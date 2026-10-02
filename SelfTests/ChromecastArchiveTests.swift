import AppKit
import Foundation

enum L10n { static func text(_ chinese: String, _ english: String) -> String { english } }
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
        _ = try ChromecastSettingsArchive.validate(archive([DockVisibilityPreference.key: true]))
        try rejects([DockVisibilityPreference.key: "true"])
        try rejects([DockVisibilityPreference.key: 2])
        for appearance in AppAppearance.allCases {
            _ = try ChromecastSettingsArchive.validate(archive([AppAppearance.key: appearance.rawValue]))
        }
        try rejects([AppAppearance.key: "unknown"])
        try rejects([AppAppearance.key: true])
        try rejects([AppAppearance.key: Data()])
        let original = ChromecastSettingsArchive.snapshot()
        defer { ChromecastSettingsArchive.restore(original) }
        DockVisibilityPreference.setVisible(true)
        AppAppearance.set(.dark)
        let exported = try ChromecastSettingsArchive.validate(ChromecastSettingsArchive.exportData())
        ChromecastSettingsArchive.restore([:])
        precondition(!DockVisibilityPreference.isVisible())
        precondition(AppAppearance.selected() == .system)
        ChromecastSettingsArchive.restore(exported)
        precondition(DockVisibilityPreference.isVisible())
        precondition(AppAppearance.selected() == .dark)
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
        print("PASS: archive versions, device scope, field types and mapping payloads")
    }
}
