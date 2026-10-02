import Foundation

/// An app-local label for the current Chromecast profile, not a Bluetooth name
/// or a physical-device identifier. Never use this value for discovery/binding.
enum RemoteDisplayName {
    static let key = "chromecast.remoteDisplayName"
    static let defaultName = "Chromecast Voice Remote"
    static let maximumLength = 64
    // Also bound pathological strings consisting of huge combining sequences.
    static let maximumUTF8Bytes = 4096

    enum ValidationError: Error {
        case tooLong, invalidCharacters
    }

    /// Empty/whitespace-only input explicitly clears the override. Length is
    /// measured in user-perceived characters so Chinese and emoji remain usable.
    static func normalizedAlias(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count <= maximumLength, value.utf8.count <= maximumUTF8Bytes else {
            throw ValidationError.tooLong
        }
        guard !value.unicodeScalars.contains(where: { scalar in
            switch scalar.properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator: return true
            default:
                // Disallow invisible direction overrides in shared UI labels,
                // while retaining natural RTL text, combining marks and emoji.
                return [0x061C, 0x200E, 0x200F].contains(scalar.value)
                    || (0x202A...0x202E).contains(scalar.value)
                    || (0x2066...0x2069).contains(scalar.value)
            }
        }) else { throw ValidationError.invalidCharacters }
        return value
    }

    static func alias(in defaults: UserDefaults = .standard) -> String {
        guard let raw = defaults.object(forKey: key) as? String,
              let value = try? normalizedAlias(raw) else { return "" }
        return value
    }

    static func displayName(in defaults: UserDefaults = .standard) -> String {
        let value = alias(in: defaults)
        return value.isEmpty ? defaultName : value
    }

    static func set(_ input: String, in defaults: UserDefaults = .standard) throws {
        let value = try normalizedAlias(input)
        if value.isEmpty { defaults.removeObject(forKey: key) }
        else { defaults.set(value, forKey: key) }
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
