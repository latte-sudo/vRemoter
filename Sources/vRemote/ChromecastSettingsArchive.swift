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
        key.hasPrefix("remoteGestureMapping.chromecast.") ||
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
            if key == voiceKey {
                guard let blob = value as? Data,
                      (try? JSONDecoder().decode(VoiceConfiguration.self, from: blob))?.isValid == true else { throw ArchiveError.invalid }
            }
        }
        return values
    }
    enum ArchiveError: LocalizedError {
        case invalid
        var errorDescription: String? { "配置文件无效、版本不受支持，或包含非 Chromecast 设置。原设置没有改变。" }
    }
}
