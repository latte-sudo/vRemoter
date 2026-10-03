import Foundation

/// A controller-owned snapshot, independent of any page's lifetime. Events are
/// explicit facts from the voice controller, never inferred from status text.
struct VoiceSessionPresentation: Equatable {
    enum Phase: Equatable {
        case idle, opening, recording, ending, ended, error
    }

    enum Failure: Equatable {
        case invalidConfiguration
        case outputStartupFailed
        case noRemoteAudio
        case inputToolDidNotStart
        case recordingTimedOut
        case localAudioStillClosing
        case remoteAudioFailed
        case remoteDisconnected
        case transportStopped
        case targetObservationLost
        case targetStillRecording
    }

    enum TargetStopStatus: Equatable {
        case notRequested, unconfirmed, confirmed, stillRecording
    }

    enum Event {
        case ready
        case sessionBegan
        case waitingForAudio
        case recording
        case ending
        case ended
        case targetStopChecked(TargetStopStatus)
        case failed(Failure)
    }

    private(set) var phase: Phase = .idle
    // Keep the message's identity so switching languages can redraw an active
    // or finished session without restarting it or changing its timestamps.
    private var detailText = ""
    private var detailKey: String?
    var detail: String {
        guard let detailKey else { return detailText }
        return L10n.tr(detailKey)
    }
    private(set) var sessionStartedAt: Date?
    /// Set only after real PCM and any required target confirmation arrive.
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var failure: Failure?
    private(set) var targetStopStatus: TargetStopStatus = .notRequested
    private struct FailureRecord: Equatable {
        let reason: Failure
        let detail: String
        let localizationKey: String?
    }
    private var failures = [FailureRecord]()

    var recordingStartedAt: Date? { startedAt }

    /// Frozen after closure/failure; rendering or navigating never resets it.
    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }

    mutating func apply(_ event: Event, detail: String, at date: Date) {
        apply(event, detail: detail, localizationKey: nil, at: date)
    }

    mutating func apply(_ event: Event, localizationKey: String, at date: Date) {
        apply(event, detail: "", localizationKey: localizationKey, at: date)
    }

    private mutating func apply(_ event: Event, detail newDetail: String, localizationKey: String?, at date: Date) {
        switch event {
        case .ready:
            // Wake and routine cleanup must not dismiss an actionable failure.
            guard failure == nil else { return }
            self = Self()
        case .sessionBegan:
            // Only a new deliberate session can reset unrelated past errors.
            self = Self()
            phase = .opening
            sessionStartedAt = date
        case .waitingForAudio:
            guard failure == nil, phase == .opening else { return }
        case .recording:
            guard failure == nil, phase == .opening || phase == .recording else { return }
            phase = .recording
            if startedAt == nil { startedAt = date }
        case .ending:
            guard failure == nil else { return }
            phase = .ending
        case .ended:
            if endedAt == nil { endedAt = date }
            targetStopStatus = .unconfirmed
            // A successful release is recovery for this specific failure only.
            recover(from: .localAudioStillClosing)
            guard failure == nil else { return }
            phase = sessionStartedAt == nil ? .idle : .ended
        case .targetStopChecked(let status):
            guard phase == .ended || phase == .error || phase == .idle else { return }
            targetStopStatus = status
            if status == .confirmed { recover(from: .targetStillRecording) }
            guard failure == nil else { return }
            phase = sessionStartedAt == nil ? .idle : .ended
        case .failed(let reason):
            failures.removeAll { $0.reason == reason }
            failures.append(FailureRecord(reason: reason, detail: newDetail, localizationKey: localizationKey))
            failure = reason
            phase = .error
            if startedAt != nil, endedAt == nil { endedAt = date }
            if reason == .targetStillRecording { targetStopStatus = .stillRecording }
        }
        detailText = newDetail
        detailKey = localizationKey
    }

    private mutating func recover(from reason: Failure) {
        // Recovery is specific: releasing local resources or confirming the
        // target stopped cannot dismiss an unrelated earlier startup fault.
        failures.removeAll { $0.reason == reason }
        failure = failures.last?.reason
        if let previous = failures.last {
            detailText = previous.detail
            detailKey = previous.localizationKey
        }
    }
}
