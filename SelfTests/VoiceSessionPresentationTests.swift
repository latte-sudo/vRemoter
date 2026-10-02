import Foundation

@main
struct VoiceSessionPresentationTests {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let origin = Date(timeIntervalSince1970: 1_000)
        func time(_ seconds: TimeInterval) -> Date { origin.addingTimeInterval(seconds) }

        var state = VoiceSessionPresentation()
        check(state.phase == .idle && state.failure == nil, "initial state is idle")
        state.apply(.recording, detail: "late audio", at: origin)
        check(state.phase == .idle && state.startedAt == nil, "stray audio cannot invent a session")
        state.apply(.ready, detail: "ready", at: origin)
        state.apply(.sessionBegan, detail: "opening", at: time(1))
        check(state.phase == .opening && state.sessionStartedAt == time(1), "a real start enters opening")
        check(state.startedAt == nil && state.elapsed(at: time(10)) == 0, "opening is not confirmed recording")
        state.apply(.waitingForAudio, detail: "waiting", at: time(2))
        check(state.startedAt == nil, "waiting never starts the recording timer")
        state.apply(.recording, detail: "recording", at: time(3))
        check(state.phase == .recording && state.startedAt == time(3), "confirmed audio starts the timer")
        state.apply(.recording, detail: "still recording", at: time(4))
        check(state.startedAt == time(3), "later observations never reset recording time")
        let anotherPageSnapshot = state
        check(anotherPageSnapshot.elapsed(at: time(8)) == 5, "navigation uses the same global timestamp")
        check(state.elapsed(at: time(2)) == 0, "clock rollback cannot display negative time")
        state.apply(.targetStopChecked(.confirmed), detail: "stale check", at: time(8))
        check(state.phase == .recording && state.targetStopStatus == .notRequested, "stale stop checks cannot label a live session")
        state.apply(.ending, detail: "draining", at: time(9))
        check(state.phase == .ending && state.endedAt == nil, "ending does not prematurely claim local release")
        state.apply(.ended, detail: "locally ended", at: time(10))
        check(state.phase == .ended && state.elapsed(at: time(100)) == 7, "local completion freezes elapsed time")
        check(state.targetStopStatus == .unconfirmed, "local release does not confirm target release")
        state.apply(.targetStopChecked(.unconfirmed), detail: "custom target unconfirmed", at: time(11))
        check(state.targetStopStatus == .unconfirmed && state.endedAt == time(10), "unobserved custom target remains unconfirmed")
        state.apply(.targetStopChecked(.confirmed), detail: "observed target stop", at: time(12))
        check(state.targetStopStatus == .confirmed, "only a checked fact confirms target release")

        state.apply(.sessionBegan, detail: "opening again", at: time(20))
        state.apply(.recording, detail: "recording again", at: time(21))
        state.apply(.failed(.recordingTimedOut), detail: "timeout", at: time(30))
        check(state.phase == .error && state.failure == .recordingTimedOut, "failure is explicit typed state")
        check(state.elapsed(at: time(100)) == 9, "failed recording freezes elapsed time")
        state.apply(.ending, detail: "cleanup", at: time(31))
        state.apply(.ended, detail: "session-ended callback", at: time(32))
        state.apply(.targetStopChecked(.confirmed), detail: "target stopped", at: time(33))
        state.apply(.ready, detail: "wake", at: time(34))
        check(state.phase == .error && state.failure == .recordingTimedOut && state.detail == "timeout", "cleanup, stop confirmation, and wake preserve unrelated errors")
        state.apply(.recording, detail: "late PCM", at: time(35))
        check(state.phase == .error, "late audio cannot clear an error")
        state.apply(.sessionBegan, detail: "deliberate retry", at: time(40))
        check(state.phase == .opening && state.failure == nil && state.startedAt == nil && state.endedAt == nil, "a deliberate new session resets old state")

        state.apply(.failed(.outputStartupFailed), detail: "output unavailable", at: time(41))
        check(state.startedAt == nil && state.elapsed(at: time(100)) == 0, "failed startup never fabricates recording time")
        state.apply(.failed(.localAudioStillClosing), detail: "retry stop", at: time(42))
        check(state.failure == .localAudioStillClosing, "cleanup failure is actionable while resources remain acquired")
        state.apply(.ended, detail: "resources released", at: time(43))
        check(state.phase == .error && state.failure == .outputStartupFailed && state.detail == "output unavailable", "resource recovery preserves the underlying startup failure")
        state.apply(.failed(.targetStillRecording), detail: "stop in target", at: time(44))
        state.apply(.targetStopChecked(.unconfirmed), detail: "observer unavailable", at: time(45))
        check(state.failure == .targetStillRecording && state.phase == .error, "unavailable observation never clears target warning")
        state.apply(.targetStopChecked(.confirmed), detail: "target really stopped", at: time(46))
        check(state.failure == .outputStartupFailed && state.phase == .error, "target recovery preserves unrelated startup failure")

        state.apply(.sessionBegan, detail: "fresh session", at: time(50))
        state.apply(.recording, detail: "real audio", at: time(51))
        state.apply(.ending, detail: "stopping", at: time(52))
        state.apply(.failed(.localAudioStillClosing), detail: "retry release", at: time(53))
        state.apply(.ended, detail: "released", at: time(54))
        check(state.phase == .ended && state.failure == nil, "actual local release resolves its own failure")
        state.apply(.failed(.targetStillRecording), detail: "still recording", at: time(55))
        state.apply(.targetStopChecked(.confirmed), detail: "target stopped", at: time(56))
        check(state.phase == .ended && state.failure == nil && state.targetStopStatus == .confirmed, "actual target stop resolves its own warning")

        var idleCleanup = VoiceSessionPresentation()
        idleCleanup.apply(.failed(.localAudioStillClosing), detail: "temporary route closing", at: origin)
        idleCleanup.apply(.ended, detail: "released temporary route", at: time(1))
        check(idleCleanup.phase == .idle && idleCleanup.startedAt == nil, "idle resource cleanup invents no completed recording")
        print("PASS: \(checks) typed voice presentation checks")
    }
}
