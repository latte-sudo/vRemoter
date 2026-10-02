import Foundation

/// A virtual output discovered on this Mac. Device IDs are deliberately not
/// persisted: CoreAudio can assign a different ID after a driver reconnects.
struct AudioOutputRoute: Equatable, Identifiable {
    let uid: String
    let name: String
    let sampleRate: Double
    let channelCount: UInt32
    let unavailableReason: String?

    var id: String { uid }
    var isSupported: Bool { unavailableReason == nil }
}

enum AudioRouteConfiguration {
    static let defaultOutputName = "vRemoteDr 2ch"
    static let selectedOutputUIDKey = "audioOutputDeviceUID"
    static let remoteGainKey = "remoteMicrophoneGain"
    static let defaultRemoteGain: Float = 10
    static let remoteGainRange: ClosedRange<Float> = 0...20
    static let testToneDuration = 1.0

    static var hasOutputSelection: Bool {
        UserDefaults.standard.object(forKey: selectedOutputUIDKey) != nil
    }

    static var selectedOutputUID: String? {
        get { storedOutputUID(in: .standard) }
        set { storeOutputUID(newValue, in: .standard) }
    }

    static var remoteGain: Float {
        get { storedRemoteGain(in: .standard) }
        set { storeRemoteGain(newValue, in: .standard) }
    }

    static func storedOutputUID(in defaults: UserDefaults) -> String? {
        guard let uid = defaults.object(forKey: selectedOutputUIDKey) as? String, !uid.isEmpty else { return nil }
        return uid
    }

    static func storeOutputUID(_ uid: String?, in defaults: UserDefaults) {
        // An empty value means the user explicitly disabled output. It is
        // different from a first launch with no preference yet.
        defaults.set(uid ?? "", forKey: selectedOutputUIDKey)
    }

    static func storedRemoteGain(in defaults: UserDefaults) -> Float {
        guard let stored = defaults.object(forKey: remoteGainKey) as? NSNumber else { return defaultRemoteGain }
        return clampedGain(stored.floatValue)
    }

    static func storeRemoteGain(_ value: Float, in defaults: UserDefaults) {
        defaults.set(clampedGain(value), forKey: remoteGainKey)
    }

    static func preferredOutputUID(
        in routes: [AudioOutputRoute],
        savedUID: String?,
        hasSavedSelection: Bool
    ) -> String? {
        // Preserve unavailable selections, and preserve an explicit "off".
        if hasSavedSelection { return savedUID }
        return routes.first {
            $0.name.caseInsensitiveCompare(defaultOutputName) == .orderedSame && $0.isSupported
        }?.uid
    }

    static func clampedGain(_ value: Float) -> Float {
        guard value.isFinite else { return defaultRemoteGain }
        return min(remoteGainRange.upperBound, max(remoteGainRange.lowerBound, value))
    }

    /// Fixed one-second, -20 dBFS tone, with short fades to prevent clicks.
    /// It is generated independently of microphone gain and session state.
    static func testTone(sampleRate: Double) -> [Float] {
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate) else { return [] }
        let count = Int((sampleRate * testToneDuration).rounded())
        let fadeFrames = max(1, Int(sampleRate * 0.01))
        return (0..<count).map { index in
            let fadeIn = min(1, Double(index) / Double(fadeFrames))
            let fadeOut = min(1, Double(count - 1 - index) / Double(fadeFrames))
            let wave = sin(2 * Double.pi * 440 * Double(index) / sampleRate)
            return Float(wave * 0.1 * min(fadeIn, fadeOut))
        }
    }
}
