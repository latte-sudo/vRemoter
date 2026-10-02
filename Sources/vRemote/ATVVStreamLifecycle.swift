import Foundation

/// Transport ownership, separate from the application's recording session.
/// Physical release edges must survive a MIC_CLOSE acknowledgement. ATVV STOP
/// has no stream ID, so arbitrary reordered STOPs cannot be correlated; only
/// provably duplicate physical edges and generation-scoped local work are dropped.
struct ATVVStreamLifecycle {
    enum StopDisposition { case ignore, releaseOnly, finishStream, finishLocally }
    let tracksPhysicalVoiceEdges: Bool
    private(set) var isStreaming = false
    private(set) var isClosing = false
    private(set) var physicalButtonDown = false
    private(set) var awaitingHostStart = false
    private(set) var generation: UInt64 = 0
    private(set) var streamID: UInt8 = 0

    var acceptsPCM: Bool { isStreaming && !isClosing }

    mutating func requestedOpen() { awaitingHostStart = true }
    mutating func requestedClose() {
        generation &+= 1
        awaitingHostStart = false
        isClosing = true
    }

    /// False means no decoder reset, recorder allocation, timer or callback.
    mutating func start(reason: UInt8, streamID: UInt8) -> Bool {
        if tracksPhysicalVoiceEdges {
            if reason == 0x03 {
                guard !physicalButtonDown else { return false }
                physicalButtonDown = true
            } else {
                guard reason == 0x00, awaitingHostStart else { return false }
            }
        }
        generation &+= 1
        self.streamID = streamID
        isStreaming = true
        isClosing = false
        awaitingHostStart = false
        return true
    }

    mutating func stop(reason: UInt8) -> StopDisposition {
        if tracksPhysicalVoiceEdges && reason == 0x02 {
            guard physicalButtonDown else { return .ignore }
            physicalButtonDown = false
            return isStreaming ? .finishStream : .releaseOnly
        }
        guard isStreaming else { return .ignore }
        return tracksPhysicalVoiceEdges && isClosing ? .finishLocally : .finishStream
    }

    mutating func finish() {
        generation &+= 1
        isStreaming = false
        isClosing = false
        awaitingHostStart = false
        // Only a physical release (or connection reset) clears the latch.
    }

    func acceptsCloseTimeout(generation expected: UInt64) -> Bool {
        isStreaming && isClosing && generation == expected
    }

    mutating func reset() {
        finish()
        physicalButtonDown = false
    }
}
