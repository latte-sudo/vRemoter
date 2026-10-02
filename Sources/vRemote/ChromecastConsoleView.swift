import AppKit
import SwiftUI

private enum ChromecastSettingsPage: Int, CaseIterable {
    case voice, remote, permissions, settings
    var title: String {
        switch self { case .voice: return L10n.tr("console.page.voice"); case .remote: return L10n.tr("console.page.remote"); case .permissions: return L10n.tr("console.page.permissions"); case .settings: return L10n.tr("console.page.settings") }
    }
    var symbol: String {
        switch self { case .voice: return "waveform"; case .remote: return "appletvremote.gen1"; case .permissions: return "checkmark.shield"; case .settings: return "gearshape" }
    }
    var subtitle: String {
        switch self {
        case .voice: return L10n.tr("console.page.voice.subtitle")
        case .remote: return L10n.tr("console.page.remote.subtitle")
        case .permissions: return L10n.tr("console.page.permissions.subtitle")
        case .settings: return L10n.tr("console.page.settings.subtitle")
        }
    }
}

/// Retain the meaning of feedback so changing language never dismisses an error.
private struct ConsoleMessage {
    let text: () -> String
    init(_ key: String, _ arguments: Any...) {
        let values = arguments.map { String(describing: $0) }
        text = { L10n.text(key, language: AppLanguage.selected, arguments: values) }
    }
    init(resolve: @escaping () -> String) { text = resolve }
}

