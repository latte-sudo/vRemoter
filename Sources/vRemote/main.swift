// vRemote for macOS.
//
// 1. Supported remote voice key → matching Option toggle semantics
// 2. Remote ATVV + Mac microphone → aligned mix → vRemoteDr 2ch → Doubao
// 3. A physical Mac Option key controls the same remote microphone session
//
// macOS-only. Requires:
//   * X6-Remote or Chromecast Remote paired in System Settings → Bluetooth
//   * Accessibility permission (System Settings → Privacy & Security →
//     Accessibility) for Option observation and Search suppression
//   * vRemoteDriver.driver installed and visible as vRemoteDr 2ch in
//     System Settings → Sound → Input/Output
//   * Doubao IME configured for Option-as-voice-mode trigger
//
// Run:   swift run
// Quit:  menu bar icon → 退出, or Ctrl+C

import AppKit
import CoreGraphics
import Darwin
import Foundation

// MARK: - Menu bar UI

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var headerLabel: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var loggingToggleItem: NSMenuItem!
    private var logSizeItem: NSMenuItem!
    private var recordingToggleItem: NSMenuItem!
    private var recordingSizeItem: NSMenuItem!
    private var languageItems: [AppLanguage: NSMenuItem] = [:]

    private var x6HIDConnected = false
    private var x6BLEConnected = false
    private var x6RemoteStreaming = false
    private var chromecastHIDConnected = false
    private var chromecastBLEConnected = false
    private var chromecastRemoteStreaming = false
    private var remoteStreaming = false
    private var voiceStatus = ""

    private var lastVoiceRemote: VoiceRemoteID?

    private lazy var x6 = X6HIDBridge()
    private let chromecastHID = ChromecastRemoteHIDBridge()
    private let x6SearchSuppressor = X6SearchSuppressor()
    private let doubaoAudioState = DoubaoAudioStateMonitor()
    private lazy var x6Session = X6SessionCoordinator(
        doubaoState: doubaoAudioState
    )
    private lazy var chromecastSession = ChromecastVoiceSessionController(doubaoState: doubaoAudioState)
    private var sleepObserver: NSObjectProtocol?
    private let debugWindow = DebugWindowController()
    private lazy var x6BLE = BLEBridge(
        nameHint: "X6-Remote",
        savedUUIDFilename: "x6-uuid.txt",
        recordingPrefix: "x6-voice",
        logTag: "X6-BLE",
        resetSessionOnConnect: true
    )
    private let chromecastBLE = BLEBridge(
        nameHint: "Chromecast Remote",
        savedUUIDFilename: "chromecast-remote-uuid.txt",
        recordingPrefix: "chromecast-remote-voice",
        logTag: "CAST-BLE",
        resetSessionOnConnect: true,
        tracksPhysicalVoiceEdges: true
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppStorage.prepare()
        AppAppearanceController.apply(AppAppearance.selected())
        DockVisibilityController.apply(DockVisibilityPreference.isVisible())
        // This release intentionally supports only remote audio, including upgrades.
        AppStorage.macInputEnabled = false
        AppStorage.remoteInputEnabled = true
        // Keep one continuous diagnostic history while X6 is being tuned.
        // Log.swift rotates at 5 MB; only the explicit menu action clears it.
        Log.setEnabled(AppStorage.loggingEnabled)
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        print("[APP] ===== vRemoter \(appVersion) started =====")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let statusImage = LogoAsset.image.copy() as? NSImage
        statusImage?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = statusImage
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        NSApp.applicationIconImage = LogoAsset.image

        let menu = NSMenu()
        menu.delegate = self
        let header = NSMenuItem(
            title: L10n.text("状态 · 启动中", "Status · Starting"),
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        headerLabel = header

        let launch = NSMenuItem(
            title: L10n.text("登录时自动启动", "Launch at login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launch.target = self
        menu.addItem(launch)
        launchAtLoginItem = launch

        menu.addItem(.separator())
        menu.addItem(makeControlMenu())
        menu.addItem(makeLogMenu())
        menu.addItem(makeRecordingMenu())
        menu.addItem(makeLanguageMenu())

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: L10n.text("退出", "Quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        refreshMenuState()
        wireDebugWindow()

        chromecastHID.onConnectionChanged = { [weak self] connected in
            self?.chromecastHIDConnected = connected
            self?.updateStatus()
        }
        chromecastBLE.onConnectionChanged = { [weak self] connected in
            self?.chromecastBLEConnected = connected
            if !connected {
                self?.chromecastRemoteStreaming = false
                self?.chromecastSession.disconnected()
            }
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        chromecastBLE.onStreamingChanged = { [weak self] streaming, _ in
            self?.chromecastRemoteStreaming = streaming
            self?.refreshCombinedStreaming()
            self?.updateStatus()
        }
        chromecastBLE.onAudioStarted = { [weak self] reason, _ in
            guard AudioPipe.shared.isOutputDeviceAvailable else {
                self?.chromecastSession.outputRouteUnavailable()
                return
            }
            if reason == 0x03 { self?.debugWindow.observedButton("voice") }
            self?.lastVoiceRemote = .chromecast
            self?.chromecastSession.remoteAudioStarted(reason: reason)
        }
        chromecastBLE.onAudioStopped = { [weak self] reason in
            self?.chromecastSession.remoteAudioStopped(reason: reason)
        }
        chromecastBLE.onMicrophoneOpenFailed = { [weak self] code in
            self?.chromecastSession.remoteMicrophoneOpenFailed(code: code)
        }
        chromecastBLE.onPCMReceived = { [weak self] in
            self?.chromecastSession.remotePCMReceived()
            self?.debugWindow.receivedAudioPacket()
        }
        chromecastBLE.onLevel = { [weak self] db, _ in
            guard AudioPipe.shared.isRemoteInputEnabled else { return }
            self?.debugWindow.updateRemoteLevel(db)
        }
        chromecastSession.onMicrophoneOpenRequested = { [weak self] bypass in
            guard let self, self.chromecastBLEConnected else { return .unavailable }
            return self.chromecastBLE.openMicrophone(bypassDebounce: bypass)
        }
        chromecastSession.onMicrophoneCloseRequested = { [weak self] in
            self?.chromecastBLE.closeMicrophone(force: true)
        }
        chromecastSession.onStateChanged = { [weak self] status in
            guard let self else { return }
            self.voiceStatus = status
            self.updateStatus()
        }
        chromecastSession.onPresentationChanged = { [weak self] presentation in
            guard let self else { return }
            self.debugWindow.voiceStateChanged(presentation, active: self.chromecastSession.isActive)
        }
        chromecastSession.onSessionEnded = { [weak self] in self?.debugWindow.voiceSessionEnded() }
        chromecastHID.onButtonObserved = { [weak self] id in self?.debugWindow.observedButton(id) }
        x6SearchSuppressor.onTriggerDownObserved = { [weak self] synthetic in
            guard let self, self.chromecastBLEConnected, AudioPipe.shared.isOutputDeviceAvailable else { return }
            self.chromecastSession.triggerDownObserved(isSynthetic: synthetic)
        }
        x6SearchSuppressor.onTriggerUpObserved = { [weak self] synthetic in
            self?.chromecastSession.triggerUpObserved(isSynthetic: synthetic)
        }
        chromecastSession.start()
        x6SearchSuppressor.start()
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stopMicrophoneNow() }
        chromecastHID.start()
        chromecastBLE.start()

        // Discover the selected route eagerly without starting an audio IOProc.
        // Each session acquires output before sending its target shortcut.
        _ = AudioPipe.shared
        AudioPipe.shared.onMacLevel = { [weak self] db in
            self?.debugWindow.updateMacLevel(db)
        }
        AudioPipe.shared.onResourcesInvalidated = { [weak self] in
            self?.chromecastSession.outputRouteUnavailable()
        }
        AudioPipe.shared.onRouteChanged = { [weak self] _ in
            self?.updateStatus()
        }
        // Show the persisted remote label even when no connection event arrives.
        updateStatus()

        DispatchQueue.main.async { [weak self] in
            self?.debugWindow.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        debugWindow.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    private func makeLogMenu() -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("日志", "Logs"), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.text("日志", "Logs"))

        let toggle = NSMenuItem(
            title: L10n.text("记录日志", "Record logs"),
            action: #selector(toggleLogging),
            keyEquivalent: ""
        )
        toggle.target = self
        submenu.addItem(toggle)
        loggingToggleItem = toggle

        let size = NSMenuItem(title: L10n.text("占用 · 0 字节", "Size · 0 bytes"), action: nil, keyEquivalent: "")
        size.isEnabled = false
        submenu.addItem(size)
        logSizeItem = size

        let refresh = NSMenuItem(
            title: L10n.text("刷新占用大小", "Refresh size"),
            action: #selector(refreshStorageSizes),
            keyEquivalent: ""
        )
        refresh.target = self
        submenu.addItem(refresh)

        let open = NSMenuItem(
            title: L10n.text("打开日志文件夹", "Open logs folder"),
            action: #selector(openLogFolder),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let clear = NSMenuItem(
            title: L10n.text("清空日志", "Clear logs"),
            action: #selector(clearLog),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        root.submenu = submenu
        return root
    }

    private func makeControlMenu() -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("控制台", "Console"), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.text("控制台", "Console"))

        let open = NSMenuItem(
            title: L10n.text("打开前台控制台", "Open console"),
            action: #selector(openDebugWindow),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let stop = NSMenuItem(
            title: L10n.text("关闭麦克风", "Stop microphone"),
            action: #selector(stopMicrophone),
            keyEquivalent: ""
        )
        stop.target = self
        submenu.addItem(stop)

        let restart = NSMenuItem(
            title: L10n.text("重启 App", "Restart app"),
            action: #selector(restartApp),
            keyEquivalent: ""
        )
        restart.target = self
        submenu.addItem(restart)

        root.submenu = submenu
        return root
    }

    private func makeRecordingMenu() -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("调试录音", "Debug recordings"), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.text("调试录音", "Debug recordings"))

        let toggle = NSMenuItem(
            title: L10n.text("保存 WAV 与原始数据", "Save WAV and raw data"),
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        toggle.target = self
        submenu.addItem(toggle)
        recordingToggleItem = toggle

        let size = NSMenuItem(title: L10n.text("占用 · 0 字节", "Size · 0 bytes"), action: nil, keyEquivalent: "")
        size.isEnabled = false
        submenu.addItem(size)
        recordingSizeItem = size

        let refresh = NSMenuItem(
            title: L10n.text("刷新占用大小", "Refresh size"),
            action: #selector(refreshStorageSizes),
            keyEquivalent: ""
        )
        refresh.target = self
        submenu.addItem(refresh)

        let open = NSMenuItem(
            title: L10n.text("打开录音文件夹", "Open recordings folder"),
            action: #selector(openRecordingFolder),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let clear = NSMenuItem(
            title: L10n.text("清空录音文件", "Clear recordings"),
            action: #selector(clearRecordings),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        root.submenu = submenu
        return root
    }

    private func makeLanguageMenu() -> NSMenuItem {
        let root = NSMenuItem(
            title: L10n.text("语言", "Language"),
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: L10n.text("语言", "Language"))
        let options: [(AppLanguage, String, Selector)] = [
            (.system, L10n.text("跟随系统", "System Default"), #selector(selectSystemLanguage)),
            (.simplifiedChinese, "简体中文", #selector(selectSimplifiedChinese)),
            (.english, "English", #selector(selectEnglish))
        ]
        for (language, title, selector) in options {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            item.state = AppLanguage.selected == language ? .on : .off
            submenu.addItem(item)
            languageItems[language] = item
        }
        root.submenu = submenu
        return root
    }

    private func updateStatus() {
        let remoteName = RemoteDisplayName.displayName()
        let anyHID = x6HIDConnected || chromecastHIDConnected
        let anyBLE = x6BLEConnected || chromecastBLEConnected
        let doubaoSnapshot = doubaoAudioState.snapshotNow()
        let statusText: String
        if !anyHID && !anyBLE {
            statusText = L10n.text("等待遥控器连接", "Waiting for remote connection")
        } else if !anyHID || !anyBLE {
            statusText = L10n.text("正在连接语音 / 按键通道", "Connecting voice / buttons")
        } else if !voiceStatus.isEmpty {
            statusText = voiceStatus
        } else {
            statusText = L10n.text("已就绪", "Ready")
        }
        statusItem.button?.toolTip = "vRemoter · \(remoteName) · \(statusText)"
        headerLabel.title = "\(remoteName) · \(statusText)"
        debugWindow.update(
            status: statusText,
            hidConnected: anyHID,
            bleConnected: anyBLE,
            remoteStreaming: remoteStreaming,
            macInputEnabled: AudioPipe.shared.isMacInputEnabled,
            remoteInputEnabled: AudioPipe.shared.isRemoteInputEnabled,
            doubaoIsRecording: doubaoSnapshot.isRecording,
            doubaoInput: doubaoSnapshot.deviceSummary,
            driverAvailable: AudioPipe.shared.isOutputDeviceAvailable,
            x6Connected: x6HIDConnected || x6BLEConnected,
            chromecastConnected: chromecastHIDConnected || chromecastBLEConnected,
            macLevelDB: nil,
            remoteLevelDB: nil
        )
    }

    private func wireDebugWindow() {
        debugWindow.onRemoteDisplayNameChanged = { [weak self] in self?.updateStatus() }
        debugWindow.onStopMicrophone = { [weak self] in
            self?.stopMicrophoneNow()
        }
        debugWindow.onRestartApp = { [weak self] in
            self?.restartAppNow()
        }
        debugWindow.onMacInputEnabledChanged = { [weak self] enabled in
            self?.chromecastSession.configurationChanged()
            let audio = AudioPipe.shared
            audio.setInputEnabled(
                mac: enabled,
                remote: audio.isRemoteInputEnabled
            )
            self?.updateStatus()
        }
        debugWindow.onRemoteInputEnabledChanged = { [weak self] enabled in
            self?.chromecastSession.configurationChanged()
            let audio = AudioPipe.shared
            audio.setInputEnabled(
                mac: audio.isMacInputEnabled,
                remote: enabled
            )
            if !enabled {
                self?.chromecastBLE.closeMicrophone(force: true)
                self?.debugWindow.updateRemoteLevel(-120)
            }
            self?.updateStatus()
        }
        debugWindow.onReconnectInputs = { [weak self] in
            guard let self, !self.chromecastSession.isActive else { return }
            self.chromecastHID.start()
            self.x6SearchSuppressor.stop()
            self.x6SearchSuppressor.start()
            self.chromecastBLE.start()
        }
        debugWindow.onVoiceConfigurationChanged = { [weak self] in
            self?.chromecastSession.configurationChanged()
            self?.x6SearchSuppressor.triggerConfigurationDidChange()
        }
        debugWindow.onInputTriggerChanged = { [weak self] in
            self?.x6SearchSuppressor.triggerConfigurationDidChange()
        }
        debugWindow.onRemoteMappingEnabledChanged = { [weak self] remote, enabled in
            switch remote {
            case .x6:
                self?.x6.setRemappingEnabled(enabled)
            case .chromecast:
                self?.chromecastHID.setRemappingEnabled(enabled)
            }
        }
    }

    @objc private func openDebugWindow() {
        debugWindow.show()
    }

    @objc private func selectSystemLanguage() {
        setLanguageAndRestart(.system)
    }

    @objc private func selectSimplifiedChinese() {
        setLanguageAndRestart(.simplifiedChinese)
    }

    @objc private func selectEnglish() {
        setLanguageAndRestart(.english)
    }

    private func setLanguageAndRestart(_ language: AppLanguage) {
        guard AppLanguage.selected != language else { return }
        AppLanguage.selected = language
        restartAppNow()
    }

    @objc private func stopMicrophone() {
        stopMicrophoneNow()
    }

    private func stopMicrophoneNow() {
        chromecastSession.forceClose()
        chromecastBLE.closeMicrophone(force: true)
        AudioPipe.shared.setRemoteActive(false)
        updateStatus()
    }

    @objc private func restartApp() {
        restartAppNow()
    }

    private func restartAppNow() {
        stopMicrophoneNow()
        let bundleURL = Bundle.main.bundleURL
        // `NSWorkspace.openApplication` may reuse the current instance for an
        // accessory app. Use `/usr/bin/open -n` so macOS creates a genuinely
        // new process before this one exits.
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launcher.arguments = ["-n", bundleURL.path]
        do {
            try launcher.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NSApp.terminate(nil)
            }
        } catch {
            print("[APP] 重启失败: \(error.localizedDescription)")
        }
    }

    private func refreshCombinedStreaming() {
        remoteStreaming = x6RemoteStreaming || chromecastRemoteStreaming
    }

    private func preferredVoiceRemote() -> VoiceRemoteID? {
        if let lastVoiceRemote {
            switch lastVoiceRemote {
            case .x6 where x6BLEConnected:
                return .x6
            case .chromecast where chromecastBLEConnected:
                return .chromecast
            default:
                break
            }
        }
        if x6BLEConnected { return .x6 }
        if chromecastBLEConnected { return .chromecast }
        return nil
    }

    private func openRemoteMicrophone(
        _ remote: VoiceRemoteID,
        bypassDebounce: Bool
    ) -> RemoteMicrophoneOpenResult {
        switch remote {
        case .x6:
            guard x6BLEConnected else { return .unavailable }
            return x6BLE.openMicrophone(bypassDebounce: bypassDebounce)
        case .chromecast:
            guard chromecastBLEConnected else { return .unavailable }
            return chromecastBLE.openMicrophone(
                bypassDebounce: bypassDebounce
            )
        }
    }

    private func openPreferredRemoteMicrophone() {
        guard let remote = preferredVoiceRemote() else { return }
        _ = openRemoteMicrophone(remote, bypassDebounce: false)
    }

    private func closeAllRemoteMicrophones() {
        chromecastBLE.closeMicrophone(force: true)
    }

    private func refreshMenuState() {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
        loggingToggleItem?.state = Log.isEnabled ? .on : .off
        recordingToggleItem?.state = AppStorage.recordingEnabled ? .on : .off
        refreshSizeLabels()
    }

    private func refreshSizeLabels() {
        logSizeItem?.title = L10n.text("占用", "Size")
            + " · \(AppStorage.formattedSize(Log.byteSize))"
        let recordingBytes = AppStorage.byteSize(
            of: AppStorage.recordingsDirectory
        )
        recordingSizeItem?.title = L10n.text("占用", "Size")
            + " · \(AppStorage.formattedSize(recordingBytes))"
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            headerLabel.title = L10n.text(
                "状态 · 登录启动设置失败",
                "Status · Launch-at-login failed"
            )
        }
        refreshMenuState()
    }

    @objc private func toggleLogging() {
        Log.setEnabled(!Log.isEnabled)
        if Log.isEnabled {
            print("[APP] 日志已由用户开启")
        }
        refreshMenuState()
    }

    @objc private func toggleRecording() {
        let enabled = !AppStorage.recordingEnabled
        AppStorage.recordingEnabled = enabled
        x6BLE.setRecordingEnabled(enabled)
        chromecastBLE.setRecordingEnabled(enabled)
        refreshMenuState()
    }

    @objc private func refreshStorageSizes() {
        refreshSizeLabels()
    }

    @objc private func openLogFolder() {
        AppStorage.ensureDirectory(AppStorage.logsDirectory)
        NSWorkspace.shared.open(AppStorage.logsDirectory)
    }

    @objc private func openRecordingFolder() {
        AppStorage.ensureDirectory(AppStorage.recordingsDirectory)
        NSWorkspace.shared.open(AppStorage.recordingsDirectory)
    }

    @objc private func clearLog() {
        Log.clear()
        refreshSizeLabels()
    }

    @objc private func clearRecordings() {
        x6BLE.clearRecordings()
        refreshSizeLabels()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        chromecastHID.stop()
        x6SearchSuppressor.stop()
        chromecastSession.stop()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        chromecastBLE.stop()
        AudioPipe.shared.stop()
    }
}

// MARK: - Entry

#if DEBUG
if CommandLine.arguments.contains("--voice-session-self-test") {
    exit(VoiceSessionSelfTest.run() ? EXIT_SUCCESS : EXIT_FAILURE)
}
#endif

let app = NSApplication.shared
let delegate = AppController()
app.delegate = delegate

// Convert SIGTERM (including `kill`/`pkill`) into a normal AppKit
// termination so Option and the CoreAudio IOProc are always released.
signal(SIGTERM, SIG_IGN)
let terminationSignal = DispatchSource.makeSignalSource(
    signal: SIGTERM,
    queue: .main
)
terminationSignal.setEventHandler {
    NSApp.terminate(nil)
}
terminationSignal.resume()

app.run()
