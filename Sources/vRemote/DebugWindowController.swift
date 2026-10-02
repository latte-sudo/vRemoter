import AppKit
import ApplicationServices
import AVFoundation
import CoreBluetooth
import CoreGraphics
import SwiftUI

enum PermissionKind: String, Identifiable, CaseIterable {
    case doubaoInput
    case microphone
    case accessibility
    case inputMonitoring
    case bluetooth

    var id: String { rawValue }

    var requestablePermission: RequestablePermission? {
        switch self {
        case .bluetooth: .bluetooth
        case .accessibility: .accessibility
        case .inputMonitoring: .inputMonitoring
        case .doubaoInput, .microphone: nil
        }
    }

    var title: String {
        switch self {
        case .doubaoInput: L10n.tr("permission.title.doubao")
        case .microphone: L10n.tr("permission.title.microphone")
        case .accessibility: L10n.tr("permission.title.accessibility")
        case .inputMonitoring: L10n.tr("permission.title.input_monitoring")
        case .bluetooth: L10n.tr("permission.title.bluetooth")
        }
    }

    var settingsURL: URL? {
        let anchor: String
        switch self {
        case .doubaoInput: return nil
        case .microphone: anchor = "Privacy_Microphone"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .bluetooth: anchor = "Privacy_Bluetooth"
        }
        return URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        )
    }

    var screenshotNames: [String] {
        switch self {
        case .doubaoInput:
            [
                "permission-app-management",
                "doubaoinput0",
                "doubaoinput1",
                "doubaoinput2"
            ]
        case .microphone: ["permission-microphone", "permission-microphone"]
        case .accessibility: ["permission-accessibility", "permission-accessibility"]
        case .inputMonitoring: ["permission-input-monitoring", "permission-input-monitoring"]
        case .bluetooth: ["permission-bluetooth", "permission-bluetooth"]
        }
    }

    var guidance: [String] {
        switch self {
        case .doubaoInput:
            return [
                L10n.tr("permission.doubao.app_management"),
                L10n.tr("permission.doubao.open_menu"),
                L10n.tr("permission.doubao.choose_input"),
                L10n.tr("permission.doubao.select_microphone")
            ]
        case .microphone:
            return [
                L10n.tr("permission.microphone.open_settings"),
                L10n.tr("permission.microphone.enable")
            ]
        case .accessibility:
            return [
                L10n.tr("permission.accessibility.open_settings"),
                L10n.tr("permission.accessibility.enable")
            ]
        case .inputMonitoring:
            return [
                L10n.tr("permission.input_monitoring.open_settings"),
                L10n.tr("permission.input_monitoring.enable")
            ]
        case .bluetooth:
            return [
                L10n.tr("permission.bluetooth.open_settings"),
                L10n.tr("permission.bluetooth.enable")
            ]
        }
    }

    var pageCount: Int { screenshotNames.count }

    func screenshotName(for page: Int) -> String {
        screenshotNames[min(max(page, 0), pageCount - 1)]
    }
}

private enum ConsoleTheme {
    // Semantic colors retain contrast in light/dark and accessibility appearances.
    static let panel = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surface2 = Color(nsColor: .quaternaryLabelColor)
    static let line = Color(nsColor: .separatorColor)
    static let lineSoft = Color(nsColor: .separatorColor)
    static let text = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .secondaryLabelColor)
    static let green = Color(nsColor: .systemGreen)
    static let amber = Color(nsColor: .systemOrange)
    static let amberDeep = Color(nsColor: .systemOrange).opacity(0.12)
    static let red = Color(nsColor: .systemRed)
    static let redDeep = Color(nsColor: .systemRed).opacity(0.12)
    static let black = Color(nsColor: .textBackgroundColor)
}

enum LogoAsset {
    static let image: NSImage = {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "vRemoterLogo", withExtension: "png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        // A development checkout or missing packaged PNG must never produce a blank Dock icon.
        let image = NSImage(size: NSSize(width: 128, height: 128))
        image.lockFocus()
        NSColor.systemIndigo.setFill()
        NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 120, height: 120), xRadius: 28, yRadius: 28).fill()
        let text = "vR" as NSString
        text.draw(at: NSPoint(x: 25, y: 36), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 50), .foregroundColor: NSColor.white
        ])
        image.unlockFocus()
        return image
    }()
}

