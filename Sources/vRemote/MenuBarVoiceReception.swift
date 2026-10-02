import Foundation

/// A green menu-bar dot means recent incoming PCM in a live voice session,
/// never just a paired device or an open route. Call with a monotonic clock.
struct MenuBarVoiceReception {
    static let packetFreshness: TimeInterval = 0.75
    private var acceptsAudio = false
    private var lastPacketAt: TimeInterval?

    mutating func update(phase: VoiceSessionPresentation.Phase, streaming: Bool) {
        acceptsAudio = streaming && (phase == .opening || phase == .recording)
        if !acceptsAudio { lastPacketAt = nil }
    }

    mutating func receivedPacket(at time: TimeInterval) {
        guard acceptsAudio else { return }
        lastPacketAt = time
    }

    func isReceiving(at time: TimeInterval) -> Bool {
        guard acceptsAudio, let lastPacketAt else { return false }
        let age = time - lastPacketAt
        return age >= 0 && age < Self.packetFreshness
    }
}
