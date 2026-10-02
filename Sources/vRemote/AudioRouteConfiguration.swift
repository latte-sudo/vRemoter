import Foundation

/// Stable audio failure identities keep cached route data independent of the
/// selected interface language. Status codes remain available for diagnostics.
enum AudioRouteIssue: Equatable {
    case noSelection, savedDeviceUnavailable, testToneNeedsDevice
    case cleanupIncomplete, macCaptureStillRunning
    case creationFailed(Int32)
    case startFailed(start: Int32, cleanup: Int32)
    case cleanupFailed(stop: Int32, cleanup: Int32)
    case deviceOffline, formatUnreadable, unsupportedFormat
    case sampleRateMismatch, unsupportedChannels

    var message: String {
        switch self {
        case .noSelection: L10n.tr("support.audio.issue.noSelection")
        case .savedDeviceUnavailable: L10n.tr("support.audio.issue.savedDeviceUnavailable")
        case .testToneNeedsDevice: L10n.tr("support.audio.issue.testToneNeedsDevice")
        case .cleanupIncomplete: L10n.tr("support.audio.issue.cleanupIncomplete")
        case .creationFailed: L10n.tr("support.audio.issue.creationFailed")
        case .startFailed: L10n.tr("support.audio.issue.startFailed")
        case .cleanupFailed: L10n.tr("support.audio.issue.cleanupFailed")
        case .macCaptureStillRunning: L10n.tr("support.audio.issue.macCaptureStillRunning")
        case .deviceOffline: L10n.tr("support.audio.issue.deviceOffline")
        case .formatUnreadable: L10n.tr("support.audio.issue.formatUnreadable")
        case .unsupportedFormat: L10n.tr("support.audio.issue.unsupportedFormat")
        case .sampleRateMismatch: L10n.tr("support.audio.issue.sampleRateMismatch")
        case .unsupportedChannels: L10n.tr("support.audio.issue.unsupportedChannels")
        }
    }

    var localizedDiagnostics: String {
        let detail: String
        switch self {
        case .creationFailed(let status):
            detail = L10n.tr("support.audio.diagnostic.systemError", status)
        case .startFailed(let start, let cleanup):
            detail = L10n.tr("support.audio.diagnostic.startAndCleanup", start, cleanup)
        case .cleanupFailed(let stop, let cleanup):
            detail = L10n.tr("support.audio.diagnostic.stopAndCleanup", stop, cleanup)
        default: return message
        }
        return message + "\n" + detail
    }

    var diagnosticDescription: String {
        switch self {
        case .noSelection: "未选择虚拟输出设备"
        case .savedDeviceUnavailable: "已保存的输出设备不可用；请连接设备后刷新，或重新选择"
        case .testToneNeedsDevice: "测试音未播放：请先选择可用的虚拟输出设备"
        case .cleanupIncomplete: "输出清理未完成；请重试关闭会话"
        case .creationFailed(let status): "创建输出失败：OSStatus=\(status)"
        case .startFailed(let start, let cleanup): "启动输出失败：OSStatus=\(start)，清理=\(cleanup)"
        case .cleanupFailed(let stop, let cleanup): "输出清理：停止=\(stop)，销毁=\(cleanup)"
        case .macCaptureStillRunning: "Mac 麦克风采集尚未停止；请重试关闭会话"
        case .deviceOffline: "设备当前离线"
        case .formatUnreadable: "无法读取输出格式"
        case .unsupportedFormat: "暂不支持此输出格式（需 32-bit Float PCM，8–192 kHz）"
        case .sampleRateMismatch: "输出流采样率不一致"
        case .unsupportedChannels: "暂不支持此输出声道配置"
        }
    }
}

/// A virtual output discovered on this Mac. Device IDs are deliberately not
/// persisted: CoreAudio can assign a different ID after a driver reconnects.
struct AudioOutputRoute: Equatable, Identifiable {
    let uid: String
    let name: String
    let sampleRate: Double
    let channelCount: UInt32
    private let unavailableReasonText: String?
    let unavailableIssue: AudioRouteIssue?

    init(uid: String, name: String, sampleRate: Double, channelCount: UInt32,
         unavailableReason: String? = nil, unavailableIssue: AudioRouteIssue? = nil) {
        self.uid = uid
        self.name = name
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.unavailableReasonText = unavailableReason
        self.unavailableIssue = unavailableIssue
    }

    var unavailableReason: String? { unavailableIssue?.message ?? unavailableReasonText }
    var id: String { uid }
    var isSupported: Bool { unavailableIssue == nil && unavailableReasonText == nil }
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