private enum GuideAsset {
    static func image(named name: String) -> NSImage? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent("PermissionGuides", isDirectory: true)
                .appendingPathComponent("\(name).png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/PermissionGuides/\(name).png")
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) { return image }
        }
        return nil
    }
}

enum ConsoleModal: Identifiable {
    case permission(PermissionKind)

    var id: String {
        switch self {
        case .permission(let kind): "permission-\(kind.id)"
        }
    }
}

@MainActor
final class ConsoleViewModel: ObservableObject {
    @Published var status = L10n.tr("shell.status.starting")
    @Published private(set) var remoteDisplayName = RemoteDisplayName.displayName()
    var onRemoteDisplayNameChanged: (() -> Void)?
    @Published var hidConnected = false
    @Published var bleConnected = false
    @Published var remoteStreaming = false
    @Published var macInputEnabled = false
    @Published var voiceActive = false
    @Published var voicePresentation = VoiceSessionPresentation()
    @Published var receivedAudioPackets = 0
    @Published var completedVoiceSessions = 0
    @Published var lastButtonID: String?
    var onVoiceConfigurationChanged: (() -> Void)?
    var onReconnectInputs: (() -> Void)?
    @Published var remoteInputEnabled = true
    @Published var doubaoIsRecording = false
    @Published var doubaoInput = "--"
    @Published var driverAvailable = false
    @Published var macLevelDB = -120.0
    @Published var remoteLevelDB = -120.0
    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var bluetoothGranted = false
    @Published private var bluetoothPermissionStatusKey = "permission.status.pending"
    var bluetoothPermissionStatus: String { L10n.tr(bluetoothPermissionStatusKey) }
    @Published var permissionCheckedAt: Date?
    var accessibilityPermissionStatus: String {
        L10n.tr(accessibilityGranted ? "permission.status.granted" : "permission.status.denied")
    }
    var inputMonitoringPermissionStatus: String {
        L10n.tr(inputMonitoringGranted ? "permission.status.granted" : "permission.status.denied")
    }
    @Published var chromecastConnected = false
    @Published var inputTriggerKey = AppStorage.inputTriggerKey
    @Published var activeModal: ConsoleModal?
    private let permissionRequester = MacPermissionRequester()
    private struct PermissionFeedback {
        let kind: PermissionKind
        let result: PermissionRequestResult?
    }
    @Published private var permissionFeedback: PermissionFeedback?

    /// Preserve the outcome, and translate it when the view renders. Changing
    /// languages must not request permission again or clear useful feedback.
    var permissionRequestMessage: String {
        guard let feedback = permissionFeedback else { return "" }
        guard let result = feedback.result else { return L10n.tr("permission.request.not_needed") }
        let key: String
        switch result {
        case .alreadyGranted: key = "permission.request.granted"
        case .requested: key = "permission.request.sent"
        case .openSettings: key = "permission.request.settings"
        case .restricted: key = "permission.request.restricted"
        case .unavailable: key = "permission.request.unknown"
        }
        return L10n.tr(key, feedback.kind.title)
    }

    var onStopMicrophone: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onMacInputEnabledChanged: ((Bool) -> Void)?
    var onRemoteInputEnabledChanged: ((Bool) -> Void)?
    var onInputTriggerChanged: (() -> Void)?
    var onRemoteMappingEnabledChanged: ((SupportedRemoteID, Bool) -> Void)?

    func refreshRemoteDisplayName() {
        let name = RemoteDisplayName.displayName()
        guard remoteDisplayName != name else { return }
        remoteDisplayName = name
        onRemoteDisplayNameChanged?()
    }

    func setInputTrigger(_ trigger: InputTriggerKey) {
        guard inputTriggerKey != trigger else { return }
        inputTriggerKey = trigger
        AppStorage.inputTriggerKey = trigger
        onInputTriggerChanged?()
    }

    func setRemoteMappingEnabled(_ enabled: Bool, remote: SupportedRemoteID) {
        RemoteMappingStore.shared.setEnabled(enabled, for: remote)
        onRemoteMappingEnabledChanged?(remote, enabled)
    }

