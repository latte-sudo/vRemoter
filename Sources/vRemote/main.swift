// vRemote for macOS 12+ — Chromecast-focused runtime.
//
// Remote ATVV audio -> selected virtual route -> user-selected speech tool.
// Physical remote and target shortcut modes are configured independently.
// Mac microphone capture is disabled for this product, including upgrades.
// Keyboard trigger observation and voice contracts are shared, neutral helpers.
// See docs/NATIVE_INTERFACE_IMPLEMENTATION.md.
//
// Run: swift run. Quit: menu bar icon -> Quit, or Ctrl+C.

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

    private var chromecastHIDConnected = false
    private var chromecastBLEConnected = false
    private var chromecastRemoteStreaming = false
    private var menuStatusSummary = L10n.tr("shell.window.title")
    private var voiceReception = MenuBarVoiceReception()
    private var voiceReceptionTimer: Timer?
    private var renderedVoiceReception: Bool?

    private let chromecastHID = ChromecastRemoteHIDBridge()
    private let keyboardTriggerObserver = KeyboardTriggerObserver()
    private let doubaoAudioState = DoubaoAudioStateMonitor()
    private lazy var chromecastSession = ChromecastVoiceSessionController(doubaoState: doubaoAudioState)
    private var sleepObserver: NSObjectProtocol?
    private let debugWindow = DebugWindowController()
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
        // SwiftUI may have initialized the shared pipe before didFinishLaunching.
        // Update its cached flags too, before any HID/BLE/session can start.
        AudioPipe.shared.setInputEnabled(mac: false, remote: true)
        // Keep one diagnostic history for transport troubleshooting.
        // Log.swift rotates at 5 MB; only the explicit menu action clears it.
        Log.setEnabled(AppStorage.loggingEnabled)
        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        print("[APP] ===== \(L10n.tr("shell.window.title")) \(appVersion) started =====")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarStatusIcon.image(receivingVoice: false)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        NSApp.applicationIconImage = LogoAsset.image

        let menu = NSMenu()
        menu.delegate = self
        let header = localizedMenuItem("shell.status.starting",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        headerLabel = header

        let launch = localizedMenuItem("shell.menu.launch_at_login",
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
        let quit = localizedMenuItem("shell.menu.quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        refreshMenuState()
        wireDebugWindow()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )

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
            self?.updateStatus()
        }
        chromecastBLE.onStreamingChanged = { [weak self] streaming, _ in
            self?.chromecastRemoteStreaming = streaming
            self?.updateStatus()
        }
        chromecastBLE.onAudioStarted = { [weak self] reason, _ in
            guard AudioPipe.shared.isOutputDeviceAvailable else {
                self?.chromecastSession.outputRouteUnavailable()
                return
            }
            if reason == 0x03 { self?.debugWindow.observedButton("voice") }
            self?.chromecastSession.remoteAudioStarted(reason: reason)
        }
        chromecastBLE.onAudioStopped = { [weak self] reason in
            self?.chromecastSession.remoteAudioStopped(reason: reason)
        }
        chromecastBLE.onMicrophoneOpenFailed = { [weak self] code in
            self?.chromecastSession.remoteMicrophoneOpenFailed(code: code)
        }
        chromecastBLE.onPCMReceived = { [weak self] in
            guard let self else { return }
            self.chromecastSession.remotePCMReceived()
            self.debugWindow.receivedAudioPacket()
            self.voiceReception.update(phase: self.chromecastSession.presentation.phase,
                                       streaming: self.chromecastRemoteStreaming)
            self.voiceReception.receivedPacket(at: ProcessInfo.processInfo.systemUptime)
            self.updateMenuVoiceIndicator()
            if self.voiceReception.isReceiving(at: ProcessInfo.processInfo.systemUptime), self.voiceReceptionTimer == nil {
                let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                    self?.updateMenuVoiceIndicator()
                }
                self.voiceReceptionTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
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
        chromecastSession.onStateChanged = { [weak self] _ in self?.updateStatus() }
        chromecastSession.onPresentationChanged = { [weak self] presentation in
            guard let self else { return }
            self.debugWindow.voiceStateChanged(presentation, active: self.chromecastSession.isActive)
            self.updateMenuVoiceIndicator()
        }
        chromecastSession.onSessionEnded = { [weak self] in self?.debugWindow.voiceSessionEnded() }
        chromecastHID.onButtonObserved = { [weak self] id in self?.debugWindow.observedButton(id) }
        keyboardTriggerObserver.onTriggerDownObserved = { [weak self] synthetic in
            guard let self, self.chromecastBLEConnected, AudioPipe.shared.isOutputDeviceAvailable else { return }
            self.chromecastSession.triggerDownObserved(isSynthetic: synthetic)
        }
        keyboardTriggerObserver.onTriggerUpObserved = { [weak self] synthetic in
            self?.chromecastSession.triggerUpObserved(isSynthetic: synthetic)
        }
        chromecastSession.start()
        keyboardTriggerObserver.start()
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
        let root = localizedMenuItem("shell.menu.logs", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.tr("shell.menu.logs"))

        let toggle = localizedMenuItem("shell.menu.record_logs",
            action: #selector(toggleLogging),
            keyEquivalent: ""
        )
        toggle.target = self
        submenu.addItem(toggle)
        loggingToggleItem = toggle

        let size = localizedMenuItem("shell.storage.empty", action: nil, keyEquivalent: "")
        size.isEnabled = false
        submenu.addItem(size)
        logSizeItem = size

        let refresh = localizedMenuItem("shell.storage.refresh",
            action: #selector(refreshStorageSizes),
            keyEquivalent: ""
        )
        refresh.target = self
        submenu.addItem(refresh)

        let open = localizedMenuItem("shell.menu.open_logs",
            action: #selector(openLogFolder),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let clear = localizedMenuItem("shell.menu.clear_logs",
            action: #selector(clearLog),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        root.submenu = submenu
        return root
    }

    private func makeControlMenu() -> NSMenuItem {
        let root = localizedMenuItem("shell.menu.controls", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.tr("shell.menu.controls"))

        let open = localizedMenuItem("shell.menu.open_controls",
            action: #selector(openDebugWindow),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let stop = localizedMenuItem("shell.menu.stop_voice",
            action: #selector(stopMicrophone),
            keyEquivalent: ""
        )
        stop.target = self
        submenu.addItem(stop)

        let restart = localizedMenuItem("shell.menu.restart",
            action: #selector(restartApp),
            keyEquivalent: ""
        )
        restart.target = self
        submenu.addItem(restart)

        root.submenu = submenu
        return root
    }

    private func makeRecordingMenu() -> NSMenuItem {
        let root = localizedMenuItem("shell.menu.recordings", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: L10n.tr("shell.menu.recordings"))

        let toggle = localizedMenuItem("shell.menu.save_recordings",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        toggle.target = self
        submenu.addItem(toggle)
        recordingToggleItem = toggle

        let size = localizedMenuItem("shell.storage.empty", action: nil, keyEquivalent: "")
        size.isEnabled = false
        submenu.addItem(size)
        recordingSizeItem = size

        let refresh = localizedMenuItem("shell.storage.refresh",
            action: #selector(refreshStorageSizes),
            keyEquivalent: ""
        )
        refresh.target = self
        submenu.addItem(refresh)

        let open = localizedMenuItem("shell.menu.open_recordings",
            action: #selector(openRecordingFolder),
            keyEquivalent: ""
        )
        open.target = self
        submenu.addItem(open)

        let clear = localizedMenuItem("shell.menu.clear_recordings",
            action: #selector(clearRecordings),
            keyEquivalent: ""
        )
        clear.target = self
        submenu.addItem(clear)

        root.submenu = submenu
        return root
    }

    private func makeLanguageMenu() -> NSMenuItem {
        let root = localizedMenuItem("shell.menu.language",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: L10n.tr("shell.menu.language"))
        let options: [(AppLanguage, Selector)] = [
            (.system, #selector(selectSystemLanguage)),
            (.simplifiedChinese, #selector(selectSimplifiedChinese)),
            (.traditionalChinese, #selector(selectTraditionalChinese)),
            (.english, #selector(selectEnglish))
        ]
        for (language, selector) in options {
            let item = NSMenuItem(title: language.title, action: selector, keyEquivalent: "")
            item.representedObject = language
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
        let doubaoSnapshot = doubaoAudioState.snapshotNow()
        let statusText: String
        if !chromecastHIDConnected && !chromecastBLEConnected {
            statusText = L10n.tr("shell.status.waiting")
        } else if !chromecastHIDConnected || !chromecastBLEConnected {
            statusText = L10n.tr("shell.status.connecting")
        } else if !chromecastSession.presentation.detail.isEmpty {
            // Resolve the current presentation when drawing, so changing the
            // language does not need to restart or interrupt a voice session.
            statusText = chromecastSession.presentation.detail
        } else {
            statusText = L10n.tr("shell.status.ready")
        }
        menuStatusSummary = "\(L10n.tr("shell.window.title")) · \(remoteName) · \(statusText)"
        updateMenuVoiceIndicator()
        headerLabel.title = "\(remoteName) · \(statusText)"
        debugWindow.update(
            status: statusText,
            hidConnected: chromecastHIDConnected,
            bleConnected: chromecastBLEConnected,
            remoteStreaming: chromecastRemoteStreaming,
            macInputEnabled: AudioPipe.shared.isMacInputEnabled,
            remoteInputEnabled: AudioPipe.shared.isRemoteInputEnabled,
            doubaoIsRecording: doubaoSnapshot.isRecording,
            doubaoInput: doubaoSnapshot.deviceSummary,
            driverAvailable: AudioPipe.shared.isOutputDeviceAvailable,
            chromecastConnected: chromecastHIDConnected || chromecastBLEConnected,
            macLevelDB: nil,
            remoteLevelDB: nil
        )
    }

    private func updateMenuVoiceIndicator() {
        voiceReception.update(phase: chromecastSession.presentation.phase,
                              streaming: chromecastRemoteStreaming)
        let receiving = voiceReception.isReceiving(at: ProcessInfo.processInfo.systemUptime)
        if renderedVoiceReception != receiving {
            renderedVoiceReception = receiving
            statusItem.button?.image = MenuBarStatusIcon.image(receivingVoice: receiving)
        }
        let receipt = receiving ? L10n.tr("shell.status.receiving") : ""
        let label = menuStatusSummary + receipt
        statusItem.button?.toolTip = label
        statusItem.button?.setAccessibilityLabel(label)
        if !receiving {
            voiceReceptionTimer?.invalidate()
            voiceReceptionTimer = nil
        }
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
            self.keyboardTriggerObserver.start()
            self.chromecastBLE.start()
        }
        debugWindow.onVoiceConfigurationChanged = { [weak self] in
            self?.chromecastSession.configurationChanged()
            self?.keyboardTriggerObserver.triggerConfigurationDidChange()
        }
        debugWindow.onInputTriggerChanged = { [weak self] in
            self?.keyboardTriggerObserver.triggerConfigurationDidChange()
        }
        debugWindow.onRemoteMappingEnabledChanged = { [weak self] remote, enabled in
            switch remote {
            case .chromecast:
                self?.chromecastHID.setRemappingEnabled(enabled)
            }
        }
    }

    @objc private func openDebugWindow() {
        debugWindow.show()
    }

    @objc private func selectSystemLanguage() {
        AppLanguage.selected = .system
    }

    @objc private func selectSimplifiedChinese() {
        AppLanguage.selected = .simplifiedChinese
    }

    @objc private func selectTraditionalChinese() {
        AppLanguage.selected = .traditionalChinese
    }

    @objc private func selectEnglish() {
        AppLanguage.selected = .english
    }

    @objc private func languageDidChange() {
        if let menu = statusItem?.menu { refreshLocalizedMenu(menu) }
        refreshMenuState()
        updateStatus()
    }

    private func localizedMenuItem(
        _ key: String,
        action: Selector?,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr(key), action: action, keyEquivalent: keyEquivalent)
        item.representedObject = key
        return item
    }

    private func refreshLocalizedMenu(_ menu: NSMenu) {
        // Update the existing menu in place, including an open submenu.
        for item in menu.items {
            if let key = item.representedObject as? String {
                item.title = L10n.tr(key)
            } else if let language = item.representedObject as? AppLanguage {
                item.title = language.title
            }
            if let submenu = item.submenu {
                submenu.title = item.title
                refreshLocalizedMenu(submenu)
            }
        }
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

    private func refreshMenuState() {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
        loggingToggleItem?.state = Log.isEnabled ? .on : .off
        recordingToggleItem?.state = AppStorage.recordingEnabled ? .on : .off
        for (language, item) in languageItems {
            item.state = AppLanguage.selected == language ? .on : .off
        }
        refreshSizeLabels()
    }

    private func refreshSizeLabels() {
        logSizeItem?.title = L10n.tr("shell.storage.used")
            + " · \(AppStorage.formattedSize(Log.byteSize))"
        let recordingBytes = AppStorage.byteSize(
            of: AppStorage.recordingsDirectory
        )
        recordingSizeItem?.title = L10n.tr("shell.storage.used")
            + " · \(AppStorage.formattedSize(recordingBytes))"
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            headerLabel.title = L10n.tr("shell.status.login_failed")
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
        chromecastBLE.clearRecordings()
        refreshSizeLabels()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugWindow.stopPermissionGuidance()
        NotificationCenter.default.removeObserver(self, name: .appLanguageDidChange, object: nil)
        voiceReceptionTimer?.invalidate()
        voiceReceptionTimer = nil
        chromecastHID.stop()
        keyboardTriggerObserver.stop()
        chromecastSession.stop()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        chromecastBLE.stop()
        AudioPipe.shared.stop()
    }
}

// MARK: - Entry

// A read-only packaging probe. Do not initialize AppKit, preferences, Bluetooth,
// audio, login items or permission requesters during this check.
if CommandLine.arguments.contains("--localization-self-test") {
    let failures = L10n.validateBundledResources()
    for failure in failures { FileHandle.standardError.write(Data((failure + "\n").utf8)) }
    if !failures.isEmpty { exit(1) }
    for language in L10n.supportedLanguages {
        Swift.print("\(language.rawValue): \(L10n.text("language.title", language: language))")
    }
    Swift.print("PASS: running executable loaded all three bundled language tables")
    exit(0)
}

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
