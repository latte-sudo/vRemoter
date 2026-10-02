import Foundation

/// Owns one Chromecast voice session. Remote interaction and the application's
/// shortcut semantics are separate: neither a transport START nor a monitor
/// callback is allowed to synthesize a second start shortcut.
///
/// Call on the main queue, as with BLEBridge and DoubaoAudioStateMonitor.
final class ChromecastVoiceSessionController {
    struct DebugSnapshot: Equatable {
        let phase: String
        let generation: UInt64
        let physicalButtonDown: Bool
        let streaming: Bool
        let awaitingHostOpen: Bool
        let syntheticKeyDown: Bool
    }

    private static let maximumOpenAttempts = 3
    private static let openConfirmationTimeout: TimeInterval = 1
    private static let targetConfirmationTimeout: TimeInterval = 1.5
    private static let firstPCMTimeout: TimeInterval = 2
    private static let targetStopConfirmationTimeout: TimeInterval = 1.5
    private static let maximumSessionDuration: TimeInterval = 120
    private static let shortcutTapDuration: TimeInterval = 0.06
    private static let audioTailDuration: TimeInterval = 0.12

    private let configurationProvider: () -> VoiceConfiguration
    private let doubaoState: any DoubaoAudioStateProviding
    private let setRemoteRouteActive: (Bool) -> Bool
    private let triggerDown: (InputTriggerKey) -> Void
    private let triggerUp: (InputTriggerKey) -> Void
    // Inject scheduling rather than wall-clock sleeps into regression tests.
    // Production still uses the main queue and identical relative delays.
    private let schedule: (TimeInterval, DispatchWorkItem) -> Void

    private var machine = ChromecastVoiceStateMachine()
    private var started = false
    private var isFinishing = false
    private var finishEndPulsePending = false
    private var finishReason = ""
    private var finishSendsEndShortcut = false
    private var finishWork: DispatchWorkItem?
    private var monitorStarted = false
    private var routeActive = false
    private var sessionConfiguration: VoiceConfiguration?
    private var targetRecordingConfirmed = false
    private var ownsTargetShortcut = false
    private var keyboardOwnsSession = false
    private var physicalKeyboardDown = false
    private var syntheticKey: InputTriggerKey?
    private var keyPulseGeneration: UInt64 = 0
    private var currentOpenAttempt = 0
    private var openRequestPending = false

    private var keyReleaseWork: DispatchWorkItem?
    private var openRetryWork: DispatchWorkItem?
    private var openConfirmationWork: DispatchWorkItem?
    private var targetConfirmationWork: DispatchWorkItem?
    private var sessionTimeoutWork: DispatchWorkItem?
    private var firstPCMWork: DispatchWorkItem?
    private var targetStopConfirmationWork: DispatchWorkItem?
    private var stopConfirmationGeneration: UInt64 = 0

    var onMicrophoneOpenRequested: ((Bool) -> RemoteMicrophoneOpenResult)?
    var onMicrophoneCloseRequested: (() -> Void)?
    var onStateChanged: ((String) -> Void)?
    var onSessionEnded: (() -> Void)?