    func refreshPermissions() {
        permissionCheckedAt = Date()
        let demoMode = ProcessInfo.processInfo.environment["VREMOTER_PERMISSION_DEMO"] == "1"
            || CommandLine.arguments.contains("--permission-demo")
        if demoMode {
            microphoneGranted = false
            accessibilityGranted = false
            inputMonitoringGranted = false
            bluetoothGranted = false
            bluetoothPermissionStatusKey = "permission.status.demo"
            return
        }
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        if #available(macOS 11.0, *) {
            switch CBManager.authorization {
            case .allowedAlways: bluetoothGranted = true; bluetoothPermissionStatusKey = "permission.status.granted"
            case .denied: bluetoothGranted = false; bluetoothPermissionStatusKey = "permission.status.denied"
            case .notDetermined: bluetoothGranted = false; bluetoothPermissionStatusKey = "permission.status.pending"
            case .restricted: bluetoothGranted = false; bluetoothPermissionStatusKey = "permission.status.restricted"
            @unknown default: bluetoothGranted = false; bluetoothPermissionStatusKey = "permission.status.unknown"
            }
        } else {
            bluetoothGranted = true
            bluetoothPermissionStatusKey = "permission.status.not_required"
        }
    }

    @discardableResult
    func requestPermission(for kind: PermissionKind) -> String {
        guard let permission = kind.requestablePermission else {
            permissionFeedback = PermissionFeedback(kind: kind, result: nil)
            return permissionRequestMessage
        }
        let result = permissionRequester.request(permission)
        permissionFeedback = PermissionFeedback(kind: kind, result: result)
        refreshPermissions()
        return permissionRequestMessage
    }

    func openSettings(for kind: PermissionKind) {
        if kind == .doubaoInput {
            openDoubaoSettings()
            activeModal = nil
            return
        }
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
        activeModal = nil
    }

    private func openDoubaoSettings() {
        let bundleIdentifier = "com.bytedance.inputmethod.doubaoime.settings"
        let candidates = [
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
            URL(
                fileURLWithPath:
                    "/Library/Input Methods/DoubaoIme.app/Contents/DoubaoImeSettings.app"
            )
        ]
        for candidate in candidates.compactMap({ $0 })
            where FileManager.default.fileExists(atPath: candidate.path) {
            if NSWorkspace.shared.open(candidate) { return }
        }
    }
}

final class DebugWindowController: NSWindowController, NSWindowDelegate {
    private static let windowSize = NSSize(width: 1160, height: 820)

    var onStopMicrophone: (() -> Void)?
    var onRemoteDisplayNameChanged: (() -> Void)?
    var onVoiceConfigurationChanged: (() -> Void)?
    var onReconnectInputs: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onMacInputEnabledChanged: ((Bool) -> Void)?
    var onRemoteInputEnabledChanged: ((Bool) -> Void)?
    var onInputTriggerChanged: (() -> Void)?
    var onRemoteMappingEnabledChanged: ((SupportedRemoteID, Bool) -> Void)?

    private let model = ConsoleViewModel()
    private var permissionTimer: Timer?

    init() {
        let windowSize = Self.windowSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("shell.window.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        // Inherit the app's selected appearance, including automatic system changes.
        window.minSize = NSSize(width: 1080, height: 720)
        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )

        model.onReconnectInputs = { [weak self] in self?.onReconnectInputs?() }
        model.onRemoteDisplayNameChanged = { [weak self] in self?.onRemoteDisplayNameChanged?() }
        model.onVoiceConfigurationChanged = { [weak self] in self?.onVoiceConfigurationChanged?() }
        model.onStopMicrophone = { [weak self] in self?.onStopMicrophone?() }
        model.onRestartApp = { [weak self] in self?.onRestartApp?() }
        model.onMacInputEnabledChanged = { [weak self] enabled in
            self?.onMacInputEnabledChanged?(enabled)
        }
        model.onRemoteInputEnabledChanged = { [weak self] enabled in
            self?.onRemoteInputEnabledChanged?(enabled)
        }
        model.onInputTriggerChanged = { [weak self] in
            self?.onInputTriggerChanged?()
        }
        model.onRemoteMappingEnabledChanged = { [weak self] remote, enabled in
            self?.onRemoteMappingEnabledChanged?(remote, enabled)
        }
        window.contentView = NSHostingView(
            rootView: ChromecastConsoleView(model: model)
                .frame(minWidth: 1080, minHeight: 720)
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .appLanguageDidChange, object: nil)
    }

