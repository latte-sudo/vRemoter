import Foundation

/// Shared ATVV transport and speech-state contracts used by the Chromecast session.
enum RemoteMicrophoneOpenResult: Equatable {
    case sent
    case alreadyStreaming
    case retryAfter(TimeInterval)
    case unavailable
    case failed(String)
}

protocol DoubaoAudioStateProviding: AnyObject {
    var onSnapshotChanged: ((DoubaoAudioStateMonitor.Snapshot) -> Void)? {
        get set
    }

    func start()
    func stop()
    func snapshotNow() -> DoubaoAudioStateMonitor.Snapshot
}

extension DoubaoAudioStateMonitor: DoubaoAudioStateProviding {}
