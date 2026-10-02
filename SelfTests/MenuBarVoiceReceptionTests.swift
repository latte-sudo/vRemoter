import Foundation

@main
struct MenuBarVoiceReceptionTests {
    static func main() {
        var state = MenuBarVoiceReception()
        precondition(!state.isReceiving(at: 1))
        state.receivedPacket(at: 1)
        precondition(!state.isReceiving(at: 1), "unsolicited idle PCM cannot turn the dot on")
        state.update(phase: .opening, streaming: false)
        state.receivedPacket(at: 2)
        precondition(!state.isReceiving(at: 2), "a route/session without transport is not receipt")
        state.update(phase: .opening, streaming: true)
        precondition(!state.isReceiving(at: 2), "transport START alone is not receipt")
        state.receivedPacket(at: 3)
        precondition(state.isReceiving(at: 3), "real PCM during opening shows receipt")
        state.update(phase: .recording, streaming: true)
        precondition(state.isReceiving(at: 3.5))
        precondition(!state.isReceiving(at: 3.75), "missing packets expire the indicator")
        state.receivedPacket(at: 4)
        precondition(state.isReceiving(at: 4), "resuming PCM restores the indicator")
        precondition(!state.isReceiving(at: 3.9), "clock anomalies cannot create false receipt")
        for phase in [VoiceSessionPresentation.Phase.ending, .ended, .error, .idle] {
            state.update(phase: .recording, streaming: true)
            state.receivedPacket(at: 5)
            precondition(state.isReceiving(at: 5))
            state.update(phase: phase, streaming: true)
            precondition(!state.isReceiving(at: 5), "stop/error clears immediately while BLE drains")
            state.receivedPacket(at: 5.1)
            precondition(!state.isReceiving(at: 5.1), "late PCM after closure stays off")
        }
        state.update(phase: .recording, streaming: true)
        state.receivedPacket(at: 6)
        state.update(phase: .recording, streaming: false)
        precondition(!state.isReceiving(at: 6), "disconnect/transport stop clears immediately")
        state.update(phase: .opening, streaming: true)
        precondition(!state.isReceiving(at: 6), "new session cannot reuse old packet proof")
        state.receivedPacket(at: 6.1)
        precondition(state.isReceiving(at: 6.1))
        print("PASS: 24 menu-bar PCM receipt lifecycle assertions")
    }
}