struct ChromecastConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
    @ObservedObject private var languageStore = LanguageStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = ChromecastSettingsPage.voice
    @State private var setup = UserDefaults.standard.bool(forKey: "chromecast.onboarding.inProgress") || !UserDefaults.standard.bool(forKey: "chromecast.onboarding.completed")
    @State private var step = OnboardingProgress.resumedStep()
    @State private var furthestStep = OnboardingProgress.resumedStep()
    @State private var backup: [String: Any] = [:]
    @State private var configuration = AppStorage.voiceConfiguration
    @State private var appearance = AppAppearance.selected()
    @State private var routeRevision = 0
    @State private var routeFingerprint = ""
    @State private var message: ConsoleMessage?
    @State private var remoteNameDraft = RemoteDisplayName.alias()
    @State private var launchingVoiceApplication = false
    @State private var testText = ""
    @State private var testAudioBaseline = 0
    @State private var testSessionBaseline = 0
    @State private var testArmed = false
    @State private var confirmedSpeech = false
    @State private var troubleshooting = false
    @State private var selectedButton = "07"
    @State private var selectedGesture: RemoteButtonGesture?
    @State private var editorRevision = 0
    @State private var didCheckPermissions = false
    private var permissionCheckResult: String {
        guard didCheckPermissions else { return L10n.tr("console.permissions.notChecked") }
        let missing = [(L10n.tr("console.permission.bluetooth"), model.bluetoothGranted), (L10n.tr("console.permission.accessibility"), model.accessibilityGranted), (L10n.tr("console.permission.inputMonitoring"), model.inputMonitoringGranted)].filter { !$0.1 }.map { $0.0 }
        return missing.isEmpty ? L10n.tr("console.permission.allGranted") : L10n.tr("console.permission.missing", missing.joined(separator: L10n.tr("common.listSeparator")))
    }
    @FocusState private var speechFieldFocused: Bool
    @ObservedObject private var mappingStore = RemoteMappingStore.shared
    private var steps: [String] { [L10n.tr("console.setup.chooseTool"), L10n.tr("console.setup.connectRemote"), L10n.tr("console.setup.permissions"), L10n.tr("console.setup.voiceModes"), L10n.tr("console.setup.speechTrial"), L10n.tr("console.setup.buttons"), L10n.tr("console.setup.ready")] }
    private var audio: AudioPipe { AudioPipe.shared }
    private var connected: Bool { model.hidConnected && model.bleConnected }
    private var toolTitle: String {
        configuration.inputTool == .doubao ? L10n.tr("console.tool.doubao") :
        (configuration.customApplicationPath.isEmpty ? L10n.tr("console.tool.custom") : URL(fileURLWithPath: configuration.customApplicationPath).deletingPathExtension().lastPathComponent)
    }
    private var voiceModeTitle: String { configuration.remoteVoiceMode == .hold ? L10n.tr("console.voice.hold") : L10n.tr("console.voice.toggle") }

    var body: some View {
        ScrollViewReader { scroll in
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(ConsoleDesignTokens.line).frame(width: 1)
                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Color.clear.frame(height: 0).id("page-top")
                            if setup { onboardingContent } else { settingsContent }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, ConsoleDesignTokens.pagePadding).padding(.bottom, 28)
                    }
                    if let visibleMessage = message {
                        HStack(alignment: .top) {
                            Text(visibleMessage.text()).font(.system(size: 12)).textSelection(.enabled)
                            Spacer(minLength: 8)
                            Button { message = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel(L10n.tr("console.accessibility.dismissMessage"))
                        }.padding(14).background(ConsoleDesignTokens.secondarySurface)
                    }
                    if setup { onboardingFooter }
                }
            }.background(ConsoleDesignTokens.window).foregroundColor(ConsoleDesignTokens.text)
                .accentColor(ConsoleDesignTokens.accent)
                .environment(\.locale, AppLanguage.selected.locale)
                .sheet(item: $model.activeModal) { modal in ConsoleModalContent(model: model, modal: modal) }
                .onAppear(perform: prepareView)
                .onChange(of: configuration) { _ in saveVoiceConfiguration() }
                .onChange(of: appearance) { preference in
                    AppAppearance.set(preference); AppAppearanceController.apply(preference)
                }
                .onChange(of: step) { value in
                    OnboardingProgress.save(step: value)
                    furthestStep = max(furthestStep, value)
                    scroll.scrollTo("page-top", anchor: .top)
                }
                .onChange(of: page) { _ in scroll.scrollTo("page-top", anchor: .top) }
                .onChange(of: setup) { _ in scroll.scrollTo("page-top", anchor: .top) }
                .onChange(of: model.bleConnected) { value in if !value { invalidateTest() } }
                .onChange(of: model.hidConnected) { value in if !value { invalidateTest() } }
                .onChange(of: model.accessibilityGranted) { value in if !value { invalidateTest() } }
                .onChange(of: model.inputMonitoringGranted) { value in if !value { invalidateTest() } }
                .onChange(of: model.bluetoothGranted) { value in if !value { invalidateTest() } }
                .onChange(of: model.voiceActive) { active in
                    if active, testArmed {
                        // A second attempt needs its own packets and end event.
                        testAudioBaseline = model.receivedAudioPackets
                        testSessionBaseline = model.completedVoiceSessions
                        confirmedSpeech = false
                    }
                }
                .onChange(of: model.voicePresentation.phase) { phase in
                    if phase == .error { invalidateTest() }
                }
                .onChange(of: testText) { _ in confirmedSpeech = false }
                .onChange(of: editorRevision) { _ in
                    DispatchQueue.main.async {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            scroll.scrollTo("chromecast-inline-editor", anchor: .top)
                        }
                    }
                }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text(setup ? L10n.tr("console.sidebar.setup") : L10n.tr("console.sidebar.preferences")).font(.system(size: 18, weight: .semibold))
                Text(setup ? L10n.tr("console.sidebar.setupSubtitle") : L10n.tr("console.sidebar.settingsSubtitle"))
                    .font(.system(size: 11)).foregroundColor(ConsoleDesignTokens.secondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 45)
            if setup {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(steps.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 0) {
                            Button { step = index } label: {
                                HStack(spacing: 11) {
                                    ZStack {
                                        Circle().fill(index == step ? ConsoleDesignTokens.accent : ConsoleDesignTokens.surface)
                                        if stepCompleted(index) { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)) }
                                        else { Text("\(index + 1)").font(.system(size: 11, weight: .semibold)) }
                                    }.frame(width: 23, height: 23)
                                        .foregroundColor(index == step ? Color.white : ConsoleDesignTokens.accentText)
                                        .accessibilityHidden(true)
                                    Text(steps[index]).font(.system(size: 13, weight: index == step ? .semibold : .regular))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(index == step ? ConsoleDesignTokens.selection : Color.clear).cornerRadius(8)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(index > furthestStep)
                                .accessibilityLabel(L10n.tr("console.accessibility.step", index + 1, steps[index]))
                                .accessibilityValue(index == step ? L10n.tr("console.accessibility.currentStep") : stepCompleted(index) ? L10n.tr("console.accessibility.completed") : L10n.tr("console.accessibility.incomplete"))
                            if index < steps.count - 1 {
                                HStack { Rectangle().fill(stepCompleted(index) ? ConsoleDesignTokens.accent.opacity(0.45) : ConsoleDesignTokens.line)
                                    .frame(width: 1, height: 11).padding(.leading, 23); Spacer() }
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }.padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(ChromecastSettingsPage.allCases, id: \.self) { item in
                        Button { page = item } label: {
                            HStack(spacing: 11) {
                                Image(systemName: item.symbol).frame(width: 20).accessibilityHidden(true)
                                Text(item.title).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.font(.system(size: 13, weight: page == item ? .semibold : .regular))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .foregroundColor(page == item ? ConsoleDesignTokens.accentText : ConsoleDesignTokens.text)
                                .background(page == item ? ConsoleDesignTokens.selection : Color.clear).cornerRadius(8)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(item.title)
                            .accessibilityValue(page == item ? L10n.tr("console.accessibility.currentPage") : "")
                    }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 20)
            languagePicker.padding(.horizontal, 20)
            VStack(alignment: .leading, spacing: 10) {
                Label(model.remoteDisplayName, systemImage: "appletvremote.gen1")
                    .font(.system(size: 12, weight: .medium)).lineLimit(2).help(model.remoteDisplayName)
                Label(connected ? L10n.tr("console.connection.ready") : L10n.tr("console.connection.waiting"), systemImage: connected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11)).foregroundColor(connected ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
                Divider()
                HStack { Text("vRemoter"); Spacer(); Text("Chromecast") }.font(.system(size: 10)).foregroundColor(ConsoleDesignTokens.secondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.multilineTextAlignment(.leading)
            .frame(width: ConsoleDesignTokens.sidebarWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(ConsoleDesignTokens.sidebar)
    }

    private func stepCompleted(_ index: Int) -> Bool {
        guard index < step else { return false }
        switch index {
        case 0, 3: return configuration.isValid
        case 1: return connected
        case 2: return connected && model.accessibilityGranted && model.inputMonitoringGranted && model.bluetoothGranted
        case 4: return speechEvidence.canComplete && prerequisitesReady
        default: return true
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("vRemoter").font(.system(size: 12, weight: .semibold))
            Text(L10n.tr("console.header.breadcrumb", setup ? L10n.tr("console.header.firstUse") : page.title)).font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText)
            Spacer()
            ChromecastGlobalVoiceHeader(model: model)
        }.padding(.horizontal, 24).padding(.top, 18).frame(height: 83)
    }

    @ViewBuilder private var onboardingContent: some View {
        switch step {
        case 0:
            pageHeading(L10n.tr("console.setup.tool.eyebrow"), L10n.tr("console.setup.tool.title"), L10n.tr("console.setup.tool.description"))
            HStack(alignment: .top, spacing: 28) {
                voiceToolSelection.frame(maxWidth: .infinity)
                remoteHero.frame(width: 240)
            }
        case 1:
            pageHeading(L10n.tr("console.setup.connect.eyebrow"), L10n.tr("console.setup.connect.title"), L10n.tr("console.setup.connect.description"))
            connection
        case 2:
            pageHeading(L10n.tr("console.setup.permissions.eyebrow"), L10n.tr("console.setup.permissions.title"), L10n.tr("console.setup.permissions.description"))
            permissions
            if !connected {
                ConsoleCard {
                    VStack(alignment: .leading, spacing: 12) {
                        connectionStatus
                        Text(L10n.tr("console.connection.reconnectAfterPermission")).font(.caption)
                        Button(L10n.tr("console.connection.reconnectRemote")) { model.onReconnectInputs?() }.disabled(model.voiceActive)
                        Button(L10n.tr("console.connection.backToHelp")) { step = 1 }
                    }
                }
            }
        case 3:
            pageHeading(L10n.tr("console.setup.modes.eyebrow"), L10n.tr("console.setup.modes.title"), L10n.tr("console.setup.modes.description"))
            voiceSettings
        case 4:
            pageHeading(L10n.tr("console.setup.trial.eyebrow"), L10n.tr("console.setup.trial.title"), "")
            speechTest
        case 5:
            pageHeading(L10n.tr("console.setup.buttons.eyebrow"), L10n.tr("console.setup.buttons.title"), L10n.tr("console.setup.buttons.description"))
            mapping
        default:
            completion
        }
    }

    @ViewBuilder private var settingsContent: some View {
        pageHeading("", page.title, page.subtitle)
        switch page {
        case .voice:
            voiceToolSelection
            voiceSettings
            audioSettings
            Button(L10n.tr("console.setup.speechTrial")) { beginSetup(at: 4) }.disabled(model.voiceActive)
        case .remote:
            remoteOverview
            mapping
        case .permissions:
            permissions
            diagnostics
        case .settings:
            settings
        }
    }

    private func pageHeading(_ eyebrow: String, _ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !eyebrow.isEmpty { Text(eyebrow).font(.system(size: 11, weight: .semibold)).foregroundColor(ConsoleDesignTokens.accentText) }
            Text(title).font(.system(size: 29, weight: .semibold))
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 13)).foregroundColor(ConsoleDesignTokens.secondaryText).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private var onboardingFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(String(format: "%02d / 07", step + 1)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                Button(L10n.tr("console.setup.later")) { deferSetup() }.disabled(model.voiceActive)
                Spacer()
                if step > 0 { Button(L10n.tr("console.setup.back")) { step -= 1 } }
                Button(step == 6 ? L10n.tr("console.setup.start") : L10n.tr("console.setup.next")) { advanceSetup() }
                    .buttonStyle(ConsolePrimaryButtonStyle()).disabled(!canAdvance || model.voiceActive)
            }.padding(.horizontal, 24).padding(.vertical, 17)
        }
    }

    private var speechEvidence: OnboardingSpeechEvidence {
        OnboardingSpeechEvidence(armed: testArmed,
            receivedAudioPackets: model.receivedAudioPackets, baselineAudioPackets: testAudioBaseline,
            endedSessions: model.completedVoiceSessions, baselineEndedSessions: testSessionBaseline,
            voiceActive: model.voiceActive, routeAvailable: audio.isOutputDeviceAvailable,
            remoteConnected: connected, text: testText, userConfirmedRecognition: confirmedSpeech)
    }
    private var prerequisitesReady: Bool {
        connected && model.accessibilityGranted && model.inputMonitoringGranted && model.bluetoothGranted && audio.isOutputDeviceAvailable && configuration.isValid
    }
    private var canConfirmSpeech: Bool {
        testArmed && model.receivedAudioPackets > testAudioBaseline && model.completedVoiceSessions > testSessionBaseline && !model.voiceActive && model.voicePresentation.phase == .ended && model.voicePresentation.startedAt != nil && prerequisitesReady && !testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var canAdvance: Bool {
        switch step {
        case 0, 3: return configuration.isValid
        case 1: return connected
        case 2: return connected && model.accessibilityGranted && model.inputMonitoringGranted && model.bluetoothGranted
        case 4, 6: return speechEvidence.canComplete && prerequisitesReady && model.voicePresentation.phase == .ended && model.voicePresentation.startedAt != nil
        default: return true
        }
    }

    private var voiceToolSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                toolCard(.doubao, title: L10n.tr("console.tool.doubao"), subtitle: L10n.tr("console.tool.supported"), symbol: "sparkles")
                toolCard(.custom, title: L10n.tr("console.tool.other"), subtitle: L10n.tr("console.tool.chooseOwn"), symbol: "app")
            }
            if configuration.inputTool == .custom {
                ConsoleCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(toolTitle).font(.headline).lineLimit(2)
                            Spacer()
                            Button(L10n.tr("console.tool.chooseApp")) { chooseVoiceApplication() }
                        }
                        if !configuration.customApplicationPath.isEmpty {
                            Button(L10n.tr("console.tool.clearApp")) { configuration.customApplicationPath = ""; configuration.customBundleIdentifier = "" }
                        }
                        DisclosureGroup(L10n.tr("console.tool.advancedIdentifier")) {
                            TextField(L10n.tr("console.tool.bundleIdentifier"), text: $configuration.customBundleIdentifier).textFieldStyle(.roundedBorder)
                                .padding(.top, 8)
                        }
                        Text(L10n.tr("console.tool.compatibility"))
                            .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    }
                }
            }
            Button(launchingVoiceApplication ? L10n.tr("console.tool.opening") : L10n.tr("console.tool.openNamed", toolTitle)) { launchVoiceTool() }
                .disabled(launchingVoiceApplication || !configuration.isValid)
        }.disabled(model.voiceActive)
    }
    private func toolCard(_ tool: VoiceInputTool, title: String, subtitle: String, symbol: String) -> some View {
        Button { configuration.inputTool = tool } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: symbol).font(.system(size: 21)); Spacer(); Image(systemName: configuration.inputTool == tool ? "checkmark.circle.fill" : "circle") }
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundColor(ConsoleDesignTokens.secondaryText)
            }.padding(18).frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .background(configuration.inputTool == tool ? ConsoleDesignTokens.selection : ConsoleDesignTokens.surface)
                .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(configuration.inputTool == tool ? ConsoleDesignTokens.accent : ConsoleDesignTokens.line, lineWidth: 1.5))
        }.buttonStyle(.plain).accessibilityValue(configuration.inputTool == tool ? L10n.tr("console.accessibility.selected") : L10n.tr("console.accessibility.notSelected"))
    }
    private var remoteHero: some View {
        VStack(spacing: 16) {
            if let image = ChromecastMappingPhoto.image { Image(nsImage: image).resizable().scaledToFit().frame(height: 290).cornerRadius(14).accessibilityLabel(L10n.tr("console.accessibility.remotePhoto")) }
            Text(L10n.tr("console.setup.readySlogan")).font(.system(size: 13, weight: .medium))
        }.padding(20).frame(maxWidth: .infinity).background(ConsoleDesignTokens.hero).cornerRadius(17)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Label(L10n.tr("console.connection.stepOne"), systemImage: "dot.radiowaves.left.and.right")
                    Label(L10n.tr("console.connection.stepTwo"), systemImage: "hand.tap")
                    Label(L10n.tr("console.connection.stepThree"), systemImage: "checkmark.circle")
                    HStack {
                        Button(L10n.tr("console.connection.openBluetooth")) { open("x-apple.systempreferences:com.apple.Bluetooth") }
                        Button(L10n.tr("console.connection.reconnect")) { model.onReconnectInputs?() }.disabled(model.voiceActive)
                    }
                }.font(.system(size: 13))
            }
            ConsoleCard { connectionStatus }
            ConsoleNotice(text: L10n.tr("console.connection.permissionsFirst"))
            Button(L10n.tr("console.connection.checkPermissionsFirst")) { step = 2 }
            if !model.bluetoothGranted { permissionRow(L10n.tr("console.permission.bluetooth"), detail: L10n.tr("console.permission.connectVoice"), granted: false, status: model.bluetoothPermissionStatus, kind: .bluetooth) }
            if !model.permissionRequestMessage.isEmpty { Text(model.permissionRequestMessage).font(.caption).textSelection(.enabled) }
        }
    }
    private var connectionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.remoteDisplayName).font(.system(size: 15, weight: .semibold)).lineLimit(2).help(model.remoteDisplayName)
            HStack(spacing: 28) {
                statusLabel(L10n.tr("console.connection.buttons"), connected: model.hidConnected)
                statusLabel(L10n.tr("console.connection.voice"), connected: model.bleConnected)
            }
        }
    }
    private func statusLabel(_ title: String, connected: Bool) -> some View {
        Label(L10n.tr("console.connection.namedStatus", title, connected ? L10n.tr("console.connection.connected") : L10n.tr("console.connection.disconnected")), systemImage: connected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 12)).foregroundColor(connected ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionRow(L10n.tr("console.permission.bluetooth"), detail: L10n.tr("console.permission.receiveAudio"), granted: model.bluetoothGranted, status: model.bluetoothPermissionStatus, kind: .bluetooth)
            permissionRow(L10n.tr("console.permission.accessibility"), detail: L10n.tr("console.permission.sendShortcut"), granted: model.accessibilityGranted, status: model.accessibilityPermissionStatus, kind: .accessibility)
            permissionRow(L10n.tr("console.permission.inputMonitoring"), detail: L10n.tr("console.permission.receiveButtons"), granted: model.inputMonitoringGranted, status: model.inputMonitoringPermissionStatus, kind: .inputMonitoring)
            HStack {
                Text(permissionCheckResult).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                Spacer()
                Button(L10n.tr("console.permission.recheck")) { checkPermissions() }
            }
            if !model.permissionRequestMessage.isEmpty { Text(model.permissionRequestMessage).font(.caption).textSelection(.enabled) }
            if let checked = model.permissionCheckedAt { Text(L10n.tr("console.permission.lastCheck", checked.formatted(Date.FormatStyle(date: .abbreviated, time: .standard).locale(AppLanguage.selected.locale)))).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
            ConsoleNotice(text: L10n.tr("console.permission.remoteOnly"))
            Text(L10n.tr("console.permission.missingApp"))
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, status: String, kind: PermissionKind) -> some View {
        ConsoleCard {
            HStack(spacing: 16) {
                Button { model.activeModal = .permission(kind) } label: {
                    Image(systemName: granted ? "checkmark.shield.fill" : "shield").font(.system(size: 22))
                        .foregroundColor(granted ? ConsoleDesignTokens.success : ConsoleDesignTokens.accent)
                }.buttonStyle(.plain).help(L10n.tr("console.permission.instructions", title)).accessibilityLabel(L10n.tr("console.permission.instructions", title))
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText) }
                Spacer(minLength: 8)
                Text(status).font(.system(size: 12)).foregroundColor(granted ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
                if !granted { Button(L10n.tr("console.permission.request")) { _ = model.requestPermission(for: kind) }.disabled(model.voiceActive) }
                Button(L10n.tr("console.permission.openSettings")) { model.openSettings(for: kind) }
            }.accessibilityElement(children: .contain)
        }
    }

    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            ChromecastHelpLabel(title: L10n.tr("console.voice.remoteModeTitle"), explanation: L10n.tr("console.voice.remoteModeHelp"))
            HStack(spacing: 12) {
                voiceModeCard(.toggle, title: L10n.tr("console.voice.toggle"), subtitle: L10n.tr("console.voice.toggleHelp"), symbol: "hand.tap")
                voiceModeCard(.hold, title: L10n.tr("console.voice.hold"), subtitle: L10n.tr("console.voice.holdHelp"), symbol: "hand.point.up.left")
            }
            ChromecastHelpLabel(title: L10n.tr("console.voice.toolModeTitle", toolTitle), explanation: L10n.tr("console.voice.toolModeHelp"))
            ConsoleCard {
                VStack(spacing: 18) {
                    Picker(L10n.tr("console.voice.toolMode"), selection: $configuration.inputToolTriggerMode) {
                        Text(L10n.tr("console.voice.toolToggle")).tag(InputToolTriggerMode.toggle)
                        Text(L10n.tr("console.voice.toolHold")).tag(InputToolTriggerMode.hold)
                    }
                    Divider()
                    Picker(L10n.tr("console.voice.shortcut"), selection: $configuration.triggerKey) { ForEach(InputTriggerKey.allCases) { Text($0.title).tag($0) } }
                }
            }
            HStack { Text(L10n.tr("console.voice.shortcutHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText); Spacer(); Button(L10n.tr("console.tool.openNamed", toolTitle)) { launchVoiceTool() }.disabled(launchingVoiceApplication) }
            ConsoleNotice(text: L10n.tr("console.voice.modesHelp"))
        }.disabled(model.voiceActive)
    }
    private func voiceModeCard(_ mode: RemoteVoiceMode, title: String, subtitle: String, symbol: String) -> some View {
        Button { configuration.remoteVoiceMode = mode } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 21))
                VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 12, weight: .semibold)); Text(subtitle).font(.system(size: 11)).foregroundColor(ConsoleDesignTokens.secondaryText) }
                Spacer(minLength: 0)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 58)
                .background(configuration.remoteVoiceMode == mode ? ConsoleDesignTokens.selection : ConsoleDesignTokens.surface)
                .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(configuration.remoteVoiceMode == mode ? ConsoleDesignTokens.accent : ConsoleDesignTokens.line, lineWidth: 1.5))
        }.buttonStyle(.plain).accessibilityValue(configuration.remoteVoiceMode == mode ? L10n.tr("console.accessibility.selected") : L10n.tr("console.accessibility.notSelected"))
    }

    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("console.audio.title")).font(.system(size: 14, weight: .semibold))
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("console.audio.path", model.remoteDisplayName, toolTitle)).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Picker(L10n.tr("console.audio.outputDevice"), selection: Binding(get: { audio.selectedOutputUID ?? "" }, set: {
                        _ = audio.selectOutputRoute(uid: $0.isEmpty ? nil : $0); invalidateTest(); routeRevision += 1
                    })) {
                        Text(L10n.tr("console.audio.noOutput")).tag("")
                        ForEach(audio.outputRoutes, id: \.uid) { route in Text(route.name).tag(route.uid) }
                    }.id(routeRevision).disabled(model.voiceActive)
                    Text(L10n.tr("console.audio.matchDevice")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Divider()
                    HStack {
                        ChromecastHelpLabel(title: L10n.tr("console.audio.remoteVolume"), explanation: L10n.tr("console.audio.volumeHelp"))
                        Spacer(); Text(String(format: "%.1f×", audio.remoteGain)).monospacedDigit()
                    }
                    Slider(value: Binding(get: { Double(audio.remoteGain) }, set: { audio.setRemoteGain(Float($0)); routeRevision += 1 }), in: 0...20)
                        .accessibilityLabel(L10n.tr("console.audio.remoteVolume")).disabled(model.voiceActive)
                    HStack {
                        Button(L10n.tr("console.audio.refreshDevices")) { audio.refreshOutputRoutes(); routeRevision += 1 }
                        Spacer()
                        Button(L10n.tr("console.audio.testTone")) { message = ConsoleMessage(audio.playTestTone() ? "console.audio.testToneSent" : "console.audio.testToneFailed") }.disabled(model.voiceActive || !audio.isOutputDeviceAvailable)
                    }
                }
            }
            if !audio.isOutputDeviceAvailable { ConsoleNotice(text: L10n.tr("console.audio.noDeviceHelp"), isError: true) }
        }
    }

    private var speechTest: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 22) {
                ChromecastVoiceKeyPhoto()
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("console.trial.findVoiceKey")).font(.system(size: 15, weight: .semibold))
                    Text(L10n.tr("console.trial.voiceKeyLocation")).font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Text(voiceModeTitle).font(.system(size: 13, weight: .medium)).foregroundColor(ConsoleDesignTokens.accentText)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.tr("console.trial.prompt")).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button(L10n.tr("console.tool.openNamed", toolTitle)) { launchVoiceTool() }.disabled(model.voiceActive || launchingVoiceApplication)
                }
                TextEditor(text: $testText).focused($speechFieldFocused).font(.system(size: 16))
                    .frame(minHeight: 120, maxHeight: 160).padding(10)
                    .background(ConsoleDesignTokens.surface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ConsoleDesignTokens.line))
                    .accessibilityLabel(L10n.tr("console.trial.field"))
                Text(testArmed ? L10n.tr("console.trial.armedHelp") : L10n.tr("console.trial.notArmedHelp"))
                    .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
            }
            HStack(spacing: 12) {
                if model.voiceActive {
                    Button(L10n.tr("console.trial.stop")) { model.onStopMicrophone?() }.buttonStyle(ConsolePrimaryButtonStyle())
                } else if canConfirmSpeech {
                    Button(confirmedSpeech ? L10n.tr("console.trial.confirmed") : L10n.tr("console.trial.confirm")) { confirmedSpeech = true }
                        .buttonStyle(ConsolePrimaryButtonStyle()).disabled(confirmedSpeech)
                    Button(L10n.tr("console.trial.retry")) { armSpeechTest() }
                } else {
                    Button(testArmed ? L10n.tr("console.trial.rearm") : L10n.tr("console.trial.arm")) { armSpeechTest() }
                        .buttonStyle(ConsolePrimaryButtonStyle()).disabled(!prerequisitesReady)
                    if testArmed { Text(L10n.tr("console.trial.ready")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
                }
            }
            if !audio.isOutputDeviceAvailable { ConsoleNotice(text: L10n.tr("console.trial.noDevice"), isError: true) }
            DisclosureGroup(L10n.tr("console.trial.troubleshoot"), isExpanded: $troubleshooting) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.tr("console.trial.troubleshootSteps")).font(.system(size: 12))
                    audioSettings
                    ProgressView(value: normalizedLevel).accessibilityLabel(L10n.tr("console.accessibility.audioLevel"))
                    Text(String(format: L10n.tr("console.audio.liveLevel"), model.remoteLevelDB)).font(.caption)
                    Label(testArmed && model.receivedAudioPackets > testAudioBaseline ? L10n.tr("console.trial.audioReceived") : L10n.tr("console.trial.waitingAudio"), systemImage: "waveform")
                    Label(testArmed && model.completedVoiceSessions > testSessionBaseline ? L10n.tr("console.trial.ended") : L10n.tr("console.trial.waitingEnd"), systemImage: "stop.circle")
                    DisclosureGroup(L10n.tr("diagnostics.details")) {
                        Text(audio.routeDiagnostics).font(.caption).textSelection(.enabled)
                    }
                    HStack {
                        Button(L10n.tr("console.permission.check")) { checkPermissions() }
                        Button(L10n.tr("console.trial.checkModes")) { step = 3 }
                    }
                    Text(permissionCheckResult).font(.caption)
                }.padding(.top, 14)
            }.font(.system(size: 12))
            Text(L10n.tr("console.trial.evidenceHelp"))
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private var normalizedLevel: Double { model.remoteLevelDB.isFinite ? max(0, min(1, (model.remoteLevelDB + 60) / 60)) : 0 }

    private var completion: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: speechEvidence.canComplete ? "checkmark.circle.fill" : "exclamationmark.circle").font(.system(size: 46))
                .foregroundColor(speechEvidence.canComplete ? ConsoleDesignTokens.success : ConsoleDesignTokens.error)
            pageHeading(L10n.tr("console.setup.done.eyebrow"), speechEvidence.canComplete ? L10n.tr("console.setup.readySlogan") : L10n.tr("console.setup.done.retry"), L10n.tr("console.setup.done.description"))
            ConsoleCard {
                VStack(spacing: 18) {
                    summaryRow(L10n.tr("console.summary.remote"), model.remoteDisplayName)
                    Divider(); summaryRow(L10n.tr("console.summary.tool"), toolTitle)
                    Divider(); summaryRow(L10n.tr("console.summary.voiceKey"), voiceModeTitle)
                    Divider(); summaryRow(L10n.tr("console.summary.shortcut"), configuration.triggerKey.title + " · " + (configuration.inputToolTriggerMode == .hold ? L10n.tr("console.summary.hold") : L10n.tr("console.summary.toggle")))
                }
            }
            if !canAdvance { Button(L10n.tr("console.trial.back")) { step = 4 } }
            Text(L10n.tr("console.setup.buttonsSaved")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundColor(ConsoleDesignTokens.secondaryText); Spacer(); Text(value).fontWeight(.medium).multilineTextAlignment(.trailing) }.font(.system(size: 13))
    }

    private var remoteOverview: some View {
        ConsoleCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 20) {
                    if let image = ChromecastMappingPhoto.image { Image(nsImage: image).resizable().scaledToFit().frame(width: 70, height: 105).cornerRadius(10).accessibilityHidden(true) }
                    VStack(alignment: .leading, spacing: 14) {
                        connectionStatus
                        HStack {
                            Text(L10n.tr("console.remote.name")).font(.system(size: 12))
                            TextField(RemoteDisplayName.defaultName, text: $remoteNameDraft).textFieldStyle(.roundedBorder)
                                .accessibilityLabel(L10n.tr("console.accessibility.remoteName")).onSubmit { saveRemoteName() }
                            Button(L10n.tr("console.common.save")) { saveRemoteName() }.disabled(!remoteNameValidationMessage.isEmpty)
                        }.disabled(model.voiceActive)
                    }
                }
                if !remoteNameValidationMessage.isEmpty { Text(remoteNameValidationMessage).font(.caption).foregroundColor(ConsoleDesignTokens.error) }
                Divider()
                HStack {
                    Text(L10n.tr("console.remote.nameHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Spacer()
                    Button(L10n.tr("console.connection.bluetoothSettings")) { open("x-apple.systempreferences:com.apple.Bluetooth") }
                    Button(L10n.tr("console.connection.reconnect")) { model.onReconnectInputs?() }.disabled(model.voiceActive)
                }
            }
        }
    }
    private var mapping: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text(L10n.tr("console.mapping.title")).font(.title2).bold()
                Toggle(L10n.tr("console.mapping.enable"), isOn: Binding(get: { mappingStore.isEnabled(.chromecast) }, set: { model.setRemoteMappingEnabled($0, remote: .chromecast) }))
                    .toggleStyle(.switch)
                Spacer()
            }
            Text(L10n.tr("console.mapping.remote", model.remoteDisplayName)).font(.callout)
                .lineLimit(2).help(model.remoteDisplayName)
            Divider()
            ChromecastMappingCanvas(selectedButton: selectedButton, selectedGesture: selectedGesture,
                observedButton: model.lastButtonID, voiceActive: model.voiceActive,
                voiceModeTitle: configuration.remoteVoiceMode == .hold ? L10n.tr("console.voice.hold") : L10n.tr("console.voice.toggle"),
                onSelect: { selectedButton = $0; selectedGesture = nil },
                onEdit: { button, gesture in
                    selectedButton = button; selectedGesture = gesture; editorRevision += 1
                },
                onVoiceSettings: { if setup { step = 3 } else { page = .voice } })
            Text(L10n.tr("console.mapping.help"))
                .font(.caption).foregroundColor(.secondary)
            if let gesture = selectedGesture,
               let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == selectedButton && !$0.voiceControlled }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.tr("console.mapping.edit", button.title, gesture.title)).font(.headline)
                        Spacer()
                        Button(L10n.tr("console.mapping.close")) { selectedGesture = nil }
                    }
                    ChromecastGestureEditor(button: button, gesture: gesture)
                        .id(button.id + gesture.rawValue)
                    Toggle(L10n.tr("console.mapping.repeat"), isOn: Binding(get: {
                        mappingStore.holdRepeats(for: button, remote: .chromecast)
                    }, set: {
                        mappingStore.setHoldRepeats($0, for: button, remote: .chromecast)
                    }))
                    Text(L10n.tr("console.mapping.repeatHelp")).font(.caption)
                }.padding(16).background(Color.accentColor.opacity(0.08)).cornerRadius(12)
                    .id("chromecast-inline-editor")
            }
            Text(L10n.tr("console.mapping.infraredHelp")).font(.caption)
            Button(L10n.tr("console.mapping.restore")) { confirmResetMappings() }
            Text(L10n.tr("console.mapping.saveHelp")).font(.caption)
        }.disabled(model.voiceActive)
    }

    private var languagePicker: some View {
        Picker(L10n.tr("language.title"), selection: Binding(get: { AppLanguage.selected }, set: { AppLanguage.selected = $0 })) {
            ForEach(AppLanguage.allCases, id: \.self) { language in Text(language.title).tag(language) }
        }.accessibilityLabel(L10n.tr("language.title"))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.tr("language.title")).font(.headline)
            ConsoleCard {
                VStack(alignment: .leading, spacing: 8) {
                    languagePicker
                    Text(L10n.tr("language.help")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                }
            }
            Text(L10n.tr("console.settings.appearance")).font(.headline)
            ConsoleCard {
                HStack {
                    VStack(alignment: .leading, spacing: 5) { Text(L10n.tr("console.settings.theme")).fontWeight(.medium); Text(L10n.tr("console.settings.themeHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
                    Spacer(); ConsoleAppearancePicker(selection: $appearance)
                }
            }
            Text(L10n.tr("console.settings.startup")).font(.headline)
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle(L10n.tr("console.settings.login"), isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { enabled in
                        do { try LaunchAtLogin.setEnabled(enabled) } catch { message = ConsoleMessage("console.settings.operationFailed") }
                        routeRevision += 1
                    })).toggleStyle(.switch).id(routeRevision)
                    Divider()
                    Toggle(L10n.tr("console.settings.dock"), isOn: Binding(get: { DockVisibilityPreference.isVisible() }, set: { visible in
                        if DockVisibilityController.apply(visible) { DockVisibilityPreference.setVisible(visible); routeRevision += 1 }
                        else { message = ConsoleMessage("console.settings.dockError") }
                    })).toggleStyle(.switch).id(routeRevision)
                    Text(L10n.tr("console.settings.dockHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                }
            }
            Text(L10n.tr("console.backup.title")).font(.headline)
            ConsoleCard {
                VStack(spacing: 18) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(L10n.tr("console.backup.exportTitle")).fontWeight(.medium); Text(L10n.tr("console.backup.exportHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button(L10n.tr("console.backup.export")) { _ = exportSettings() } }
                    Divider()
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(L10n.tr("console.backup.importAction")).fontWeight(.medium); Text(L10n.tr("console.backup.importHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button(L10n.tr("console.backup.import")) { importSettings() } }
                }
            }.disabled(model.voiceActive)
            ConsoleNotice(text: L10n.tr("console.backup.help"))
            Text(L10n.tr("console.settings.restore")).font(.headline)
            ConsoleCard {
                VStack(spacing: 18) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(L10n.tr("console.settings.resetTitle")).fontWeight(.medium); Text(L10n.tr("console.settings.resetHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button(L10n.tr("console.settings.reset")) { resetSettings() }.foregroundColor(ConsoleDesignTokens.error) }
                    Divider()
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(L10n.tr("console.settings.setupTitle")).fontWeight(.medium); Text(L10n.tr("console.settings.setupHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button(L10n.tr("console.settings.restartSetup")) { beginSetup() } }
                    if UserDefaults.standard.bool(forKey: "chromecast.onboarding.inProgress") {
                        Divider()
                        HStack { Text(L10n.tr("console.settings.resumeHelp")); Spacer(); Button(L10n.tr("console.settings.resume")) { setup = true } }
                        HStack { Text(L10n.tr("console.settings.cancelHelp")).font(.caption); Spacer(); Button(L10n.tr("console.settings.cancel")) { cancelSetup() } }
                    }
                }
            }.disabled(model.voiceActive)
            Text(L10n.tr("console.settings.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.tr("console.settings.development")))
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("console.diagnostics.title")).font(.headline)
            ConsoleCard {
                VStack(alignment: .leading, spacing: 14) {
                    connectionStatus
                    Divider()
                    Text(model.voicePresentation.detail.isEmpty ? model.status : model.voicePresentation.detail)
                    Text(L10n.tr("console.diagnostics.counts", model.receivedAudioPackets, model.completedVoiceSessions)).font(.caption)
                    DisclosureGroup(L10n.tr("diagnostics.details")) {
                        Text(audio.routeDiagnostics).font(.caption).textSelection(.enabled)
                    }
                    Text(L10n.tr("console.diagnostics.recognitionHelp")).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    HStack {
                        Button(L10n.tr("console.connection.reconnectRemote")) { model.onReconnectInputs?() }.disabled(model.voiceActive)
                        Button(L10n.tr("console.diagnostics.stopCheck")) { model.onStopMicrophone?(); checkPermissions(); audio.refreshOutputRoutes(); routeRevision += 1 }
                    }
                }
            }
        }
    }

    private func prepareView() {
        if setup {
            UserDefaults.standard.set(true, forKey: "chromecast.onboarding.inProgress")
            if let data = UserDefaults.standard.data(forKey: "chromecast.onboarding.backup"),
               let saved = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] { backup = saved }
            else { backup = ChromecastSettingsArchive.snapshot(); saveSetupBackup() }
        }
        routeFingerprint = currentRouteFingerprint
        audio.onConfigurationChanged = {
            if !audio.isOutputDeviceAvailable && model.voiceActive { model.onStopMicrophone?() }
            let fingerprint = currentRouteFingerprint
            if fingerprint != routeFingerprint { invalidateTest(); routeFingerprint = fingerprint }
            routeRevision += 1
        }
        audio.refreshOutputRoutes()
        model.refreshPermissions()
    }
    private func saveVoiceConfiguration() {
        guard !model.voiceActive else { return }
        AppStorage.voiceConfiguration = configuration
        AppStorage.inputTriggerKey = configuration.triggerKey
        model.inputTriggerKey = configuration.triggerKey
        model.onVoiceConfigurationChanged?()
        invalidateTest()
    }
    private var currentRouteFingerprint: String { "\(audio.selectedOutputUID ?? "")|\(audio.isOutputDeviceAvailable)|\(audio.remoteGain)" }
    private func beginSetup(at firstStep: Int = 0) {
        guard !model.voiceActive else { return }
        // Preserve the original cancellation snapshot when resuming a deferred flow.
        if !UserDefaults.standard.bool(forKey: "chromecast.onboarding.inProgress") {
            backup = ChromecastSettingsArchive.snapshot(); saveSetupBackup()
        }
        UserDefaults.standard.set(true, forKey: "chromecast.onboarding.inProgress")
        step = firstStep; furthestStep = firstStep; invalidateTest(); setup = true
    }
    private func deferSetup() { setup = false; page = .voice }
    private func advanceSetup() {
        guard canAdvance, !model.voiceActive else { return }
        if step == 6 {
            UserDefaults.standard.set(true, forKey: "chromecast.onboarding.completed")
            UserDefaults.standard.set(false, forKey: "chromecast.onboarding.inProgress")
            UserDefaults.standard.removeObject(forKey: "chromecast.onboarding.backup")
            setup = false; page = .voice; step = 0; furthestStep = 0
        } else { step += 1 }
    }
    private func saveSetupBackup() {
        if let data = try? PropertyListSerialization.data(fromPropertyList: backup, format: .binary, options: 0) { UserDefaults.standard.set(data, forKey: "chromecast.onboarding.backup") }
    }
    private func cancelSetup() {
        guard confirmReplacement(title: L10n.tr("console.setup.cancel.title"), detail: L10n.tr("console.setup.cancel.description"), action: L10n.tr("console.setup.cancel.action")), !model.voiceActive else { return }
        ChromecastSettingsArchive.restore(backup); reloadConfiguration()
        UserDefaults.standard.removeObject(forKey: "chromecast.onboarding.backup")
        UserDefaults.standard.set(false, forKey: "chromecast.onboarding.inProgress")
        setup = false; step = 0; furthestStep = 0; message = ConsoleMessage("console.setup.cancel.done")
    }
    private func armSpeechTest() {
        guard !model.voiceActive, prerequisitesReady else { return }
        testText = ""; confirmedSpeech = false
        testAudioBaseline = model.receivedAudioPackets; testSessionBaseline = model.completedVoiceSessions
        testArmed = true; speechFieldFocused = true
    }
    private func invalidateTest() { testArmed = false; confirmedSpeech = false; testText = "" }
    private func reloadConfiguration() {
        remoteNameDraft = RemoteDisplayName.alias(); model.refreshRemoteDisplayName()
        appearance = AppAppearance.selected(); AppAppearanceController.apply(appearance)
        _ = DockVisibilityController.apply(DockVisibilityPreference.isVisible())
        configuration = AppStorage.voiceConfiguration
        model.inputTriggerKey = configuration.triggerKey
        model.setRemoteMappingEnabled(mappingStore.isEnabled(.chromecast), remote: .chromecast)
        model.onVoiceConfigurationChanged?()
        audio.refreshOutputRoutes(); routeRevision += 1; invalidateTest()
    }
    private func checkPermissions() {
        model.refreshPermissions()
        let missing = [(L10n.tr("console.permission.bluetooth"), model.bluetoothGranted), (L10n.tr("console.permission.accessibility"), model.accessibilityGranted), (L10n.tr("console.permission.inputMonitoring"), model.inputMonitoringGranted)].filter { !$0.1 }.map { $0.0 }
        didCheckPermissions = true
        if !missing.isEmpty { invalidateTest() }
    }
    private var remoteNameValidationMessage: String {
        do { _ = try RemoteDisplayName.normalizedAlias(remoteNameDraft); return "" }
        catch RemoteDisplayName.ValidationError.tooLong { return L10n.tr("console.remote.nameTooLong", RemoteDisplayName.maximumLength) }
        catch { return L10n.tr("console.remote.invalidName") }
    }
    private func saveRemoteName() {
        guard !model.voiceActive else { return }
        do { try RemoteDisplayName.set(remoteNameDraft); remoteNameDraft = RemoteDisplayName.alias(); model.refreshRemoteDisplayName(); message = ConsoleMessage("console.remote.nameSaved") }
        catch RemoteDisplayName.ValidationError.tooLong { message = ConsoleMessage("console.remote.nameTooLong", RemoteDisplayName.maximumLength) }
        catch { message = ConsoleMessage("console.remote.invalidName") }
    }
    private func launchVoiceTool() {
        guard !model.voiceActive, !launchingVoiceApplication else { return }
        launchingVoiceApplication = true
        VoiceApplicationLauncher().launch(configuration: configuration) { result in
            DispatchQueue.main.async {
                launchingVoiceApplication = false
                switch result { case .success(let success): message = ConsoleMessage(resolve: { success.message }); case .failure(let error): message = ConsoleMessage(resolve: { error.localizedDescription }) }
            }
        }
    }
    private func chooseVoiceApplication() {
        let panel = NSOpenPanel(); panel.title = L10n.tr("console.tool.choosePanel")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, !model.voiceActive else { return }
        let identifier = Bundle(url: url)?.bundleIdentifier
        guard VoiceApplicationLaunchEnvironment.workspace.isValidApplication(url, identifier) else { message = ConsoleMessage("console.tool.invalidApp"); return }
        configuration.customApplicationPath = url.path; configuration.customBundleIdentifier = identifier ?? ""
        message = ConsoleMessage("console.tool.selectedHelp")
    }
    @discardableResult private func exportSettings() -> Bool {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Chromecast-vRemoter-v1.plist"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do { try ChromecastSettingsArchive.exportData().write(to: url, options: .atomic); message = ConsoleMessage("console.backup.exported"); return true }
        catch { message = ConsoleMessage("backup.exportFailed"); return false }
    }
    private func importSettings() {
        guard !model.voiceActive else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedFileTypes = ["plist"]
        guard panel.runModal() == .OK, let url = panel.url, !model.voiceActive else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size < 1_000_000 else { throw ChromecastSettingsArchive.ArchiveError.invalid }
            let values = try ChromecastSettingsArchive.validate(Data(contentsOf: url))
            guard confirmReplacement(title: L10n.tr("console.backup.importConfirm"), detail: L10n.tr("console.backup.importDescription", url.lastPathComponent), action: L10n.tr("console.backup.importAction")), !model.voiceActive else { return }
            ChromecastSettingsArchive.restore(values); reloadConfiguration()
            message = ConsoleMessage("console.backup.imported")
        } catch {
            message = ConsoleMessage(error is ChromecastSettingsArchive.ArchiveError ? "backup.invalid" : "backup.readFailed")
        }
    }
    private func resetSettings() {
        guard confirmReplacement(title: L10n.tr("console.settings.resetConfirm"), detail: L10n.tr("console.settings.resetDescription"), action: L10n.tr("console.settings.resetAction")), !model.voiceActive else { return }
        ChromecastSettingsArchive.restore([:]); mappingStore.reset(.chromecast); reloadConfiguration()
        message = ConsoleMessage("console.settings.resetDone")
    }
    private func confirmResetMappings() {
        guard confirmReplacement(title: L10n.tr("console.mapping.resetConfirm"), detail: L10n.tr("console.mapping.resetDescription"), action: L10n.tr("console.mapping.resetAction")), !model.voiceActive else { return }
        mappingStore.reset(.chromecast); selectedGesture = nil; message = ConsoleMessage("console.mapping.resetDone")
    }
    /// Cancel is the default; export is optional and never authorizes replacement.
    private func confirmReplacement(title: String, detail: String, action: String) -> Bool {
        guard !model.voiceActive else { return false }
        while true {
            let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = title
            alert.informativeText = detail + L10n.tr("console.backup.exportFirstHelp")
            alert.addButton(withTitle: L10n.tr("console.common.cancel")); alert.addButton(withTitle: L10n.tr("console.backup.exportFirst")); alert.addButton(withTitle: action)
            switch alert.runModal() {
            case .alertSecondButtonReturn: guard exportSettings() else { return false }
            case .alertThirdButtonReturn: return !model.voiceActive
            default: return false
            }
        }
    }
    private func open(_ value: String) { if let url = URL(string: value) { NSWorkspace.shared.open(url) } }
}

private struct ChromecastVoiceKeyPhoto: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = ChromecastMappingPhoto.image {
                Image(nsImage: image).resizable().frame(width: 240, height: 360).offset(x: -45, y: -78)
                Circle().stroke(ConsoleDesignTokens.accent, lineWidth: 2).frame(width: 42, height: 42).position(x: 69, y: 52)
            } else { Text(L10n.tr("console.voiceKey.photoFallback")).font(.caption).padding(12) }
        }.frame(width: 160, height: 112, alignment: .topLeading).clipped().cornerRadius(12)
            .accessibilityLabel(L10n.tr("console.accessibility.voiceKeyPhoto"))
    }
}

private struct ChromecastGlobalVoiceHeader: View {
    @ObservedObject var model: ConsoleViewModel
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var showingDetail = false
    private var phase: VoiceSessionPresentation.Phase { model.voicePresentation.phase }
    private var title: String {
        switch phase { case .idle: return L10n.tr("console.voice.idle"); case .opening: return L10n.tr("console.voice.opening"); case .recording: return L10n.tr("console.voice.recording"); case .ending: return L10n.tr("console.voice.ending"); case .ended: return L10n.tr("console.voice.ended"); case .error: return L10n.tr("console.voice.error") }
    }
    private var symbol: String {
        switch phase { case .idle: return "mic"; case .opening: return "hourglass"; case .recording: return "waveform"; case .ending: return "stop.circle"; case .ended: return "checkmark.circle"; case .error: return "exclamationmark.circle" }
    }
    var body: some View {
        HStack(spacing: 10) {
            Button { showingDetail.toggle() } label: {
                HStack(spacing: 9) {
                    if phase == .recording { meter } else { Image(systemName: symbol).font(.system(size: 18)) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 12, weight: .semibold))
                        if phase == .recording || phase == .ending {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(duration(at: context.date)).font(.system(size: 10)).monospacedDigit()
                            }
                        } else { Text(phase == .ended ? L10n.tr("console.voice.checkTool") : L10n.tr("console.voice.showStatus")).font(.system(size: 10)) }
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L10n.tr("console.accessibility.voiceStatus") + title)
                .popover(isPresented: $showingDetail, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title).font(.headline)
                        Text(model.voicePresentation.detail.isEmpty ? L10n.tr("console.voice.pressRemote") : model.voicePresentation.detail)
                        Text(L10n.tr("console.voice.endHelp")).font(.caption)
                        if model.voiceActive { Button(L10n.tr("console.voice.stop")) { model.onStopMicrophone?() } }
                        Button(L10n.tr("console.common.close")) { showingDetail = false }
                    }.padding(18).frame(width: 320)
                }
            if model.voiceActive {
                Button { model.onStopMicrophone?() } label: { Image(systemName: "stop.fill").font(.system(size: 11)).padding(8) }
                    .buttonStyle(.plain).background(ConsoleDesignTokens.surface).cornerRadius(7).accessibilityLabel(L10n.tr("console.accessibility.stopVoice"))
            }
        }.padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundColor(phase == .error ? ConsoleDesignTokens.error : ConsoleDesignTokens.accentText)
            .background(phase == .error ? ConsoleDesignTokens.errorBackground : ConsoleDesignTokens.selection).cornerRadius(10)
    }
    private var meter: some View {
        let value = model.remoteLevelDB.isFinite ? max(0, min(1, (model.remoteLevelDB + 60) / 60)) : 0
        return HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Capsule().fill(ConsoleDesignTokens.accent).frame(width: 3, height: 4 + value * Double([10, 17, 24, 15, 8][index]))
            }
        }.frame(width: 24, height: 28).accessibilityLabel(L10n.tr("console.accessibility.audioLevel"))
    }
    private func duration(at date: Date) -> String {
        let seconds = Int(model.voicePresentation.elapsed(at: date))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ChromecastGestureEditor: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let button: RemoteButtonDefinition
    let gesture: RemoteButtonGesture
    @ObservedObject private var store = RemoteMappingStore.shared
    @State private var record = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(gesture.title, selection: Binding(get: { store.target(for: button, remote: .chromecast, gesture: gesture) }, set: { target in
                if target == .custom { record = true }
                else if target == .launchApplication { chooseApplication() }
                else { store.setTarget(target, for: button, remote: .chromecast, gesture: gesture) }
            })) {
                ForEach(RemoteMappingTarget.allCases.filter { $0 != .doubaoVoice }) { target in Text(target.title).tag(target) }
            }
            Text(store.targetTitle(for: button, remote: .chromecast, gesture: gesture)).font(.caption).foregroundColor(.secondary)
            if store.action(for: button, remote: .chromecast, gesture: gesture).isContinuous {
                Text(gesture == .longPress
                     ? L10n.tr("console.mapping.longScrollHelp")
                     : L10n.tr("console.mapping.clickScrollHelp"))
                    .font(.caption).foregroundColor(.secondary)
            }
            if let failure = store.lastActionError { Text(failure).font(.caption).foregroundColor(.orange) }
        }.sheet(isPresented: $record) {
            KeyboardShortcutCaptureView(buttonTitle: { button.title + " · " + gesture.title }, onCancel: { record = false }, onSave: {
                store.setCustomShortcut($0, for: button, remote: .chromecast, gesture: gesture); record = false
            })
        }
    }
    private func chooseApplication() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let app = RemoteApplicationShortcut(url: url) else { return }
        store.setApplication(app, for: button, remote: .chromecast, gesture: gesture)
    }
}

/// SF Symbols remain sharp at every display scale. Help is also available by
/// keyboard/click so essential guidance never depends on a pointer hovering.
private struct ChromecastHelpLabel: View {
    let title: String
    let explanation: String
    @State private var showingHelp = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title).fontWeight(.semibold)
            Button { showingHelp.toggle() } label: {
                Image(systemName: "info.circle").font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .help(explanation)
            .accessibilityLabel(title + L10n.tr("console.accessibility.helpSuffix"))
            .accessibilityHint(L10n.tr("console.accessibility.openHelp"))
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.headline)
                    Text(explanation).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.tr("console.common.gotIt")) { showingHelp = false }
                }.padding(18).frame(width: 340)
            }
        }
    }
}