    @objc private func languageDidChange() {
        window?.title = L10n.tr("shell.window.title")
        model.refreshRemoteDisplayName()
        model.objectWillChange.send()
    }

    func show() {
        guard let window else { return }
        model.refreshPermissions()
        startPermissionTimer()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func update(
        status: String,
        hidConnected: Bool,
        bleConnected: Bool,
        remoteStreaming: Bool,
        macInputEnabled: Bool,
        remoteInputEnabled: Bool,
        doubaoIsRecording: Bool,
        doubaoInput: String,
        driverAvailable: Bool,
        chromecastConnected: Bool,
        macLevelDB: Double? = nil,
        remoteLevelDB: Double? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.model.status = status
            self.model.hidConnected = hidConnected
            self.model.bleConnected = bleConnected
            self.model.remoteStreaming = remoteStreaming
            self.model.macInputEnabled = macInputEnabled
            self.model.remoteInputEnabled = remoteInputEnabled
            self.model.doubaoIsRecording = doubaoIsRecording
            self.model.doubaoInput = doubaoInput
            self.model.driverAvailable = driverAvailable
            self.model.chromecastConnected = chromecastConnected
            if let macLevelDB { self.model.macLevelDB = macLevelDB }
            if let remoteLevelDB { self.model.remoteLevelDB = remoteLevelDB }
            self.model.refreshPermissions()
        }
    }

    func voiceStateChanged(_ presentation: VoiceSessionPresentation, active: Bool) {
        model.voicePresentation = presentation
        model.voiceActive = active
    }

    func receivedAudioPacket() { model.receivedAudioPackets += 1 }

    func voiceSessionEnded() { model.completedVoiceSessions += 1 }
    func observedButton(_ id: String) {
        model.lastButtonID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            if self?.model.lastButtonID == id { self?.model.lastButtonID = nil }
        }
    }

    func updateMacLevel(_ db: Double) {
        DispatchQueue.main.async { [weak self] in self?.model.macLevelDB = db }
    }

    func updateRemoteLevel(_ db: Double) {
        DispatchQueue.main.async { [weak self] in self?.model.remoteLevelDB = db }
    }

    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func startPermissionTimer() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.model.refreshPermissions()
            }
        }
    }
}

/// Permission help shared by the native console and onboarding flow.
struct ConsoleModalContent: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    @ObservedObject var model: ConsoleViewModel
    let modal: ConsoleModal

    var body: some View {
        switch modal {
        case .permission(let kind):
            PermissionGuideView(
                kind: kind,
                onCancel: { model.activeModal = nil },
                onOpenSettings: { model.openSettings(for: kind) }
            )
        }
    }
}

