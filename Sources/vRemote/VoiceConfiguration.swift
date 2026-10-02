import Foundation

/// The target application's shortcut mode is independent of the remote button's
/// interaction mode. A toggle remote can keep a hold shortcut pressed, and a
/// hold remote can send one toggle shortcut at each edge.
enum VoiceInputTool: String, Codable, CaseIterable, Identifiable {
    case doubao
    case custom

    var id: String { rawValue }
}

struct VoiceConfiguration: Codable, Equatable {
    static let defaultsKey = "voiceConfiguration.v1"
    static let doubaoBundleIdentifier = "com.bytedance.inputmethod.doubaoime"

    var remoteVoiceMode: RemoteVoiceMode = .toggle
    var inputToolTriggerMode: InputToolTriggerMode = .toggle
    var inputTool: VoiceInputTool = .doubao
    var customBundleIdentifier: String = ""
    var triggerKey: InputTriggerKey = .option

    var targetBundleIdentifier: String {
        inputTool == .doubao
            ? Self.doubaoBundleIdentifier
            : customBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The current CoreAudio observation is verified only for Doubao. A custom
    /// input tool may capture through a helper process, so its absent/inactive
    /// process snapshot must never reject an otherwise valid voice gesture.
    var usesAuthoritativeAudioMonitor: Bool { inputTool == .doubao }

    var isValid: Bool {
        guard inputTool == .custom else { return true }
        let components = targetBundleIdentifier.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        return components.count >= 2 && components.allSatisfy { component in
            !component.isEmpty && component.unicodeScalars.allSatisfy(allowed.contains)
        }
    }
}

extension AppStorage {
    static var voiceConfiguration: VoiceConfiguration {
        get {
            if let data = UserDefaults.standard.data(forKey: VoiceConfiguration.defaultsKey),
               let configuration = try? JSONDecoder().decode(VoiceConfiguration.self, from: data)
            {
                return configuration
            }
            // Preserve the user's existing modifier when upgrading from the
            // original single-input-tool configuration.
            var configuration = VoiceConfiguration()
            configuration.triggerKey = inputTriggerKey
            return configuration
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: VoiceConfiguration.defaultsKey)
            // Physical keyboard observation and existing Key helpers read this
            // key; keep both paths matched to the selected tool's shortcut.
            inputTriggerKey = newValue.triggerKey
        }
    }
}
