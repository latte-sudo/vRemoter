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
    /// A selected application is more reliable than a manually entered identifier.
    var customApplicationPath: String = ""

    private enum CodingKeys: String, CodingKey {
        case remoteVoiceMode, inputToolTriggerMode, inputTool, customBundleIdentifier, triggerKey, customApplicationPath
    }

    init(remoteVoiceMode: RemoteVoiceMode = .toggle,
         inputToolTriggerMode: InputToolTriggerMode = .toggle,
         inputTool: VoiceInputTool = .doubao,
         customBundleIdentifier: String = "",
         triggerKey: InputTriggerKey = .option,
         customApplicationPath: String = "") {
        self.remoteVoiceMode = remoteVoiceMode
        self.inputToolTriggerMode = inputToolTriggerMode
        self.inputTool = inputTool
        self.customBundleIdentifier = customBundleIdentifier
        self.triggerKey = triggerKey
        self.customApplicationPath = customApplicationPath
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        remoteVoiceMode = try values.decode(RemoteVoiceMode.self, forKey: .remoteVoiceMode)
        inputToolTriggerMode = try values.decode(InputToolTriggerMode.self, forKey: .inputToolTriggerMode)
        inputTool = try values.decode(VoiceInputTool.self, forKey: .inputTool)
        customBundleIdentifier = try values.decode(String.self, forKey: .customBundleIdentifier)
        triggerKey = try values.decode(InputTriggerKey.self, forKey: .triggerKey)
        customApplicationPath = try values.decodeIfPresent(String.self, forKey: .customApplicationPath) ?? ""
    }

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
        // Validate persisted paths even when the preset is selected, so an imported
        // archive cannot smuggle arbitrary executable paths into a later selection.
        if !customApplicationPath.isEmpty {
            guard Self.isApplicationPath(customApplicationPath) else { return false }
        }
        guard inputTool == .custom else { return true }
        if targetBundleIdentifier.isEmpty { return !customApplicationPath.isEmpty }
        let components = targetBundleIdentifier.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        return components.count >= 2 && components.allSatisfy { component in
            !component.isEmpty && component.unicodeScalars.allSatisfy(allowed.contains)
        }
    }

    static func isApplicationPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("\0")
            && !(path as NSString).pathComponents.contains("..")
            && URL(fileURLWithPath: path).pathExtension.lowercased() == "app"
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