    init(
        configurationProvider: @escaping () -> VoiceConfiguration = { AppStorage.voiceConfiguration },
        doubaoState: (any DoubaoAudioStateProviding)? = nil,
        setRemoteRouteActive: @escaping (Bool) -> Bool = { AudioPipe.shared.setRemoteActive($0) },
        triggerDown: @escaping (InputTriggerKey) -> Void = { Key.triggerDown($0) },
        triggerUp: @escaping (InputTriggerKey) -> Void = { Key.triggerUp($0) },
        schedule: @escaping (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.configurationProvider = configurationProvider
        self.doubaoState = doubaoState ?? DoubaoAudioStateMonitor()
        self.setRemoteRouteActive = setRemoteRouteActive
        self.triggerDown = triggerDown
        self.triggerUp = triggerUp
        self.schedule = schedule
    }

    var isActive: Bool { machine.isActive || isFinishing }

    var debugSnapshot: DebugSnapshot {
        DebugSnapshot(
            phase: isFinishing ? "closing" : (!machine.isActive ? "closed" : (targetConfirmationWork == nil && firstPCMWork == nil ? "open" : "opening")),
            generation: machine.generation,
            physicalButtonDown: machine.physicalButtonDown,
            streaming: machine.isStreaming,
            awaitingHostOpen: machine.awaitingHostOpen,
            syntheticKeyDown: syntheticKey != nil
        )
    }

    func start() {
        guard !started else { return }
        started = true
        configureMonitor()
        publish("语音已就绪", "Voice ready")
    }

    /// Call after saving settings. The in-flight key is always released using
    /// the old session's key, even if the newly selected trigger is different.
    func configurationChanged() {
        closeSession(reason: "configuration changed", sendEndShortcut: true, immediateKeyRelease: true)
        if started { configureMonitor() }
    }

    func forceClose() {
        closeSession(reason: "manual close", sendEndShortcut: true, immediateKeyRelease: true)
    }

    /// Sleep and termination use the same synchronous key-up guarantee.
    /// Call start() again after wake before accepting new remote gestures.
    func stop(reason: String = "stopped") {
        closeSession(reason: reason, sendEndShortcut: true, immediateKeyRelease: true)
        started = false
        physicalKeyboardDown = false
        doubaoState.onSnapshotChanged = nil
        doubaoState.stop()
        monitorStarted = false
    }

    func disconnected() {
        physicalKeyboardDown = false
        closeSession(reason: "remote disconnected", sendEndShortcut: true, immediateKeyRelease: true)
        guard !isActive else { return }
        publish("遥控器已断开 · 语音已关闭", "Remote disconnected · voice closed")
    }

    // MARK: - Physical remote and ATVV transport

    func remoteAudioStarted(reason: UInt8) {
        guard started else {
            onMicrophoneCloseRequested?()
            return
        }
        if isFinishing, reason == 0x03, !machine.physicalButtonDown {
            // Finish the previous shortcut before a new deliberate press can
            // start another session. Its delayed tail can never close this one.
            completeFinishingSession(immediateKeyRelease: true)
            guard !isFinishing else { return }
        }
        let configuration = configurationProvider()
        guard configuration.isValid else {
            closeSession(reason: "invalid target configuration", sendEndShortcut: true, immediateKeyRelease: true)
            guard !isActive else { return }
            publish("请先选择输入工具并设置触发键", "Choose an input tool and matching shortcut first")
            return
        }
        let effects = machine.remoteAudioStarted(reason: reason, mode: configuration.remoteVoiceMode)
        if reason == 0x00, machine.isActive, machine.isStreaming {
            cancelOpenWork()
        }
        apply(effects, configuration: configuration, sendShortcut: true, reason: "remote press")
    }

    func remoteAudioStopped(reason: UInt8) {
        let effects = machine.remoteAudioStopped(reason: reason)
        if effects.contains(.requestHostOpen) {
            cancelOpenWork()
        }
        apply(
            effects,
            configuration: sessionConfiguration ?? configurationProvider(),
            sendShortcut: true,
            reason: reason == 0x02 ? "remote release" : "transport stopped",
            immediateKeyRelease: reason != 0x02
        )
    }

    /// Only startup is bounded. Natural pauses never end an active session.
    func remotePCMReceived() {
        guard machine.isActive, firstPCMWork != nil else { return }
        firstPCMWork?.cancel()
        firstPCMWork = nil
        publishActiveState()
    }

    func remoteMicrophoneOpenFailed(code: UInt16) {
        guard machine.isActive, machine.awaitingHostOpen, openRequestPending else { return }
        openRequestPending = false
        openConfirmationWork?.cancel()
        openConfirmationWork = nil
        print("[CAST-VOICE] MIC_OPEN failed code=" + String(format: "0x%04x", code))
        scheduleOpenRetry(after: 0.2, attempt: currentOpenAttempt + 1)
    }

    // MARK: - Physical keyboard: the real key reaches the target itself

    func triggerDownObserved(isSynthetic: Bool) {
        guard started, !isSynthetic, !physicalKeyboardDown else { return }
        physicalKeyboardDown = true
        if isFinishing {
            completeFinishingSession(immediateKeyRelease: true)
            guard !isFinishing else { return }
        }
        let configuration = sessionConfiguration ?? configurationProvider()
        guard configuration.isValid else { return }
        if machine.isActive {
            if configuration.inputToolTriggerMode == .toggle {
                closeSession(reason: "physical shortcut", sendEndShortcut: false, immediateKeyRelease: true)
            }
            return
        }
        let effects = machine.beginFromKeyboard(mode: configuration.remoteVoiceMode)
        apply(effects, configuration: configuration, sendShortcut: false, reason: "physical shortcut")
    }

    func triggerUpObserved(isSynthetic: Bool) {
        guard started, !isSynthetic else { return }
        physicalKeyboardDown = false
        guard keyboardOwnsSession,
              sessionConfiguration?.inputToolTriggerMode == .hold
        else { return }
        closeSession(reason: "physical shortcut released", sendEndShortcut: false, immediateKeyRelease: true)
    }

    // MARK: - Session transitions

    private func apply(
        _ effects: [ChromecastVoiceStateMachine.Effect],
        configuration: VoiceConfiguration,
        sendShortcut: Bool,
        reason: String,
        immediateKeyRelease: Bool = false
    ) {
        for effect in effects {
            switch effect {
            case .beginSession:
                beginSession(configuration: configuration, sendShortcut: sendShortcut)
            case .endSession:
                finishSession(reason: reason, sendEndShortcut: sendShortcut, immediateKeyRelease: immediateKeyRelease)
            case .requestHostOpen:
                // BLEBridge has already cleared isStreaming before the STOP
                // callback. No long-press timer or fixed reopening delay.
                requestHostOpen(bypassDebounce: true, attempt: 1)
            case .rejectStream:
                print("[CAST-VOICE] stale or unsupported AUDIO_START ignored")
                onMicrophoneCloseRequested?()
            }
        }
    }

    private func beginSession(configuration: VoiceConfiguration, sendShortcut: Bool) {
        cancelSessionWork()
        cancelStopConfirmation()
        sessionConfiguration = configuration
        targetRecordingConfirmed = false
        ownsTargetShortcut = sendShortcut
        keyboardOwnsSession = !sendShortcut
        // Validate and start our output before synthesizing a target trigger.
        guard setRouteActive(true) else {
            closeSession(reason: "output startup failed", sendEndShortcut: false, immediateKeyRelease: true)
            guard !isActive else { return }
            publish("虚拟输出启动失败 · 未触发输入工具", "Virtual output failed to start · input tool was not triggered")
            return
        }

        if sendShortcut {
            if configuration.inputToolTriggerMode == .hold {
                releaseSyntheticKey()
                syntheticKey = configuration.triggerKey
                triggerDown(configuration.triggerKey)
            } else {
                tapShortcut(configuration.triggerKey)
            }
        }

        let generation = machine.generation
        let firstPCM = DispatchWorkItem { [weak self] in
            guard let self, self.machine.isActive, self.machine.generation == generation else { return }
            self.firstPCMWork = nil
            self.closeSession(reason: "no first audio packet", sendEndShortcut: true, immediateKeyRelease: true)
            guard !self.isActive else { return }
            self.publish("未收到遥控器音频 · 本地语音已关闭", "No remote audio received · local voice closed")
        }
        firstPCMWork = firstPCM
        schedule(Self.firstPCMTimeout, firstPCM)
        if configuration.usesAuthoritativeAudioMonitor {
            let verification = DispatchWorkItem { [weak self] in
                guard let self, self.machine.isActive, self.machine.generation == generation else { return }
                self.targetConfirmationWork = nil
                if self.doubaoState.snapshotNow().isRecording {
                    self.targetRecordingConfirmed = true
                    self.publishActiveState()
                } else {
                    // Never send another toggle when startup failed: it could
                    // accidentally open an application that was still idle.
                    self.closeSession(reason: "input tool did not start", sendEndShortcut: false, immediateKeyRelease: true)
                    guard !self.isActive else { return }
                    self.publish("输入工具未启动 · 语音已关闭", "Input tool did not start · voice closed")
                }
            }
            targetConfirmationWork = verification
            schedule(Self.targetConfirmationTimeout, verification)
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.machine.isActive, self.machine.generation == generation else { return }
            self.closeSession(reason: "safety timeout", sendEndShortcut: true, immediateKeyRelease: true)
            guard !self.isActive else { return }
            self.publish("录音超时 · 语音已关闭", "Recording timed out · voice closed")
        }
        sessionTimeoutWork = timeout
        schedule(Self.maximumSessionDuration, timeout)
        publishActiveState()
    }

    private func closeSession(reason: String, sendEndShortcut: Bool, immediateKeyRelease: Bool) {
        if isFinishing {
            _ = machine.close()
            completeFinishingSession(immediateKeyRelease: true)
            return
        }
        let wasActive = machine.isActive
        _ = machine.close()
        if wasActive {
            finishSession(reason: reason, sendEndShortcut: sendEndShortcut, immediateKeyRelease: immediateKeyRelease)
        } else {
            cancelSessionWork()
            releaseSyntheticKey()
            let released = setRouteActive(false)
            onMicrophoneCloseRequested?()
            if !released {
                isFinishing = true
                finishSendsEndShortcut = false
                finishReason = reason
                publish("本地音频资源尚未释放 · 请重试停止", "Local audio resources are still closing · retry stop")
            }
        }
    }

    private func finishSession(reason: String, sendEndShortcut: Bool, immediateKeyRelease: Bool) {
        cancelSessionWork()
        isFinishing = true
        finishReason = reason
        finishSendsEndShortcut = sendEndShortcut
        // Stop the source now, while queued PCM gets a small bounded drain
        // through the still-active route and the target's still-open capture.
        onMicrophoneCloseRequested?()
        if immediateKeyRelease {
            completeFinishingSession(immediateKeyRelease: true)
            return
        }
        let generation = machine.generation
        let finish = DispatchWorkItem { [weak self] in
            guard let self, self.isFinishing, self.machine.generation == generation else { return }
            self.completeFinishingSession(immediateKeyRelease: false)
        }
        finishWork = finish
        schedule(Self.audioTailDuration, finish)
    }

    private func completeFinishingSession(immediateKeyRelease: Bool) {
        guard isFinishing else { return }
        finishWork?.cancel()
        finishWork = nil
        // A forced stop/new press during the final pulse must only release
        // it, never send a second stop toggle or report completion twice.
        if finishEndPulsePending {
            releaseSyntheticKey()
            finalizeFinishingSession()
            return
        }
        let configuration = sessionConfiguration
        let reason = finishReason
        let sendEndShortcut = finishSendsEndShortcut
        finishSendsEndShortcut = false
        // Release the old key before clearing its captured configuration.
        releaseSyntheticKey()
        if sendEndShortcut, let configuration, configuration.inputToolTriggerMode == .toggle {
            let shouldSendEnd = !configuration.usesAuthoritativeAudioMonitor
                || doubaoState.snapshotNow().isRecording
                || (!targetRecordingConfirmed && ownsTargetShortcut
                    && (reason == "remote release" || reason == "remote press"))
            if shouldSendEnd {
                if immediateKeyRelease {
                    tapShortcut(configuration.triggerKey, immediateRelease: true)
                } else {
                    finishEndPulsePending = true
                    tapShortcut(configuration.triggerKey, onReleased: { [weak self] in
                        guard let self, self.isFinishing, self.finishEndPulsePending else { return }
                        self.finalizeFinishingSession()
                    })
                    return
                }
            }
        }
        finalizeFinishingSession()
    }

    private func finalizeFinishingSession() {
        guard isFinishing else { return }
        let reason = finishReason
        let configuration = sessionConfiguration
        guard setRouteActive(false) else {
            publish("本地音频资源尚未释放 · 请重试停止", "Local audio resources are still closing · retry stop")
            return
        }
        finishEndPulsePending = false
        ownsTargetShortcut = false
        keyboardOwnsSession = false
        sessionConfiguration = nil
        targetRecordingConfirmed = false
        isFinishing = false
        print("[CAST-VOICE] session closed reason=\(reason) generation=\(machine.generation)")
        publish("本地语音已关闭 · 输入工具停止状态待确认", "Local voice closed · input tool stop not yet confirmed")
        onSessionEnded?()
        confirmTargetStopped(configuration: configuration)
    }

    // Read-only and generation-scoped: old confirmation cannot block or label
    // a new session, and failure never sends a blind toggle or kills a process.
    private func cancelStopConfirmation() {
        stopConfirmationGeneration &+= 1
        targetStopConfirmationWork?.cancel()
        targetStopConfirmationWork = nil
    }

    private func confirmTargetStopped(configuration: VoiceConfiguration?) {
        cancelStopConfirmation()
        guard configuration?.usesAuthoritativeAudioMonitor == true else {
            publish("本地语音已关闭 · 自定义工具停止状态未确认", "Local voice closed · custom tool stop not confirmed")
            return
        }
        let generation = stopConfirmationGeneration
        let confirmation = DispatchWorkItem { [weak self] in
            guard let self, self.stopConfirmationGeneration == generation, !self.isActive else { return }
            self.targetStopConfirmationWork = nil
            switch self.doubaoState.snapshotNow().state {
            case .inactive:
                self.publish("本地语音已关闭 · 已确认豆包停止录音", "Local voice closed · Doubao stopped recording")
            case .active:
                self.publish("本地语音已关闭 · 警告：豆包仍在录音，请在豆包中停止", "Local voice closed · warning: Doubao is still recording; stop it in Doubao")
            case .unavailable:
                self.publish("本地语音已关闭 · 豆包停止状态未确认", "Local voice closed · Doubao stop not confirmed")
            }
        }
        targetStopConfirmationWork = confirmation
        schedule(Self.targetStopConfirmationTimeout, confirmation)
    }

    // MARK: - Bounded host-open continuation

    private func requestHostOpen(bypassDebounce: Bool, attempt: Int) {
        guard machine.isActive, machine.awaitingHostOpen, !openRequestPending else { return }
        guard attempt <= Self.maximumOpenAttempts else {
            failHostOpen()
            return
        }
        currentOpenAttempt = attempt
        let generation = machine.generation
        guard let request = onMicrophoneOpenRequested else {
            failHostOpen()
            return
        }
        let result = request(bypassDebounce)
        // The callback may synchronously close the session.
        guard machine.acceptsHostOpenWork(generation: generation) else { return }
        switch result {
        case .sent:
            openRequestPending = true
            let confirmation = DispatchWorkItem { [weak self] in
                guard let self,
                      self.machine.acceptsHostOpenWork(generation: generation),
                      self.openRequestPending
                else { return }
                self.openRequestPending = false
                self.openConfirmationWork = nil
                self.scheduleOpenRetry(after: 0.05, attempt: attempt + 1)
            }
            openConfirmationWork = confirmation
            schedule(Self.openConfirmationTimeout, confirmation)
        case .alreadyStreaming:
            machine.hostOpenConfirmed()
            cancelOpenWork()
        case .retryAfter(let delay):
            scheduleOpenRetry(after: delay, attempt: attempt + 1)
        case .failed(let message):
            print("[CAST-VOICE] MIC_OPEN failed: \(message)")
            scheduleOpenRetry(after: 0.2, attempt: attempt + 1)
        case .unavailable:
            failHostOpen()
        }
    }

    private func scheduleOpenRetry(after delay: TimeInterval, attempt: Int) {
        guard machine.isActive, machine.awaitingHostOpen else { return }
        guard attempt <= Self.maximumOpenAttempts else {
            failHostOpen()
            return
        }
        openRetryWork?.cancel()
        let generation = machine.generation
        let retry = DispatchWorkItem { [weak self] in
            guard let self, self.machine.acceptsHostOpenWork(generation: generation) else { return }
            self.openRetryWork = nil
            self.requestHostOpen(bypassDebounce: true, attempt: attempt)
        }
        openRetryWork = retry
        // Prevent malformed transport responses from scheduling unbounded
        // waits, while honoring BLEBridge's ordinary debounce interval.
        let boundedDelay = delay.isFinite ? min(max(delay, 0.01), 2) : 0.2
        schedule(boundedDelay, retry)
    }

    private func failHostOpen() {
        closeSession(reason: "microphone reopen failed", sendEndShortcut: true, immediateKeyRelease: true)
        guard !isActive else { return }
        publish("遥控器音频连接失败 · 语音已关闭", "Remote audio failed · voice closed")
    }

    // MARK: - Target observation and key ownership

    private func configureMonitor() {
        doubaoState.onSnapshotChanged = nil
        doubaoState.stop()
        monitorStarted = configurationProvider().usesAuthoritativeAudioMonitor
        guard monitorStarted else { return }
        doubaoState.onSnapshotChanged = { [weak self] snapshot in
            self?.handleTargetSnapshot(snapshot)
        }
        doubaoState.start()
    }

    private func handleTargetSnapshot(_ snapshot: DoubaoAudioStateMonitor.Snapshot) {
        guard started, monitorStarted, machine.isActive,
              sessionConfiguration?.usesAuthoritativeAudioMonitor == true
        else { return }
        switch snapshot.state {
        case .active:
            targetRecordingConfirmed = true
            targetConfirmationWork?.cancel()
            targetConfirmationWork = nil
            publishActiveState()
        case .inactive, .unavailable:
            // Idle snapshots during launch are transient. Once a real active
            // capture was observed, ending it is authoritative and must not
            // synthesize a toggle that would start it again.
            guard targetRecordingConfirmed else { return }
            closeSession(reason: "input tool stopped", sendEndShortcut: false, immediateKeyRelease: true)
        }
    }

    private func tapShortcut(
        _ key: InputTriggerKey,
        immediateRelease: Bool = false,
        onReleased: (() -> Void)? = nil
    ) {
        releaseSyntheticKey()
        syntheticKey = key
        triggerDown(key)
        if immediateRelease {
            releaseSyntheticKey()
            onReleased?()
            return
        }
        let pulse = keyPulseGeneration
        let release = DispatchWorkItem { [weak self] in
            guard let self, self.keyPulseGeneration == pulse else { return }
            self.releaseSyntheticKey()
            onReleased?()
        }
        keyReleaseWork = release
        schedule(Self.shortcutTapDuration, release)
    }

    private func releaseSyntheticKey() {
        keyPulseGeneration &+= 1
        keyReleaseWork?.cancel()
        keyReleaseWork = nil
        guard let key = syntheticKey else { return }
        syntheticKey = nil
        triggerUp(key)
    }

    private func cancelOpenWork() {
        openRequestPending = false
        openRetryWork?.cancel()
        openRetryWork = nil
        openConfirmationWork?.cancel()
        openConfirmationWork = nil
    }

    private func cancelSessionWork() {
        cancelOpenWork()
        firstPCMWork?.cancel()
        firstPCMWork = nil
        targetConfirmationWork?.cancel()
        targetConfirmationWork = nil
        sessionTimeoutWork?.cancel()
        sessionTimeoutWork = nil
    }

    @discardableResult
    private func setRouteActive(_ active: Bool) -> Bool {
        // Idle cleanup also releases a temporary tone or a partially-started
        // device left by a failed acquisition.
        if active && routeActive { return true }
        guard setRemoteRouteActive(active) else { return false }
        routeActive = active
        return true
    }

    private func publishActiveState() {
        if firstPCMWork != nil || targetConfirmationWork != nil {
            publish("语音启动中 · 等待音频确认", "Voice starting · awaiting audio confirmation")
        } else {
            publish("录音中", "Recording")
        }
    }

    private func publish(_ chinese: String, _ english: String) {
        onStateChanged?(L10n.text(chinese, english))
    }
}
