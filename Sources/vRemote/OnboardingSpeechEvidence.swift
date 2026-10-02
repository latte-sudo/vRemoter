import Foundation

/// Separates observed transport evidence from the human confirmation of the
/// target app's recognition result. Typed text alone can never pass this gate.
struct OnboardingSpeechEvidence {
    let armed: Bool
    let receivedAudioPackets: Int
    let baselineAudioPackets: Int
    let endedSessions: Int
    let baselineEndedSessions: Int
    let voiceActive: Bool
    let routeAvailable: Bool
    let remoteConnected: Bool
    let text: String
    let userConfirmedRecognition: Bool

    var canComplete: Bool {
        armed && receivedAudioPackets > baselineAudioPackets &&
        endedSessions > baselineEndedSessions && !voiceActive &&
        routeAvailable && remoteConnected && userConfirmedRecognition &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
