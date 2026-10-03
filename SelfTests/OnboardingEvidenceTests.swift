import Foundation
@main
struct OnboardingEvidenceTests {
    static func main() {
        func evidence(armed: Bool = true, audio: Int = 3, ended: Int = 2, active: Bool = false, route: Bool = true, connected: Bool = true, text: String = "你好", confirmed: Bool = true) -> OnboardingSpeechEvidence {
            OnboardingSpeechEvidence(armed: armed, receivedAudioPackets: audio, baselineAudioPackets: 2, endedSessions: ended, baselineEndedSessions: 1, voiceActive: active, routeAvailable: route, remoteConnected: connected, text: text, userConfirmedRecognition: confirmed)
        }
        precondition(evidence().canComplete)
        precondition(!evidence(armed: false).canComplete)
        precondition(!evidence(audio: 2).canComplete, "typed text without new PCM must fail")
        precondition(!evidence(ended: 1).canComplete, "old ended session must fail")
        precondition(!evidence(active: true).canComplete)
        precondition(!evidence(route: false).canComplete)
        precondition(!evidence(connected: false).canComplete)
        precondition(!evidence(text: " \n").canComplete)
        precondition(!evidence(confirmed: false).canComplete)
        print("PASS: 9 onboarding evidence checks")
    }
}
