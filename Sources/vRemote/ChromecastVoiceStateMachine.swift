import Foundation

enum RemoteVoiceMode: String, Codable, CaseIterable, Identifiable {
    case toggle
    case hold

    var id: String { rawValue }
}

enum InputToolTriggerMode: String, Codable, CaseIterable, Identifiable {
    case toggle
    case hold

    var id: String { rawValue }
}

/// Pure state transitions, independent of CoreAudio, Bluetooth, clocks, and key
/// injection. Only reason 0x03 is a physical Chromecast microphone press. A
/// reason-0 host response can confirm a session, but can never create one.
struct ChromecastVoiceStateMachine {
    enum Effect: Equatable {
        case beginSession
        case endSession
        case requestHostOpen
        case rejectStream
    }

    private(set) var isActive = false
    private(set) var physicalButtonDown = false
    private(set) var isStreaming = false
    private(set) var awaitingHostOpen = false
    private(set) var generation: UInt64 = 0
    private(set) var remoteMode: RemoteVoiceMode = .toggle

    mutating func remoteAudioStarted(reason: UInt8, mode: RemoteVoiceMode) -> [Effect] {
        if reason == 0x03 {
            // Duplicate STARTs during one physical press must not toggle off.
            guard !physicalButtonDown else {
                return isActive ? [] : [.rejectStream]
            }
            physicalButtonDown = true
            if isActive {
                if remoteMode == .toggle {
                    finish(preservePhysicalPress: true)
                    return [.endSession]
                }
                isStreaming = true
                awaitingHostOpen = false
                return []
            }
            begin(mode: mode, streaming: true)
            return [.beginSession]
        }

        guard reason == 0x00,
              isActive,
              awaitingHostOpen || isStreaming
        else { return [.rejectStream] }
        isStreaming = true
        awaitingHostOpen = false
        return []
    }

    mutating func remoteAudioStopped(reason: UInt8) -> [Effect] {
        if reason == 0x02 {
            // Ignore duplicate physical releases. In particular, they must not
            // cancel a host-open request made by the original release.
            guard physicalButtonDown else { return [] }
            physicalButtonDown = false
            isStreaming = false
            guard isActive else { return [] }
            if remoteMode == .hold {
                finish()
                return [.endSession]
            }
            awaitingHostOpen = true
            return [.requestHostOpen]
        }

        // Unexpected stops, transport timeout, and local disconnect cleanup
        // close the session instead of leaving a synthetic modifier held.
        isStreaming = false
        guard isActive else { return [] }
        finish()
        return [.endSession]
    }

    mutating func beginFromKeyboard(mode: RemoteVoiceMode) -> [Effect] {
        guard !isActive else { return [] }
        begin(mode: mode, streaming: false)
        awaitingHostOpen = true
        return [.beginSession, .requestHostOpen]
    }

    mutating func close() -> [Effect] {
        let wasActive = isActive
        finish()
        return wasActive ? [.endSession] : []
    }

    mutating func hostOpenConfirmed() {
        guard isActive else { return }
        awaitingHostOpen = false
        isStreaming = true
    }

    /// A delayed callback must match both the session generation and its still
    /// pending request; cancelling a DispatchWorkItem alone is insufficient.
    func acceptsHostOpenWork(generation expectedGeneration: UInt64) -> Bool {
        isActive && awaitingHostOpen && generation == expectedGeneration
    }

    private mutating func begin(mode: RemoteVoiceMode, streaming: Bool) {
        generation &+= 1
        isActive = true
        remoteMode = mode
        isStreaming = streaming
        awaitingHostOpen = false
    }

    private mutating func finish(preservePhysicalPress: Bool = false) {
        generation &+= 1
        isActive = false
        isStreaming = false
        awaitingHostOpen = false
        if !preservePhysicalPress { physicalButtonDown = false }
    }
}