struct KeyboardShortcutCaptureView: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let buttonTitle: () -> String
    let onCancel: () -> Void
    let onSave: (RemoteCustomShortcut) -> Void
    @State private var captured: RemoteCustomShortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr("shortcut.capture.title"))
                    .font(.system(size: 20, weight: .semibold))
                Text(L10n.tr("shortcut.capture.instruction", buttonTitle()))
                    .font(.system(size: 13))
                    .foregroundStyle(ConsoleTheme.secondary)
            }

            KeyboardEventCaptureView { shortcut in
                captured = shortcut
            }
            .frame(height: 82)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        captured == nil ? ConsoleTheme.line : ConsoleTheme.green,
                        lineWidth: 1.5
                    )
            )
            .overlay {
                VStack(spacing: 5) {
                    Text(captured?.displayLabel ?? L10n.tr("shortcut.capture.waiting"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(captured == nil ? ConsoleTheme.secondary : ConsoleTheme.text)
                    Text(L10n.tr("shortcut.capture.modifiers"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(ConsoleTheme.tertiary)
                }
                .allowsHitTesting(false)
            }

            HStack {
                Button(L10n.tr("shell.action.cancel"), action: onCancel)
                Spacer()
                Button(L10n.tr("shortcut.capture.save")) {
                    if let captured { onSave(captured) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(captured == nil)
            }
        }
        .padding(24)
        .frame(width: 430, height: 245)
        .background(ConsoleTheme.panel)
        .foregroundStyle(ConsoleTheme.text)
    }
}

private struct KeyboardEventCaptureView: NSViewRepresentable {
    let onCapture: (RemoteCustomShortcut) -> Void

    func makeNSView(context: Context) -> KeyboardCaptureNSView {
        let view = KeyboardCaptureNSView()
        view.onCapture = onCapture
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyboardCaptureNSView: NSView {
    var onCapture: ((RemoteCustomShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        onCapture?(Self.shortcut(from: event))
    }

    private static func shortcut(from event: NSEvent) -> RemoteCustomShortcut {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var flags: CGEventFlags = []
        var prefix = ""
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
            prefix += "⌃"
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
            prefix += "⌥"
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
            prefix += "⇧"
        }
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
            prefix += "⌘"
        }

        let special: [UInt16: String] = [
            0x24: "Return", 0x30: "Tab", 0x31: "Space", 0x33: "Delete",
            0x35: "Esc", 0x73: "Home", 0x77: "End", 0x74: "Page Up",
            0x79: "Page Down", 0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        let key = special[event.keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? String(format: "Key 0x%02X", event.keyCode)
        return RemoteCustomShortcut(
            keyCode: event.keyCode,
            flags: flags.rawValue,
            label: prefix + key
        )
    }
}

private struct PermissionGuideView: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let kind: PermissionKind
    let onCancel: () -> Void
    let onOpenSettings: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: LogoAsset.image)
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 19, weight: .semibold))
                    Text(L10n.tr("permission.guide.step", page + 1, kind.pageCount))
                        .font(.system(size: 11))
                        .foregroundStyle(ConsoleTheme.secondary)
                }
                Spacer()
            }

            GuideScreenshot(kind: kind, page: $page)
                .frame(height: 320)
            if AppLanguage.selected.resolved() != .simplifiedChinese {
                Text(L10n.tr("permission.guide.illustration")).font(.caption).foregroundStyle(ConsoleTheme.secondary)
            }

            Text(kind.guidance[page])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ConsoleTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<kind.pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? ConsoleTheme.green : ConsoleTheme.line)
                            .frame(width: index == page ? 18 : 7, height: 7)
                    }
                }
                Spacer()
                Button(L10n.tr("shell.action.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(ConsoleButtonStyle(tone: .neutral))
                Button(L10n.tr("permission.action.open_settings"), action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(ConsoleButtonStyle(tone: ConsoleButtonTone.good))
            }
        }
        .padding(22)
        .frame(width: 620, height: 580)
        .background(ConsoleTheme.panel)
        .foregroundStyle(ConsoleTheme.text)
    }
}

