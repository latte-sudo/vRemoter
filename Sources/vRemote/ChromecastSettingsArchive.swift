import Foundation

/// A bounded, versioned configuration archive. Never includes logs, recordings,
/// Bluetooth UUIDs, permissions, credentials, or launch-agent state.
enum ChromecastSettingsArchive {
    static let version = 1
    static let voiceKey = "voiceConfiguration.v1"
    static func allowed(_ key: String) -> Bool {
        key == voiceKey || key == AppStorage.inputTriggerKeyKey ||
        key == AudioRouteConfiguration.selectedOutputUIDKey || key == AudioRouteConfiguration.remoteGainKey || key.hasPrefix("remoteMapping.chromecast.") ||
        key.hasPrefix("remoteCustomMapping.chromecast.") ||
        key.hasPrefix("remoteApplicationMapping.chromecast.") ||
        key.hasPrefix("remoteMappingHoldRepeat.chromecast.") || key == "remoteMappingEnabled.chromecast"
    }
    static func snapshot() -> [String: Any] {
        UserDefaults.standard.dictionaryRepresentation().filter { allowed($0.key) }
    }
    static func restore(_ values: [String: Any]) {
        for key in snapshot().keys { UserDefaults.standard.removeObject(forKey: key) }
        for (key, value) in values where allowed(key) { UserDefaults.standard.set(value, forKey: key) }
    }
    static func exportData() throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["schemaVersion": version,
            "device": "chromecast", "settings": snapshot()], format: .xml, options: 0)
    }
    static func validate(_ data: Data) throws -> [String: Any] {
        guard data.count < 1_000_000,
              let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              root["schemaVersion"] as? Int == version,
              root["device"] as? String == "chromecast",
              let values = root["settings"] as? [String: Any], values.count < 300,
              values.keys.allSatisfy(allowed) else { throw ArchiveError.invalid }
        for (key, value) in values {
            guard value is String || value is NSNumber || value is Data else { throw ArchiveError.invalid }
            if let text = value as? String, text.count > 4096 { throw ArchiveError.invalid }
            if let blob = value as? Data, blob.count > 16384 { throw ArchiveError.invalid }
            if key == AudioRouteConfiguration.selectedOutputUIDKey, !(value is String) { throw ArchiveError.invalid }
            if key == AudioRouteConfiguration.remoteGainKey {
                guard let number = value as? NSNumber, number.doubleValue.isFinite,
                      (0...20).contains(number.doubleValue) else { throw ArchiveError.invalid }
            }
            if key == AppStorage.inputTriggerKeyKey {
                guard let raw = value as? String, InputTriggerKey(rawValue: raw) != nil else { throw ArchiveError.invalid }
            }
            if key == "remoteMappingEnabled.chromecast" || key.hasPrefix("remoteMappingHoldRepeat.chromecast.") {
                guard let number = value as? NSNumber, number == 0 || number == 1 else { throw ArchiveError.invalid }
            }
            if key.hasPrefix("remoteMapping.chromecast.") {
                try validateButtonKey(key, prefix: "remoteMapping.chromecast.")
                guard let raw = value as? String, let target = RemoteMappingTarget(rawValue: raw), target != .doubaoVoice else { throw ArchiveError.invalid }
                let suffix = String(key.dropFirst("remoteMapping.chromecast.".count))
                if target == .custom, values["remoteCustomMapping.chromecast." + suffix] == nil { throw ArchiveError.invalid }
                if target == .launchApplication, values["remoteApplicationMapping.chromecast." + suffix] == nil { throw ArchiveError.invalid }
            }
            if key.hasPrefix("remoteCustomMapping.chromecast.") {
                try validateButtonKey(key, prefix: "remoteCustomMapping.chromecast.")
                guard let data = value as? Data,
                      let shortcut = try? JSONDecoder().decode(RemoteCustomShortcut.self, from: data),
                      shortcut.keyCode <= 127, shortcut.flags & ~UInt64(0x00FF0000) == 0,
                      !shortcut.label.isEmpty, shortcut.label.count <= 256 else { throw ArchiveError.invalid }
            }
            if key.hasPrefix("remoteApplicationMapping.chromecast.") {
                try validateButtonKey(key, prefix: "remoteApplicationMapping.chromecast.")
                guard let data = value as? Data,
                      let app = try? JSONDecoder().decode(RemoteApplicationShortcut.self, from: data),
                      app.path.hasPrefix("/"), URL(fileURLWithPath: app.path).pathExtension.lowercased() == "app",
                      app.path.count <= 4096, !app.name.isEmpty, app.name.count <= 512 else { throw ArchiveError.invalid }
            }
            if key.hasPrefix("remoteMappingHoldRepeat.chromecast.") {
                try validateButtonKey(key, prefix: "remoteMappingHoldRepeat.chromecast.", allowsGesture: false)
            }
            if key == voiceKey {
                guard let blob = value as? Data,
                      (try? JSONDecoder().decode(VoiceConfiguration.self, from: blob))?.isValid == true else { throw ArchiveError.invalid }
            }
        }
        return values
    }
    private static func validateButtonKey(_ key: String, prefix: String, allowsGesture: Bool = true) throws {
        let parts = key.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 1 || (allowsGesture && parts.count == 2),
              let id = parts.first, RemoteProfiles.chromecastButtons.contains(where: { $0.id == String(id) && !$0.voiceControlled }),
              parts.count == 1 || ["doubleClick", "longPress"].contains(String(parts[1])) else { throw ArchiveError.invalid }
    }
    enum ArchiveError: LocalizedError {
        case invalid
        var errorDescription: String? { "配置文件无效、版本不受支持，或包含非 Chromecast 设置。原设置没有改变。" }
    }
}
