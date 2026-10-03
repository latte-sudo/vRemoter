import Foundation
#if canImport(Combine)
import Combine
#endif

/// App-local, stable codes. Never changes AppleLanguages or the system locale.
enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    static let key = "vRemoter.appLanguage"

    static var selected: AppLanguage {
        get { selection(in: .standard) }
        set { set(newValue) }
    }

    static func selection(in defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    static func set(_ value: AppLanguage, in defaults: UserDefaults = .standard) {
        let previous = selection(in: defaults)
        defaults.set(value.rawValue, forKey: key)
        if previous != value { notifyChange() }
    }

    /// Match the first macOS preferred language. Unsupported languages use English.
    /// An explicit script wins over the region (e.g. zh-Hans-TW stays Simplified).
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        let components = (preferredLanguages.first ?? "en").replacingOccurrences(of: "_", with: "-")
            .lowercased().split(separator: "-").map(String.init)
        guard components.first == "zh" else { return .english }
        if components.contains("hant") { return .traditionalChinese }
        if components.contains("hans") { return .simplifiedChinese }
        return components.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? .traditionalChinese : .simplifiedChinese
    }

    var locale: Locale { Locale(identifier: resolved().rawValue) }
    var title: String {
        switch self {
        case .system: return L10n.tr("language.system")
        // Autonyms keep the language selector recognizable in any current locale.
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }

    static func notifyChange() {
        if Thread.isMainThread { NotificationCenter.default.post(name: .appLanguageDidChange, object: nil) }
        else { DispatchQueue.main.async { NotificationCenter.default.post(name: .appLanguageDidChange, object: nil) } }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("vRemoter.appLanguageDidChange")
}

#if canImport(Combine)
/// Refresh views in place. Never replace the root view or reset an active session.
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()
    @Published private(set) var revision = 0
    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(NotificationCenter.default.addObserver(forName: .appLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.revision += 1
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { _ in
            if AppLanguage.selected == .system { AppLanguage.notifyChange() }
        })
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
#endif

/// All app-owned text is bundled. Numeric placeholders may be reordered by locale.
/// Device names, file names, keyboard symbols and diagnostic data remain verbatim.
enum L10n {
    static let supportedLanguages: [AppLanguage] = [.simplifiedChinese, .traditionalChinese, .english]

    static var resourceRoot: URL? {
        if let root = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: root.appendingPathComponent("en.lproj/Localizable.strings").path) { return root }
        #if SWIFT_PACKAGE
        return Bundle.module.resourceURL
        #else
        return Bundle.main.resourceURL
        #endif
    }

    static func table(for language: AppLanguage, resourceRoot: URL?) -> [String: String] {
        guard let resourceRoot else { return [:] }
        let directoryName = language.resolved().rawValue + ".lproj"
        // SwiftPM may normalize localization-directory case. Explicit matching
        // also works on case-sensitive filesystems without OS fallback rules.
        let directories = (try? FileManager.default.contentsOfDirectory(at: resourceRoot, includingPropertiesForKeys: nil)) ?? []
        let directory = directories.first { $0.lastPathComponent.caseInsensitiveCompare(directoryName) == .orderedSame }
            ?? resourceRoot.appendingPathComponent(directoryName)
        let url = directory.appendingPathComponent("Localizable.strings")
        guard let data = try? Data(contentsOf: url),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return dictionary
    }

    private static let tables: [AppLanguage: [String: String]] = Dictionary(uniqueKeysWithValues:
        supportedLanguages.map { ($0, table(for: $0, resourceRoot: resourceRoot)) })

    static func tr(_ key: String, _ arguments: Any...) -> String {
        text(key, language: AppLanguage.selected, arguments: arguments.map { String(describing: $0) })
    }

    static func text(_ key: String, language: AppLanguage, arguments: [String] = []) -> String {
        let template = tables[language.resolved()]?[key] ?? tables[.english]?[key] ?? key
        return format(template, arguments: arguments)
    }

    /// Used by both SwiftPM and the packaged executable before any UI/device
    /// objects are created. This proves the running binary can read all tables.
    static func validateBundledResources() -> [String] {
        let english = table(for: .english, resourceRoot: resourceRoot)
        guard !english.isEmpty else { return ["English localization resource is missing or unreadable"] }
        var failures: [String] = []
        for language in supportedLanguages {
            let localized = table(for: language, resourceRoot: resourceRoot)
            if Set(localized.keys) != Set(english.keys) { failures.append("Localization keys differ: \(language.rawValue)") }
            if localized.values.contains(where: { $0.isEmpty }) { failures.append("Empty translation: \(language.rawValue)") }
        }
        return failures
    }

    /// Replace against the original template, never re-interpret user text as a
    /// placeholder. A remote named "{1}" must remain literally "{1}".
    static func format(_ template: String, arguments: [String]) -> String {
        guard let expression = try? NSRegularExpression(pattern: #"\{([0-9]+)\}"#) else { return template }
        let source = template as NSString
        var result = template
        for match in expression.matches(in: template, range: NSRange(location: 0, length: source.length)).reversed() {
            guard let index = Int(source.substring(with: match.range(at: 1))), arguments.indices.contains(index),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: arguments[index])
        }
        return result
    }
}