private struct GuideScreenshot: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let kind: PermissionKind
    @Binding var page: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if AppLanguage.selected.resolved() == .simplifiedChinese, let image = GuideAsset.image(named: kind.screenshotName(for: page)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    screenshotPlaceholder
                }

                if AppLanguage.selected.resolved() == .simplifiedChinese && (kind != .doubaoInput || page == 0) {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ConsoleTheme.red, lineWidth: 3)
                        .frame(
                            width: proxy.size.width * highlightWidth,
                            height: proxy.size.height * highlightHeight
                        )
                        .position(
                            x: proxy.size.width * highlightX,
                            y: proxy.size.height * highlightY
                        )
                }

                HStack {
                    guideArrow(systemName: "chevron.left", enabled: page > 0) {
                        if page > 0 { page -= 1 }
                    }
                    Spacer()
                    guideArrow(systemName: "chevron.right", enabled: page < kind.pageCount - 1) {
                        if page < kind.pageCount - 1 { page += 1 }
                    }
                }
                .padding(.horizontal, 10)
            }
            .background(ConsoleTheme.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ConsoleTheme.line))
        }
    }

    private var screenshotPlaceholder: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(kind == .doubaoInput ? L10n.tr("permission.guide.doubaoSettings") : L10n.tr("permission.settings.title"))
                    .font(.system(size: 16, weight: .semibold))
                Text(kind == .doubaoInput ? L10n.tr("permission.guide.inputDevice") : L10n.tr("permission.settings.privacy"))
                    .foregroundStyle(ConsoleTheme.text)
                Text(kind.title)
                    .foregroundStyle(ConsoleTheme.green)
                Spacer()
            }
            .padding(20)
            .frame(width: 190, alignment: .leading)
            .background(ConsoleTheme.surface)
            VStack(alignment: .leading, spacing: 18) {
                Text(kind.title)
                    .font(.system(size: 18, weight: .semibold))
                Text(kind == .doubaoInput ? L10n.tr("permission.guide.selectMicrophone") : L10n.tr("permission.settings.allow_apps"))
                    .foregroundStyle(ConsoleTheme.secondary)
                HStack {
                    Image(nsImage: LogoAsset.image).resizable().frame(width: 30, height: 30)
                    Text(kind == .doubaoInput ? "vRemoteDr 2ch" : "vRemoter")
                    Spacer()
                    Toggle("", isOn: .constant(false)).labelsHidden()
                }
                .padding(12)
                .background(ConsoleTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                Spacer()
            }
            .padding(20)
        }
        .foregroundStyle(ConsoleTheme.text)
    }

    private var secondPageY: CGFloat {
        switch kind {
        case .doubaoInput: 0.5
        case .microphone: 0.92
        case .accessibility: 0.89
        case .inputMonitoring: 0.46
        case .bluetooth: 0.74
        }
    }

    private var highlightWidth: CGFloat {
        kind == .doubaoInput ? 0.36 : (page == 0 ? 0.38 : 0.45)
    }

    private var highlightHeight: CGFloat {
        kind == .doubaoInput ? 0.11 : 0.10
    }

    private var highlightX: CGFloat {
        kind == .doubaoInput ? 0.60 : (page == 0 ? 0.255 : 0.62)
    }

    private var highlightY: CGFloat {
        kind == .doubaoInput ? 0.40 : (page == 0 ? 0.25 : secondPageY)
    }

    private func guideArrow(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(ConsoleTheme.black.opacity(0.82))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? ConsoleTheme.text : ConsoleTheme.tertiary)
        .disabled(!enabled)
        .accessibilityLabel(L10n.tr(systemName == "chevron.left" ? "permission.guide.previous" : "permission.guide.next"))
    }

}

private enum ConsoleButtonTone { case neutral, good, warning, error }

private struct ConsoleButtonStyle: ButtonStyle {
    let tone: ConsoleButtonTone
    var compact = false
    var consoleSized = false

    init(tone: ConsoleButtonTone, compact: Bool = false, consoleSized: Bool = false) {
        self.tone = tone
        self.compact = compact
        self.consoleSized = consoleSized
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(height: buttonHeight)
            .background(configuration.isPressed ? background.opacity(0.65) : background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(foreground.opacity(0.85), lineWidth: 1)
            )
    }

    private var fontSize: CGFloat {
        if consoleSized { return compact ? 11 : 14 }
        return compact ? 9 : 11
    }

    private var horizontalPadding: CGFloat {
        if consoleSized { return compact ? 15 : 23 }
        return compact ? 12 : 18
    }

    private var buttonHeight: CGFloat {
        if consoleSized { return compact ? 30 : 43 }
        return compact ? 24 : 34
    }

    private var cornerRadius: CGFloat {
        if consoleSized { return compact ? 12 : 11 }
        return compact ? 10 : 9
    }

    private var foreground: Color {
        switch tone {
        case .neutral: ConsoleTheme.text
        case .good: ConsoleTheme.green
        case .warning: ConsoleTheme.amber
        case .error: ConsoleTheme.red
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: ConsoleTheme.black
        case .good: ConsoleTheme.green.opacity(0.12)
        case .warning: ConsoleTheme.amberDeep
        case .error: ConsoleTheme.redDeep
        }
    }
}

private func panelBackground(_ color: Color, radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius)
        .fill(color)
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(ConsoleTheme.line, lineWidth: 1))
}
