import AppKit
import Foundation

enum Key { static let syntheticMarker: Int64 = 1 }
enum InputTriggerKey: String, Codable { case option, command, control, shift, function }
enum AppStorage {
    static let inputTriggerKeyKey = "inputTriggerKey"
    static var inputTriggerKey = InputTriggerKey.option
}

@main
struct ChromecastArchiveTests {
    static func main() throws {
        func archive(_ settings: [String: Any], version: Int = 1, device: String = "chromecast") throws -> Data {
            try PropertyListSerialization.data(fromPropertyList: ["schemaVersion": version, "device": device, "settings": settings], format: .xml, options: 0)
        }
        func rejects(_ settings: [String: Any], version: Int = 1, device: String = "chromecast") throws {
            do { _ = try ChromecastSettingsArchive.validate(archive(settings, version: version, device: device)); preconditionFailure("invalid archive accepted") }
            catch ChromecastSettingsArchive.ArchiveError.invalid { }
        }
        _ = try ChromecastSettingsArchive.validate(archive([:]))
        _ = try ChromecastSettingsArchive.validate(archive(["remoteMapping.chromecast.03": "arrowUp", "remoteMappingEnabled.chromecast": true]))
        for target in [RemoteMappingTarget.switchApplications, .scrollUp, .scrollDown, .scrollLeft, .scrollRight] {
            for suffix in ["", ".doubleClick", ".longPress"] {
                let key = "remoteMapping.chromecast.0E" + suffix
                let validated = try ChromecastSettingsArchive.validate(archive([key: target.rawValue]))
                precondition(validated[key] as? String == target.rawValue)
            }
        }
        _ = try ChromecastSettingsArchive.validate(archive([DockVisibilityPreference.key: true]))
        try rejects([DockVisibilityPreference.key: "true"])
        try rejects([DockVisibilityPreference.key: 2])
        for appearance in AppAppearance.allCases {
            _ = try ChromecastSettingsArchive.validate(archive([AppAppearance.key: appearance.rawValue]))
        }
        for language in AppLanguage.allCases {
            _ = try ChromecastSettingsArchive.validate(archive([AppLanguage.key: language.rawValue]))
        }
        try rejects([AppLanguage.key: "zh"])
        try rejects([AppLanguage.key: "fr"])
        try rejects([AppLanguage.key: true])
        try rejects([AppLanguage.key: Data()])
        try rejects([AppAppearance.key: "unknown"])
        try rejects([AppAppearance.key: true])
        try rejects([AppAppearance.key: Data()])
        for name in ["客厅遥控器 🎤", "  Office remote  ", "", " \n ", String(repeating: "🎤", count: 64)] {
            let values = try ChromecastSettingsArchive.validate(archive([RemoteDisplayName.key: name]))
            precondition(values[RemoteDisplayName.key] as? String == name)
        }
        let invalidNames: [Any] = [true, 7, Data(), "bad\nname", "bad\u{202E}name", String(repeating: "a", count: 65)]
        for invalid in invalidNames {
            try rejects([RemoteDisplayName.key: invalid])
        }
        let original = ChromecastSettingsArchive.snapshot()
        let originalLanguage = UserDefaults.standard.object(forKey: AppLanguage.key)
        defer {
            ChromecastSettingsArchive.restore(original)
            if let originalLanguage { UserDefaults.standard.set(originalLanguage, forKey: AppLanguage.key) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.key) }
        }
        // Older Chromecast archives can include retired mapping fields. They
        // import only current settings, never recreate an X6 model or overwrite
        // historical preferences on disk, including opaque/obsolete payloads.
        let retiredOnDisk: [String: Any] = [
            "remoteMappingEnabled.x6": true,
            "remoteMapping.x6.k52": "commandV",
            "remoteMapping.x6.k52.doubleClick": "custom",
            "remoteMapping.x6.k52.longPress": "launchApplication",
            "remoteCustomMapping.x6.k52.doubleClick": Data("saved shortcut".utf8),
            "remoteApplicationMapping.x6.k52.longPress": Data("saved application".utf8),
            "remoteMappingHoldRepeat.x6.k52": false
        ]
        let defaults = UserDefaults.standard
        let originalRetired = defaults.dictionaryRepresentation().filter { retiredOnDisk[$0.key] != nil }
        defer {
            for key in retiredOnDisk.keys {
                if let value = originalRetired[key] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        for (key, value) in retiredOnDisk { defaults.set(value, forKey: key) }
        func assertRetiredPreferencesUnchanged() {
            let remaining = defaults.dictionaryRepresentation().filter { retiredOnDisk[$0.key] != nil }
            precondition(NSDictionary(dictionary: retiredOnDisk).isEqual(to: remaining))
        }
        let mixedArchive: [String: Any] = [
            "remoteMapping.chromecast.03": "commandC",
            "remoteMappingEnabled.chromecast": true,
            "remoteMappingEnabled.x6": false,
            "remoteMapping.x6.k52": "removedTarget",
            "remoteMapping.x6.k52.doubleClick": "custom",
            "remoteMapping.x6.k52.longPress": "launchApplication",
            "remoteCustomMapping.x6.k52.doubleClick": ["obsolete": "payload"],
            "remoteApplicationMapping.x6.k52.longPress": Data("obsolete payload".utf8),
            "remoteMappingHoldRepeat.x6.k52": "obsolete value"
        ]
        let migrated = try ChromecastSettingsArchive.validate(archive(mixedArchive))
        precondition(migrated.count == 2 && migrated.keys.allSatisfy(ChromecastSettingsArchive.allowed))
        precondition(migrated["remoteMapping.chromecast.03"] as? String == "commandC")
        ChromecastSettingsArchive.restore(migrated)
        precondition(defaults.string(forKey: "remoteMapping.chromecast.03") == "commandC")
        precondition(defaults.bool(forKey: "remoteMappingEnabled.chromecast"))
        assertRetiredPreferencesUnchanged()
        let exportedRoot = try PropertyListSerialization.propertyList(from: ChromecastSettingsArchive.exportData(), format: nil) as! [String: Any]
        let exportedSettings = exportedRoot["settings"] as! [String: Any]
        precondition(exportedSettings.keys.allSatisfy(ChromecastSettingsArchive.allowed), "export must omit retired fields before validation")
        precondition(retiredOnDisk.keys.allSatisfy { !ChromecastSettingsArchive.allowed($0) })
        // The write boundary also ignores retired data passed directly to it.
        ChromecastSettingsArchive.restore(mixedArchive)
        assertRetiredPreferencesUnchanged()
        ChromecastSettingsArchive.restore([:])
        assertRetiredPreferencesUnchanged()
        try rejects(["remoteMapping.x6.k52": "arrowUp", "remoteMapping.chromecast.03": "unknown"])
        try rejects(["remoteMapping.x6.k52": "arrowUp", "unrelatedSetting": "oops"])
        for key in ["remoteMapping.x6.", "remoteMapping.x6extra.k52", "remoteMappingEnabled.x6.extra", "x6UnknownSetting"] {
            try rejects([key: true])
        }
        let tooManyRetired: [String: Any] = Dictionary(uniqueKeysWithValues: (0..<300).map { ("remoteMapping.x6.key\($0)", "disabled") })
        try rejects(tooManyRetired)
        try rejects(["remoteCustomMapping.x6.k52": Data(repeating: 0, count: 1_000_000)])
        AppLanguage.selected = .traditionalChinese
        let languageArchive = try ChromecastSettingsArchive.validate(ChromecastSettingsArchive.exportData())
        precondition(languageArchive[AppLanguage.key] as? String == "zh-Hant")
        ChromecastSettingsArchive.restore([:])
        precondition(AppLanguage.selected == .traditionalChinese, "reset preserves the current readable language")
        ChromecastSettingsArchive.restore(try ChromecastSettingsArchive.validate(archive([AppAppearance.key: "dark"])))
        precondition(AppLanguage.selected == .traditionalChinese, "legacy backup has no language preference to replace")
        AppLanguage.selected = .english
        ChromecastSettingsArchive.restore(languageArchive)
        precondition(AppLanguage.selected == .traditionalChinese, "explicit saved language restores immediately")
        try rejects([AppLanguage.key: "unsupported"])
        precondition(AppLanguage.selected == .traditionalChinese, "invalid backup never changes language")
        DockVisibilityPreference.setVisible(true)
        AppAppearance.set(.dark)
        try RemoteDisplayName.set("客厅遥控器 🎤")
        let exported = try ChromecastSettingsArchive.validate(ChromecastSettingsArchive.exportData())
        precondition(exported[RemoteDisplayName.key] as? String == "客厅遥控器 🎤")
        ChromecastSettingsArchive.restore([:])
        precondition(!DockVisibilityPreference.isVisible())
        precondition(AppAppearance.selected() == .system)
        precondition(RemoteDisplayName.displayName() == RemoteDisplayName.defaultName)
        ChromecastSettingsArchive.restore(exported)
        precondition(DockVisibilityPreference.isVisible())
        precondition(AppAppearance.selected() == .dark)
        precondition(RemoteDisplayName.displayName() == "客厅遥控器 🎤", "undo/import restores the saved name")
        // Legacy v1 archives omit the optional alias; replacing settings clears it.
        ChromecastSettingsArchive.restore(try ChromecastSettingsArchive.validate(archive([:])))
        precondition(RemoteDisplayName.displayName() == RemoteDisplayName.defaultName)
        for (raw, expected) in [("  Office remote  ", "Office remote"), (" \n ", RemoteDisplayName.defaultName)] {
            ChromecastSettingsArchive.restore(try ChromecastSettingsArchive.validate(archive([RemoteDisplayName.key: raw])))
            precondition(RemoteDisplayName.displayName() == expected)
        }
        try RemoteDisplayName.set("Keep on rejected import")
        try rejects([RemoteDisplayName.key: "bad\nname"])
        precondition(RemoteDisplayName.displayName() == "Keep on rejected import")
        // Both new action kinds survive real export, restore, and undo. Each
        // restore must also notify held-action owners to stop old timers.
        let mappingStore = RemoteMappingStore.shared
        let customButton = RemoteProfiles.chromecastButtons.first { $0.id == "0E" }!
        for target in [RemoteMappingTarget.switchApplications, .scrollUp, .scrollDown, .scrollLeft, .scrollRight] {
            mappingStore.setTarget(target, for: customButton, remote: .chromecast, gesture: .longPress)
            let saved = try ChromecastSettingsArchive.validate(ChromecastSettingsArchive.exportData())
            let revision = mappingStore.revision
            ChromecastSettingsArchive.restore([:])
            precondition(mappingStore.revision > revision)
            precondition(mappingStore.target(for: customButton, remote: .chromecast, gesture: .longPress) == .disabled)
            ChromecastSettingsArchive.restore(saved)
            precondition(mappingStore.target(for: customButton, remote: .chromecast, gesture: .longPress) == target)
        }
        // Archives made before the theme option existed still import as system.
        ChromecastSettingsArchive.restore(try ChromecastSettingsArchive.validate(archive([DockVisibilityPreference.key: true])))
        precondition(AppAppearance.selected() == .system)
        try rejects([:], version: 2)
        try rejects([:], device: "x6")
        try rejects(["unrelatedSetting": "oops"])
        try rejects(["audioOutputDeviceUID": Data()])
        try rejects(["remoteMicrophoneGain": 21])
        try rejects(["remoteMapping.chromecast.03": Data()])
        try rejects(["remoteMapping.chromecast.unknown": "arrowUp"])
        try rejects(["remoteMapping.chromecast.voice": "arrowUp"])
        try rejects(["remoteMapping.chromecast.03": "custom"])
        try rejects(["remoteCustomMapping.chromecast.03": Data("broken".utf8)])
        try rejects(["remoteMappingEnabled.chromecast": "true"])
        try rejects(["voiceConfiguration.v1": Data("broken".utf8)])
        let shortcut = try JSONEncoder().encode(RemoteCustomShortcut(keyCode: 8, flags: 0, label: "C"))
        _ = try ChromecastSettingsArchive.validate(archive(["remoteMapping.chromecast.03.doubleClick": "custom", "remoteCustomMapping.chromecast.03.doubleClick": shortcut]))
        let app = try JSONEncoder().encode(RemoteApplicationShortcut(bundleIdentifier: "com.example.Editor", path: "/Applications/Editor.app", name: "Editor"))
        _ = try ChromecastSettingsArchive.validate(archive(["remoteMapping.chromecast.03.longPress": "launchApplication", "remoteApplicationMapping.chromecast.03.longPress": app]))
        let unsafe = try JSONEncoder().encode(RemoteApplicationShortcut(bundleIdentifier: nil, path: "/bin/sh", name: "shell"))
        try rejects(["remoteApplicationMapping.chromecast.03": unsafe])
        assertRetiredPreferencesUnchanged()
        print("PASS: archive versions, device scope, field types, mapping payloads and retired-field isolation")
    }
}
