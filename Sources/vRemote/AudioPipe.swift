// vRemote selectable virtual-output audio pipe.
//
// MacBook microphone -> AVCaptureSession ----┐
//                                             ├-> aligned equal mix -> selected virtual output
// Chromecast ATVV ADPCM -> decoded Int16 PCM --┘
//
// Both microphones are peers. Neither source permanently wins or ducks the
// other. The Mac path is delayed slightly to compensate for BLE transport
// latency, then the two available signals are averaged and hard-limited.

import AVFoundation
import AudioToolbox
import CoreAudio
import CoreMedia
import Foundation

final class AudioPipe: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    static let shared = AudioPipe()

    private enum InputSource {
        case mac
        case remote
    }

    private static let targetDeviceName = AudioRouteConfiguration.defaultOutputName
    private static let defaultOutputSampleRate: Double = 48_000

    // The Mac capture path usually arrives before BLE voice frames. Keeping a
    // small Mac backlog makes the same spoken syllable from both microphones
    // meet in the same render window. This first experimental value is shown
    // in logs and can be tuned from real recordings later.
    private static let macAlignmentDelaySeconds = 0.12

    private let captureSession = AVCaptureSession()
    private let captureQueue = DispatchQueue(
        label: "local.simaqingfeng.vRemote.capture",
        qos: .userInteractive
    )

    private let captureQueueKey = DispatchSpecificKey<Bool>()
    private let stateLock = NSLock()
    // Serializes CoreAudio start/stop outside the render state lock. CoreAudio
    // may wait for a render callback while stopping an IOProc.
    private let routeLock = NSRecursiveLock()
    private var availableRoutes: [AudioOutputRoute] = []
    private var selectedUID = AudioRouteConfiguration.selectedOutputUID
    private var gain = AudioRouteConfiguration.remoteGain
    private var outputSampleRate = AudioPipe.defaultOutputSampleRate
    private var routeGeneration: UInt64 = 0
    private var outputRoute: AudioOutputRoute?
    private var routeError: String?
    private var deviceListListener: AudioObjectPropertyListenerBlock?
    private var boundRouteListener: AudioObjectPropertyListenerBlock?
    private var boundRouteProperties: [(AudioObjectID, AudioObjectPropertyAddress)] = []
    private var stopped = false
    private var pendingTestTone: [Float] = []
    private var pendingTestToneIndex = 0
    private var resourceLease = AudioResourceLease()
    private var mixActive = false
    private var macInputEnabled = AppStorage.macInputEnabled
    private var remoteInputEnabled = AppStorage.remoteInputEnabled
    private var outputDeviceID: AudioDeviceID?
    private var outputIOProcID: AudioDeviceIOProcID?

    private var pendingMac: [Float] = []
    private var pendingMacIndex = 0
    private var pendingRemote: [Float] = []
    private var pendingRemoteIndex = 0

    private var scheduledMacBuffers = 0
    private var scheduledRemoteBuffers = 0
    private var scheduledPeak: Float = 0
    private var renderCallbackCount = 0
    private var remoteSessionScheduledBuffers = 0
    private var remoteSessionRenderedFrames = 0
    private var loggedFirstRemoteRender = false
    private var diagnosticsTimer: Timer?

    /// Configuration notifications are delivered on the main queue.
    var onConfigurationChanged: (() -> Void)?
    var onMacLevel: ((Double) -> Void)?
    var onRouteChanged: ((Bool) -> Void)?
    /// Invoked synchronously when discovery invalidates an active session.
    var onResourcesInvalidated: (() -> Void)?
    private var macLevelAt = Date.distantPast
    private var captureConfigured = false

    private override init() {
        super.init()
        captureQueue.setSpecific(key: captureQueueKey, value: true)

        refreshOutputRoutes()
        installDeviceListListener()

        if ProcessInfo.processInfo.environment["MIA_DIAGNOSTICS"] == "1" {
            startDiagnosticsTimer()
        }
        // Discovery and listeners are idle-safe. Physical capture and the
        // virtual-output IOProc are leased only by an explicit voice session.
    }

    // MARK: - Public input API

    func feed(samples: [Int16], inputSampleRate: Double = 16_000) {
        guard !samples.isEmpty else { return }
        let state = inputState
        guard state.mixActive, state.remoteEnabled else { return }
        let floatSamples = samples.map { sample -> Float in
            let amplified = Float(sample) / 32768.0 * state.remoteGain
            return max(-1.0, min(1.0, amplified))
        }
        schedule(
            monoSamples: floatSamples,
            sampleRate: inputSampleRate,
            source: .remote
        )
    }

    /// Opens or closes the selected output route for a remote voice session.
    /// This product disables Mac microphone input, including on upgrade.
    @discardableResult
    func setRemoteActive(_ active: Bool) -> Bool {
        routeLock.lock()
        defer { routeLock.unlock() }
        if !active {
            return stopOutputDevice()
        }
        guard !stopped else { return false }
        // Validate the saved UID and current stream format before every start.
        refreshOutputRoutes()
        if isMixActive { return true }
        guard stopOutputDevice() else { return false } // Interrupt any tone.
        stateLock.lock()
        let deviceID = outputDeviceID
        let route = outputRoute
        stateLock.unlock()
        guard isOutputDeviceAvailable, let deviceID, let route,
              startOutputDevice(deviceID, route: route) else { return false }
        stateLock.lock()
        _ = resourceLease.acquire(.session)
        mixActive = true
        remoteSessionScheduledBuffers = 0
        remoteSessionRenderedFrames = 0
        loggedFirstRemoteRender = false
        stateLock.unlock()
        setMacCaptureEnabled(true)
        print("[AUDIO] 语音输出开启 · Chromecast · Mac 混音按设置启用")
        onRouteChanged?(true)
        notifyConfigurationChanged()
        return true
    }

    func setInputEnabled(mac: Bool, remote: Bool) {
        stateLock.lock()
        let macChanged = macInputEnabled != mac
        let remoteChanged = remoteInputEnabled != remote
        macInputEnabled = mac
        remoteInputEnabled = remote
        if !mac {
            pendingMac.removeAll(keepingCapacity: true)
            pendingMacIndex = 0
        }
        if !remote {
            pendingRemote.removeAll(keepingCapacity: true)
            pendingRemoteIndex = 0
        }
        stateLock.unlock()

        AppStorage.macInputEnabled = mac
        AppStorage.remoteInputEnabled = remote

        if macChanged {
            setMacCaptureEnabled(mac)
            if !mac { onMacLevel?(-120) }
        }
        if macChanged || remoteChanged {
            print(
                "[AUDIO] 输入选择更新 · MacBook=\(mac ? "ON" : "OFF") " +
                "Chromecast=\(remote ? "ON" : "OFF")"
            )
            onRouteChanged?(isMixActive)
            notifyConfigurationChanged()
        }
    }

    var isMacInputEnabled: Bool { inputState.macEnabled }
    var isRemoteInputEnabled: Bool { inputState.remoteEnabled }
    var isOutputDeviceAvailable: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard outputDeviceID != nil, let route = outputRoute,
              route.uid == selectedUID, route.isSupported else { return false }
        return availableRoutes.contains(route)
    }

    var outputRoutes: [AudioOutputRoute] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return availableRoutes
    }

    var selectedOutputUID: String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return selectedUID
    }

    var remoteGain: Float {
        stateLock.lock()
        defer { stateLock.unlock() }
        return gain
    }

    var isTestTonePlaying: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return pendingTestToneIndex < pendingTestTone.count
    }

    func setRemoteGain(_ value: Float) {
        let safeGain = AudioRouteConfiguration.clampedGain(value)
        stateLock.lock()
        gain = safeGain
        stateLock.unlock()
        AudioRouteConfiguration.remoteGain = safeGain
        notifyConfigurationChanged()
    }

    /// Re-enumerate devices and rebind by UID. A missing saved route is never
    /// replaced with the system output or another virtual microphone.
    func refreshOutputRoutes() {
        routeLock.lock()
        defer { routeLock.unlock() }
        guard !stopped else { return }
        let discovered = Self.discoverOutputRoutes()
        let savedUID = AudioRouteConfiguration.selectedOutputUID
        let savedGain = AudioRouteConfiguration.remoteGain
        stateLock.lock()
        // Import/reset writes preferences directly. A refresh is also the
        // explicit reload boundary for those operations.
        selectedUID = savedUID
        gain = savedGain
        availableRoutes = discovered.map { $0.route }
        if !AudioRouteConfiguration.hasOutputSelection {
            selectedUID = AudioRouteConfiguration.preferredOutputUID(
                in: availableRoutes, savedUID: selectedUID, hasSavedSelection: false
            )
            if let selectedUID { AudioRouteConfiguration.selectedOutputUID = selectedUID }
        }
        let uid = selectedUID
        let currentID = outputDeviceID
        let currentRoute = outputRoute
        stateLock.unlock()

        guard let uid else {
            guard unbindOutputDevice() else { return }
            updateRouteError("未选择虚拟输出设备")
            return
        }
        guard let selected = discovered.first(where: { $0.route.uid == uid }) else {
            guard unbindOutputDevice() else { return }
            updateRouteError("已保存的输出设备不可用；请连接设备后刷新，或重新选择")
            return
        }
        guard selected.route.isSupported else {
            guard unbindOutputDevice() else { return }
            updateRouteError(selected.route.unavailableReason)
            return
        }
        if currentID == selected.id, currentRoute == selected.route {
            stateLock.lock()
            if outputIOProcID == nil || resourceLease.current != nil { routeError = nil }
            stateLock.unlock()
            notifyConfigurationChanged()
            return
        }
        guard unbindOutputDevice() else { return }
        stateLock.lock()
        outputDeviceID = selected.id
        outputRoute = selected.route
        outputSampleRate = selected.route.sampleRate
        routeError = nil
        stateLock.unlock()
        installBoundRouteListeners(selected.id)
        notifyConfigurationChanged()
    }

    @discardableResult
    func selectOutputRoute(uid: String?) -> Bool {
        routeLock.lock()
        defer { routeLock.unlock() }
        stateLock.lock()
        selectedUID = uid
        stateLock.unlock()
        AudioRouteConfiguration.selectedOutputUID = uid
        refreshOutputRoutes()
        return uid == nil || isOutputDeviceAvailable
    }

    /// Auditions only the bound virtual output. It never changes the system
    /// default input/output and refuses to inject a tone into active dictation.
    @discardableResult
    func playTestTone() -> Bool {
        routeLock.lock()
        defer { routeLock.unlock() }
        guard !stopped, !isMixActive else { return false }
        refreshOutputRoutes()
        guard stopOutputDevice() else { return false }
        stateLock.lock()
        let deviceID = outputDeviceID
        let route = outputRoute
        stateLock.unlock()
        guard isOutputDeviceAvailable, let deviceID, let route else {
            updateRouteError("测试音未播放：请先选择可用的虚拟输出设备")
            return false
        }
        let tone = AudioRouteConfiguration.testTone(sampleRate: route.sampleRate)
        guard !tone.isEmpty, startOutputDevice(deviceID, route: route) else { return false }
        stateLock.lock()
        let token = resourceLease.acquire(.testTone)
        pendingTestTone = tone
        pendingTestToneIndex = 0
        routeError = nil
        stateLock.unlock()
        // Also bound the lease if the device stops delivering render callbacks.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.finishTestTone(token)
        }
        notifyConfigurationChanged()
        return true
    }

    private func finishTestTone(_ token: AudioResourceLease.Token) {
        routeLock.lock()
        defer { routeLock.unlock() }
        stateLock.lock()
        let owned = resourceLease.release(token)
        stateLock.unlock()
        guard owned else { return }
        stopOutputDevice()
        notifyConfigurationChanged()
    }

    var routeDiagnostics: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        var lines: [String] = []
        if let route = outputRoute {
            lines.append("输出：\(route.name) · \(Int(route.sampleRate)) Hz · \(route.channelCount) 声道")
            lines.append("UID：\(route.uid)")
            lines.append(outputIOProcID == nil ? "输出资源：空闲（会话开启时启动）" : "输出资源：已持有")
        } else {
            lines.append("输出未就绪")
            if let selectedUID = selectedUID { lines.append("已选 UID：\(selectedUID)") }
        }
        lines.append(String(format: "遥控器增益：%.1f× · Mac 麦克风：%@", gain, macInputEnabled ? "开" : "关"))
        if pendingTestToneIndex < pendingTestTone.count { lines.append("正在发送 1 秒测试音") }
        if let routeError { lines.append(routeError) }
        lines.append("请在豆包中手动选择同一虚拟设备；系统默认输入保持不变")
        return lines.joined(separator: "\n")
    }

    func stop() {
        diagnosticsTimer?.invalidate()
        diagnosticsTimer = nil

        stateLock.lock()
        macInputEnabled = false
        mixActive = false
        clearPendingBuffersLocked()
        stateLock.unlock()
        setMacCaptureEnabled(false)

        routeLock.lock()
        stopped = true
        removeDeviceListListener()
        unbindOutputDevice()
        routeLock.unlock()
        stateLock.lock()
        mixActive = false
        clearPendingBuffersLocked()
        stateLock.unlock()
    }

    // MARK: - Built-in microphone capture

    private func requestBuiltInMicAccess() {
        guard shouldCaptureMac else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startBuiltInMicCapture()
        case .notDetermined:
            print("[AUDIO] 请求 MacBook 麦克风权限…")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startBuiltInMicCapture()
                    } else {
                        print("[AUDIO] ⚠️ MacBook 麦克风权限被拒绝")
                    }
                }
            }
        default:
            print("[AUDIO] ⚠️ 没有 MacBook 麦克风权限；当前只能收到 Chromecast 音频")
        }
    }

    private func startBuiltInMicCapture() {
        captureQueue.async { [weak self] in
            self?.configureAndStartBuiltInMicCapture()
        }
    }

    private func configureAndStartBuiltInMicCapture() {
        guard shouldCaptureMac else { return }
        if captureConfigured {
            startCaptureIfNeeded()
            return
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified
        )
        let device = discovery.devices.first {
            $0.uniqueID == "BuiltInMicrophoneDevice"
        } ?? discovery.devices.first {
            $0.localizedName.localizedCaseInsensitiveContains("MacBook")
        }
        guard let device else {
            print("[AUDIO] ⚠️ 找不到 MacBook 内置麦克风")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioDataOutput()
            output.audioSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: 1,
            ]
            output.setSampleBufferDelegate(self, queue: captureQueue)

            captureSession.beginConfiguration()
            guard captureSession.canAddInput(input),
                  captureSession.canAddOutput(output)
            else {
                captureSession.commitConfiguration()
                print("[AUDIO] ⚠️ 无法建立 MacBook 麦克风采集会话")
                return
            }
            captureSession.addInput(input)
            captureSession.addOutput(output)
            captureSession.commitConfiguration()
            captureConfigured = true

            startCaptureIfNeeded()
        } catch {
            print("[AUDIO] ⚠️ MacBook 麦克风采集失败: \(error.localizedDescription)")
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard shouldCaptureMac,
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
                formatDescription
              ),
              streamDescription.pointee.mFormatID == kAudioFormatLinearPCM,
              streamDescription.pointee.mBitsPerChannel == 32,
              streamDescription.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        else { return }

        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount >= MemoryLayout<Float>.size else { return }
        var data = Data(count: byteCount)
        let copyStatus = data.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: bytes.baseAddress!
            )
        }
        guard copyStatus == kCMBlockBufferNoErr else { return }

        let channels = max(1, Int(streamDescription.pointee.mChannelsPerFrame))
        let floats: [Float] = data.withUnsafeBytes { rawBuffer in
            let values = rawBuffer.bindMemory(to: Float.self)
            if channels == 1 {
                return Array(values)
            }
            let frameCount = values.count / channels
            return (0..<frameCount).map { frame in
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += values[frame * channels + channel]
                }
                return sum / Float(channels)
            }
        }

        if Date().timeIntervalSince(macLevelAt) >= 0.1 {
            let sumSquares = floats.reduce(0.0) { $0 + Double($1 * $1) }
            let rms = floats.isEmpty ? 0 : sqrt(sumSquares / Double(floats.count))
            let db = rms > 0 ? 20.0 * log10(rms) : -120
            onMacLevel?(db)
            macLevelAt = Date()
        }

        guard isMixActive else { return }
        schedule(
            monoSamples: floats,
            sampleRate: streamDescription.pointee.mSampleRate,
            source: .mac
        )
    }

    // MARK: - Queues and resampling

    private var isMixActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return mixActive
    }

    private var inputState: (mixActive: Bool, macEnabled: Bool, remoteEnabled: Bool, remoteGain: Float) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (mixActive, macInputEnabled, remoteInputEnabled, gain)
    }

    private var shouldCaptureMac: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return resourceLease.shouldCaptureMac(enabled: macInputEnabled, mixActive: mixActive)
    }

    // Only called on captureQueue. Check again after the blocking start because
    // a stop, route loss or preference change may arrive while it is starting.
    private func startCaptureIfNeeded() {
        guard shouldCaptureMac, !captureSession.isRunning else { return }
        captureSession.startRunning()
        if !shouldCaptureMac, captureSession.isRunning { captureSession.stopRunning() }
    }

    @discardableResult
    private func setMacCaptureEnabled(_ enabled: Bool) -> Bool {
        if enabled, shouldCaptureMac {
            requestBuiltInMicAccess()
            return true
        }
        let stopCapture = { [self] () -> Bool in
            if !shouldCaptureMac, captureSession.isRunning { captureSession.stopRunning() }
            return !captureSession.isRunning
        }
        // Drain pending starts before reporting the session closed. Avoid sync
        // dispatch to our own queue if a capture delegate closes the session.
        if DispatchQueue.getSpecific(key: captureQueueKey) == true {
            return stopCapture()
        } else {
            return captureQueue.sync(execute: stopCapture)
        }
    }

    private func schedule(
        monoSamples: [Float],
        sampleRate: Double,
        source: InputSource
    ) {
        guard !monoSamples.isEmpty, sampleRate.isFinite, (8_000...192_000).contains(sampleRate) else { return }
        stateLock.lock()
        let targetRate = outputSampleRate
        let generation = routeGeneration
        let hasOutput = outputIOProcID != nil
        stateLock.unlock()
        guard hasOutput else { return }
        let resampled = Self.resample(
            monoSamples,
            from: sampleRate,
            to: targetRate
        )
        guard !resampled.isEmpty else { return }

        stateLock.lock()
        let sourceEnabled = source == .mac ? macInputEnabled : remoteInputEnabled
        guard mixActive, sourceEnabled, generation == routeGeneration, outputIOProcID != nil else {
            stateLock.unlock()
            return
        }

        var firstRemoteBufferDescription: String?
        switch source {
        case .mac:
            compactMacBufferIfNeededLocked()
            pendingMac.append(contentsOf: resampled)
            scheduledMacBuffers += 1

        case .remote:
            compactRemoteBufferIfNeededLocked()
            pendingRemote.append(contentsOf: resampled)
            scheduledRemoteBuffers += 1
            remoteSessionScheduledBuffers += 1
            if remoteSessionScheduledBuffers == 1 {
                let peak = resampled.reduce(0) { max($0, abs($1)) }
                firstRemoteBufferDescription = String(
                    format: "[AUDIO] Chromecast 首缓冲 frames=%d peak=%.4f",
                    resampled.count,
                    peak
                )
            }
        }
        scheduledPeak = max(
            scheduledPeak,
            resampled.reduce(0) { max($0, abs($1)) }
        )
        stateLock.unlock()

        if let firstRemoteBufferDescription {
            print(firstRemoteBufferDescription)
        }
    }

    private static func resample(
        _ input: [Float],
        from inputRate: Double,
        to outputRate: Double
    ) -> [Float] {
        if abs(inputRate - outputRate) < 1 {
            return input
        }
        let ratio = outputRate / inputRate
        let outputCount = max(1, Int((Double(input.count) * ratio).rounded(.down)))
        var output = [Float](repeating: 0, count: outputCount)
        for index in 0..<outputCount {
            let position = Double(index) / ratio
            let lower = min(Int(position), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(position - Double(lower))
            output[index] = input[lower] + (input[upper] - input[lower]) * fraction
        }
        return output
    }

    // MARK: - CoreAudio direct output

    private func startOutputDevice(_ deviceID: AudioDeviceID, route: AudioOutputRoute) -> Bool {
        stateLock.lock()
        let hasUnreleasedOutput = outputIOProcID != nil
        stateLock.unlock()
        guard !hasUnreleasedOutput else {
            updateRouteError("输出清理未完成；请重试关闭会话")
            return false
        }
        var ioProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &ioProcID,
            deviceID,
            nil
        ) { [weak self] _, _, _, outputData, _ in
            self?.render(outputData)
        }
        guard createStatus == noErr, let ioProcID else {
            updateRouteError("创建输出失败：OSStatus=\(createStatus)")
            return false
        }

        stateLock.lock()
        outputSampleRate = route.sampleRate
        routeGeneration &+= 1
        clearPendingBuffersLocked()
        stateLock.unlock()
        let startStatus = AudioDeviceStart(deviceID, ioProcID)
        guard startStatus == noErr else {
            let destroyStatus = AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            if destroyStatus != noErr {
                stateLock.lock()
                outputIOProcID = ioProcID
                stateLock.unlock()
            }
            updateRouteError("启动输出失败：OSStatus=\(startStatus)，清理=\(destroyStatus)")
            return false
        }

        stateLock.lock()
        outputDeviceID = deviceID
        outputIOProcID = ioProcID
        outputRoute = route
        routeError = nil
        stateLock.unlock()
        print("[AUDIO] 输出已启动：\(route.name) · \(Int(route.sampleRate)) Hz · UID=\(route.uid)")
        return true
    }

    @discardableResult
    private func stopOutputDevice() -> Bool {
        stateLock.lock()
        let deviceID = outputDeviceID
        let ioProcID = outputIOProcID
        let wasActive = mixActive
        mixActive = false
        resourceLease.invalidate()
        routeGeneration &+= 1
        clearPendingBuffersLocked()
        pendingTestTone.removeAll(keepingCapacity: true)
        pendingTestToneIndex = 0
        stateLock.unlock()
        var released = true
        if let deviceID, let ioProcID {
            let stopStatus = AudioDeviceStop(deviceID, ioProcID)
            let destroyStatus = AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            released = destroyStatus == noErr
            if released {
                stateLock.lock()
                outputIOProcID = nil
                stateLock.unlock()
            }
            if stopStatus != noErr || destroyStatus != noErr {
                updateRouteError("输出清理：停止=\(stopStatus)，销毁=\(destroyStatus)")
            }
        }
        let captureStopped = setMacCaptureEnabled(false)
        if !captureStopped { updateRouteError("Mac 麦克风采集尚未停止；请重试关闭会话") }
        released = released && captureStopped
        if wasActive {
            print("[AUDIO] 语音输出关闭")
            onRouteChanged?(false)
        }
        notifyConfigurationChanged()
        return released
    }

    @discardableResult
    private func unbindOutputDevice() -> Bool {
        let invalidatedSession = isMixActive
        let released = stopOutputDevice()
        if invalidatedSession { onResourcesInvalidated?() }
        guard released else { return false }
        removeBoundRouteListeners()
        stateLock.lock()
        outputDeviceID = nil
        outputRoute = nil
        stateLock.unlock()
        return true
    }

    private func notifyConfigurationChanged() {
        DispatchQueue.main.async { [weak self] in self?.onConfigurationChanged?() }
    }

    private func updateRouteError(_ message: String?) {
        stateLock.lock()
        routeError = message
        stateLock.unlock()
        if let message { print("[AUDIO] \(message)") }
        notifyConfigurationChanged()
    }

    private func installDeviceListListener() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Do not remove/rebuild listeners from inside a CoreAudio listener.
            DispatchQueue.main.async { [weak self] in self?.refreshOutputRoutes() }
        }
        var address = Self.propertyAddress(kAudioHardwarePropertyDevices)
        if AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener
        ) == noErr {
            deviceListListener = listener
        }
    }

    private func removeDeviceListListener() {
        guard let listener = deviceListListener else { return }
        var address = Self.propertyAddress(kAudioHardwarePropertyDevices)
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener
        )
        deviceListListener = nil
    }

    private func installBoundRouteListeners(_ deviceID: AudioDeviceID) {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Do not remove/rebuild listeners from inside a CoreAudio listener.
            DispatchQueue.main.async { [weak self] in self?.refreshOutputRoutes() }
        }
        var properties: [(AudioObjectID, AudioObjectPropertyAddress)] = [
            (deviceID, Self.propertyAddress(kAudioDevicePropertyDeviceIsAlive)),
            (deviceID, Self.propertyAddress(kAudioDevicePropertyNominalSampleRate)),
            (deviceID, Self.propertyAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)),
        ]
        properties += Self.outputStreams(deviceID).map {
            ($0, Self.propertyAddress(kAudioStreamPropertyVirtualFormat))
        }
        for (objectID, property) in properties {
            var address = property
            if AudioObjectAddPropertyListenerBlock(objectID, &address, .main, listener) == noErr {
                boundRouteProperties.append((objectID, property))
            }
        }
        boundRouteListener = listener
    }

    private func removeBoundRouteListeners() {
        if let listener = boundRouteListener {
            for (objectID, property) in boundRouteProperties {
                var address = property
                AudioObjectRemovePropertyListenerBlock(objectID, &address, .main, listener)
            }
        }
        boundRouteProperties.removeAll()
        boundRouteListener = nil
    }

    private func render(_ outputData: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(outputData)
        for buffer in buffers {
            if let data = buffer.mData {
                memset(data, 0, Int(buffer.mDataByteSize))
            }
        }
        guard let first = buffers.first else { return }
        let firstChannels = max(1, Int(first.mNumberChannels))
        let frameCount = Int(first.mDataByteSize) /
            MemoryLayout<Float>.size /
            firstChannels
        guard frameCount > 0 else { return }

        var mac = [Float](repeating: 0, count: frameCount)
        var remote = [Float](repeating: 0, count: frameCount)
        var mixed = [Float](repeating: 0, count: frameCount)
        var macTaken = 0
        var remoteTaken = 0
        var firstRemoteRenderDescription: String?
        var toneTaken = 0
        var completedTone: AudioResourceLease.Token?

        stateLock.lock()
        let toneAvailable = pendingTestTone.count - pendingTestToneIndex
        if toneAvailable > 0 {
            toneTaken = min(frameCount, toneAvailable)
            mixed.replaceSubrange(
                0..<toneTaken,
                with: pendingTestTone[pendingTestToneIndex..<(pendingTestToneIndex + toneTaken)]
            )
            pendingTestToneIndex += toneTaken
            if pendingTestToneIndex == pendingTestTone.count {
                completedTone = resourceLease.current
            }
        }
        if mixActive {
            let remoteAvailable = pendingRemote.count - pendingRemoteIndex
            if remoteAvailable > 0 {
                remoteTaken = min(frameCount, remoteAvailable)
                remote.replaceSubrange(
                    0..<remoteTaken,
                    with: pendingRemote[
                        pendingRemoteIndex..<(pendingRemoteIndex + remoteTaken)
                    ]
                )
                pendingRemoteIndex += remoteTaken
                remoteSessionRenderedFrames += remoteTaken
                if !loggedFirstRemoteRender {
                    loggedFirstRemoteRender = true
                    let peak = remote.reduce(0) { max($0, abs($1)) }
                    firstRemoteRenderDescription = String(
                        format: "[AUDIO] Chromecast 首次输出 frames=%d peak=%.4f",
                        remoteTaken,
                        peak
                    )
                }
            }

            let macAvailable = pendingMac.count - pendingMacIndex
            let macReady = max(0, macAvailable - macAlignmentDelayFrames)
            if macReady > 0 {
                macTaken = min(frameCount, macReady)
                mac.replaceSubrange(
                    0..<macTaken,
                    with: pendingMac[pendingMacIndex..<(pendingMacIndex + macTaken)]
                )
                pendingMacIndex += macTaken
            }

            compactRemoteBufferIfNeededLocked()
            compactMacBufferIfNeededLocked()
        }
        renderCallbackCount += 1
        stateLock.unlock()

        if let firstRemoteRenderDescription {
            print(firstRemoteRenderDescription)
        }

        if let completedTone {
            // CoreAudio stop/destroy must never run inside its render callback.
            DispatchQueue.main.async { [weak self] in self?.finishTestTone(completedTone) }
        }
        for frame in toneTaken..<frameCount {
            let hasMac = frame < macTaken
            let hasRemote = frame < remoteTaken
            let value: Float
            if hasMac && hasRemote {
                // Equal, source-agnostic mix. Averaging preserves headroom and
                // prevents the +6 dB overload caused by raw summation.
                value = (mac[frame] + remote[frame]) * 0.5
            } else if hasMac {
                value = mac[frame]
            } else if hasRemote {
                value = remote[frame]
            } else {
                value = 0
            }
            mixed[frame] = max(-1.0, min(1.0, value))
        }

        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let channelCount = max(1, Int(buffer.mNumberChannels))
            let writableFrames = min(
                frameCount,
                Int(buffer.mDataByteSize) /
                    MemoryLayout<Float>.size /
                    channelCount
            )
            let output = data.assumingMemoryBound(to: Float.self)
            for frame in 0..<writableFrames {
                for channel in 0..<channelCount {
                    output[frame * channelCount + channel] = mixed[frame]
                }
            }
        }
    }

    private func clearPendingBuffersLocked() {
        pendingMac.removeAll(keepingCapacity: true)
        pendingMacIndex = 0
        pendingRemote.removeAll(keepingCapacity: true)
        pendingRemoteIndex = 0
    }

    private func compactMacBufferIfNeededLocked() {
        if pendingMacIndex > 4_096 {
            pendingMac.removeFirst(pendingMacIndex)
            pendingMacIndex = 0
        }
        trimBufferIfNeededLocked(
            bufferCount: pendingMac.count,
            index: &pendingMacIndex,
            extraFrames: macAlignmentDelayFrames
        )
    }

    private func compactRemoteBufferIfNeededLocked() {
        if pendingRemoteIndex > 4_096 {
            pendingRemote.removeFirst(pendingRemoteIndex)
            pendingRemoteIndex = 0
        }
        trimBufferIfNeededLocked(
            bufferCount: pendingRemote.count,
            index: &pendingRemoteIndex,
            extraFrames: 0
        )
    }

    private func trimBufferIfNeededLocked(
        bufferCount: Int,
        index: inout Int,
        extraFrames: Int
    ) {
        let maximumQueuedFrames = Int(outputSampleRate * 2) + extraFrames
        let available = bufferCount - index
        if available > maximumQueuedFrames {
            index += available - maximumQueuedFrames
        }
    }

    private var macAlignmentDelayFrames: Int {
        Int(outputSampleRate * Self.macAlignmentDelaySeconds)
    }

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func objectIDs(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID] {
        var address = propertyAddress(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr,
              size > 0, Int(size) % MemoryLayout<AudioObjectID>.size == 0 else { return [] }
        var values = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = values.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, bytes.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(values.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private static func outputStreams(_ deviceID: AudioDeviceID) -> [AudioStreamID] {
        objectIDs(deviceID, selector: kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
    }

    private static func stringProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = propertyAddress(selector)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value?.takeRetainedValue() as String?
    }

    private static func integerProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = propertyAddress(selector)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private static func discoverOutputRoutes() -> [(id: AudioDeviceID, route: AudioOutputRoute)] {
        let devices = objectIDs(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices)
        var routes: [(id: AudioDeviceID, route: AudioOutputRoute)] = []
        for deviceID in devices {
            guard let name = stringProperty(deviceID, selector: kAudioObjectPropertyName),
                  let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID),
                  !uid.isEmpty else { continue }
            let transport = integerProperty(deviceID, selector: kAudioDevicePropertyTransportType)
            // The bundled loopback driver's device transport intentionally
            // presents as USB because some dictation apps filter virtual devices.
            let bundledDriver = name.caseInsensitiveCompare(targetDeviceName) == .orderedSame
            guard bundledDriver || transport == kAudioDeviceTransportTypeVirtual else { continue }
            let streams = outputStreams(deviceID)
            guard !streams.isEmpty else { continue }
            var rate: Double = 0
            var channels: UInt32 = 0
            var unavailable: String?
            if integerProperty(deviceID, selector: kAudioDevicePropertyDeviceIsAlive) == 0 {
                unavailable = "设备当前离线"
            }
            for streamID in streams {
                var format = AudioStreamBasicDescription()
                var address = propertyAddress(kAudioStreamPropertyVirtualFormat)
                var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                guard AudioObjectGetPropertyData(streamID, &address, 0, nil, &size, &format) == noErr else {
                    unavailable = "无法读取输出格式"
                    continue
                }
                let nonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
                let expectedFrameBytes = UInt64(MemoryLayout<Float>.size)
                    * UInt64(nonInterleaved ? 1 : format.mChannelsPerFrame)
                guard format.mFormatID == kAudioFormatLinearPCM,
                      format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                      format.mFormatFlags & kAudioFormatFlagIsPacked != 0,
                      format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
                      format.mBitsPerChannel == 32,
                      UInt64(format.mBytesPerFrame) == expectedFrameBytes,
                      format.mChannelsPerFrame > 0,
                      format.mChannelsPerFrame <= 32,
                      format.mSampleRate.isFinite,
                      (8_000...192_000).contains(format.mSampleRate) else {
                    unavailable = "暂不支持此输出格式（需 32-bit Float PCM，8–192 kHz）"
                    continue
                }
                if rate != 0, abs(rate - format.mSampleRate) >= 1 {
                    unavailable = "输出流采样率不一致"
                }
                rate = format.mSampleRate
                channels += format.mChannelsPerFrame
            }
            if channels == 0 || channels > 32 {
                unavailable = unavailable ?? "暂不支持此输出声道配置"
            }
            routes.append((deviceID, AudioOutputRoute(
                uid: uid, name: name, sampleRate: rate,
                channelCount: channels, unavailableReason: unavailable
            )))
        }
        return routes.sorted {
            $0.route.name.localizedCaseInsensitiveCompare($1.route.name) == .orderedAscending
        }
    }

    // MARK: - Diagnostics

    private func startDiagnosticsTimer() {
        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.stateLock.lock()
            let active = self.mixActive
            let macBuffers = self.scheduledMacBuffers
            let remoteBuffers = self.scheduledRemoteBuffers
            let peak = self.scheduledPeak
            let renders = self.renderCallbackCount
            let macQueued = self.pendingMac.count - self.pendingMacIndex
            let remoteQueued = self.pendingRemote.count - self.pendingRemoteIndex
            self.scheduledMacBuffers = 0
            self.scheduledRemoteBuffers = 0
            self.scheduledPeak = 0
            self.renderCallbackCount = 0
            self.stateLock.unlock()
            print(String(
                format:
                    "[AUDIO-METER] mix=%@ macBuffers=%d remoteBuffers=%d " +
                    "macQueued=%d remoteQueued=%d peak=%.4f renders=%d",
                active ? "on" : "off",
                macBuffers,
                remoteBuffers,
                macQueued,
                remoteQueued,
                peak,
                renders
            ))
        }
    }
}
