import Foundation
#if canImport(Combine)
import Combine
#endif

@main
struct LocalizationTests {
    static func main() throws {
        let originalOSLanguages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String]
        let suite = "vRemoter.localization-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(AppLanguage.selection(in: defaults) == .system)
        precondition(AppLanguage.allCases.map(\.rawValue) == ["system", "zh-Hans", "zh-Hant", "en"])
        let cases: [(String, AppLanguage)] = [
            ("zh-CN", .simplifiedChinese), ("zh-SG", .simplifiedChinese), ("zh", .simplifiedChinese),
            ("zh-Hans", .simplifiedChinese), ("zh-Hans-TW", .simplifiedChinese),
            ("zh-TW", .traditionalChinese), ("zh-HK", .traditionalChinese), ("zh-MO", .traditionalChinese),
            ("zh-Hant", .traditionalChinese), ("zh-Hant-CN", .traditionalChinese), ("ZH_hant_HK", .traditionalChinese),
            ("en-GB", .english), ("ja-JP", .english), ("fr", .english), ("", .english)
        ]
        for (system, expected) in cases {
            precondition(AppLanguage.system.resolved(preferredLanguages: [system]) == expected, system)
        }
        precondition(AppLanguage.system.resolved(preferredLanguages: []) == .english)
        precondition(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh-CN"]) == .english)
        for language in L10n.supportedLanguages {
            precondition(language.resolved(preferredLanguages: ["fr-FR"]) == language)
            AppLanguage.set(language, in: defaults)
            precondition(UserDefaults(suiteName: suite)!.string(forKey: AppLanguage.key) == language.rawValue)
            precondition(AppLanguage.selection(in: defaults) == language)
        }
        let invalidValues: [Any] = ["de", "zh", 9, true]
        for invalid in invalidValues {
            defaults.set(invalid, forKey: AppLanguage.key)
            precondition(AppLanguage.selection(in: defaults) == .system)
        }
        precondition(UserDefaults.standard.object(forKey: "AppleLanguages") as? [String] == originalOSLanguages)
        precondition(L10n.validateBundledResources().isEmpty, L10n.validateBundledResources().joined(separator: "; "))
        let english = L10n.table(for: .english, resourceRoot: L10n.resourceRoot)
        precondition(english.count >= 400, "real production catalog must load")
        for language in L10n.supportedLanguages {
            let translated = L10n.table(for: language, resourceRoot: L10n.resourceRoot)
            precondition(Set(translated.keys) == Set(english.keys))
            for key in english.keys { precondition(!L10n.text(key, language: language).isEmpty) }
        }
        precondition(L10n.text("storage.byte", language: .english, arguments: ["1"]) == "1 byte")
        precondition(L10n.text("storage.bytes", language: .english, arguments: ["2"]) == "2 bytes")
        precondition(L10n.text("shell.window.title", language: .english) == "Remote Voice Utility")
        precondition(L10n.text("shell.window.title", language: .simplifiedChinese) == "遥控器语音工具")
        precondition(L10n.text("shell.window.title", language: .traditionalChinese) == "遙控器語音工具")
        precondition(L10n.text("language.title", language: .english) == "Language")
        precondition(L10n.text("language.title", language: .simplifiedChinese) == "语言")
        precondition(L10n.text("language.title", language: .traditionalChinese) == "語言")
        precondition(L10n.format("{1} / {0} / {1}", arguments: ["甲", "🎤"]) == "🎤 / 甲 / 🎤")
        precondition(L10n.format("{0} / {1}", arguments: ["{1}", "name"]) == "{1} / name", "user data must not be reinterpreted")
        precondition(L10n.format("Literal % and {2}", arguments: ["a"]) == "Literal % and {2}")
        precondition(L10n.text("test.missing.key", language: .english) == "test.missing.key")

        let original = UserDefaults.standard.object(forKey: AppLanguage.key)
        defer {
            if let original { UserDefaults.standard.set(original, forKey: AppLanguage.key) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.key) }
            AppLanguage.notifyChange()
        }
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(forName: .appLanguageDidChange, object: nil, queue: nil) { _ in notificationCount += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        AppLanguage.selected = .english
        let countBeforeChange = notificationCount
        #if canImport(Combine)
        let store = LanguageStore.shared
        let revision = store.revision
        #endif
        AppLanguage.selected = .traditionalChinese
        precondition(L10n.tr("language.title") == "語言")
        precondition(notificationCount == countBeforeChange + 1)
        #if canImport(Combine)
        precondition(store.revision == revision + 1)
        #endif
        AppLanguage.selected = .traditionalChinese
        precondition(notificationCount == countBeforeChange + 1, "unchanged selection must not refresh")

        // Live session messages and failure history survive a locale switch.
        let start = Date(timeIntervalSince1970: 100)
        var session = VoiceSessionPresentation()
        session.apply(.sessionBegan, localizationKey: "support.voice.starting", at: start)
        session.apply(.recording, localizationKey: "support.voice.recording", at: start.addingTimeInterval(1))
        let snapshot = session
        let chinese = session.detail
        AppLanguage.selected = .english
        precondition(session == snapshot && session.startedAt == start.addingTimeInterval(1))
        precondition(session.detail != chinese && session.detail == L10n.tr("support.voice.recording"))
        session.apply(.failed(.remoteDisconnected), localizationKey: "support.voice.disconnectedClosed", at: start.addingTimeInterval(3))
        let failure = session
        AppLanguage.selected = .simplifiedChinese
        precondition(session == failure && session.failure == .remoteDisconnected)
        precondition(session.elapsed(at: start.addingTimeInterval(50)) == 2)

        let issue = AudioRouteIssue.creationFailed(-50)
        let route = AudioOutputRoute(uid: "test", name: "User device {1}", sampleRate: 48000, channelCount: 2, unavailableIssue: issue)
        let routeSnapshot = route
        let oldReason = route.unavailableReason
        AppLanguage.selected = .english
        precondition(route == routeSnapshot && route.name == "User device {1}" && route.unavailableReason != oldReason)
        precondition(issue.localizedDiagnostics.contains("-50"))
        print("PASS: localization resources, locale mapping, persistence, live refresh, placeholders, session and route invariance")
    }
}
