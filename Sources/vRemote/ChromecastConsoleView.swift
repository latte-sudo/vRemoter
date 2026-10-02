import AppKit
import SwiftUI

private enum ChromecastSettingsPage: Int, CaseIterable {
    case voice, remote, permissions, settings
    var title: String {
        switch self { case .voice: return "语音和音频"; case .remote: return "遥控器"; case .permissions: return "权限与诊断"; case .settings: return "设置" }
    }
    var symbol: String {
        switch self { case .voice: return "waveform"; case .remote: return "appletvremote.gen1"; case .permissions: return "checkmark.shield"; case .settings: return "gearshape" }
    }
    var subtitle: String {
        switch self {
        case .voice: return "从一次按键，到一句完整的话。"
        case .remote: return "认出手边的这一枚，随时查看连接。"
        case .permissions: return "权限是否开启，连接是否正常，一眼看清。"
        case .settings: return "管理外观、启动方式与配置备份。"
        }
    }
}

struct ChromecastConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
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
    @State private var message = ""
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
    @State private var permissionCheckResult = "尚未重新检查"
    @State private var permissionRequestResult = ""
    @FocusState private var speechFieldFocused: Bool
    @ObservedObject private var mappingStore = RemoteMappingStore.shared
    private let steps = ["选择语音工具", "连接遥控器", "检查必要权限", "设置说话方式", "试着说一句话", "按键配置", "准备就绪"]
    private var audio: AudioPipe { AudioPipe.shared }
    private var connected: Bool { model.hidConnected && model.bleConnected }
    private var toolTitle: String {
        configuration.inputTool == .doubao ? "豆包输入法" :
        (configuration.customApplicationPath.isEmpty ? "自定义语音工具" : URL(fileURLWithPath: configuration.customApplicationPath).deletingPathExtension().lastPathComponent)
    }
    private var voiceModeTitle: String { configuration.remoteVoiceMode == .hold ? "按住说话，松开停止" : "按一下开始，再按一下停止" }

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
                    if !message.isEmpty {
                        HStack(alignment: .top) {
                            Text(message).font(.system(size: 12)).textSelection(.enabled)
                            Spacer(minLength: 8)
                            Button { message = "" } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("关闭操作提示")
                        }.padding(14).background(ConsoleDesignTokens.secondarySurface)
                    }
                    if setup { onboardingFooter }
                }
            }.background(ConsoleDesignTokens.window).foregroundColor(ConsoleDesignTokens.text)
                .accentColor(ConsoleDesignTokens.accent)
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
                Text(setup ? "从这里开始" : "偏好设置").font(.system(size: 18, weight: .semibold))
                Text(setup ? "几步设置，让声音触手可及" : "让遥控器适合你的习惯")
                    .font(.system(size: 11)).foregroundColor(ConsoleDesignTokens.secondaryText)
            }.padding(.horizontal, 20).padding(.top, 45)
            if setup {
                VStack(spacing: 0) {
                    ForEach(steps.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            Button { step = index } label: {
                                HStack(spacing: 11) {
                                    ZStack {
                                        Circle().fill(index == step ? ConsoleDesignTokens.accent : ConsoleDesignTokens.surface)
                                        if index < step { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)) }
                                        else { Text("\(index + 1)").font(.system(size: 11, weight: .semibold)) }
                                    }.frame(width: 23, height: 23)
                                        .foregroundColor(index == step ? Color.white : ConsoleDesignTokens.accentText)
                                    Text(steps[index]).font(.system(size: 13, weight: index == step ? .semibold : .regular))
                                    Spacer(minLength: 0)
                                }.padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(index == step ? ConsoleDesignTokens.selection : Color.clear).cornerRadius(8)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(index > furthestStep)
                                .accessibilityLabel("第 \(index + 1) 步，共 7 步，\(steps[index])")
                                .accessibilityValue(index == step ? "当前步骤" : index < step ? "已访问" : "未完成")
                            if index < steps.count - 1 {
                                HStack { Rectangle().fill(index < step ? ConsoleDesignTokens.accent.opacity(0.45) : ConsoleDesignTokens.line)
                                    .frame(width: 1, height: 11).padding(.leading, 23); Spacer() }
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }.padding(.horizontal, 12)
            } else {
                VStack(spacing: 5) {
                    ForEach(ChromecastSettingsPage.allCases, id: \.self) { item in
                        Button { page = item } label: {
                            Label(item.title, systemImage: item.symbol).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .foregroundColor(page == item ? ConsoleDesignTokens.accentText : ConsoleDesignTokens.text)
                                .background(page == item ? ConsoleDesignTokens.selection : Color.clear).cornerRadius(8)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityValue(page == item ? "当前页面" : "")
                    }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 10) {
                Label(model.remoteDisplayName, systemImage: "appletvremote.gen1")
                    .font(.system(size: 12, weight: .medium)).lineLimit(2).help(model.remoteDisplayName)
                Label(connected ? "按键与语音均已连接" : "等待遥控器连接", systemImage: connected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11)).foregroundColor(connected ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
                Divider()
                HStack { Text("vRemoter"); Spacer(); Text("Chromecast") }.font(.system(size: 10)).foregroundColor(ConsoleDesignTokens.secondaryText)
            }.padding(20)
        }.frame(width: ConsoleDesignTokens.sidebarWidth).frame(maxHeight: .infinity)
            .background(ConsoleDesignTokens.sidebar)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("vRemoter").font(.system(size: 12, weight: .semibold))
            Text("/  \(setup ? "首次使用" : page.title)").font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText)
            Spacer()
            ChromecastGlobalVoiceHeader(model: model)
        }.padding(.horizontal, 24).padding(.top, 18).frame(height: 83)
    }

    @ViewBuilder private var onboardingContent: some View {
        switch step {
        case 0:
            pageHeading("01 / 先选好你的语音工具", "你准备在哪个工具里说话？", "vRemoter 传递遥控器的声音与按键，文字识别由你选择的语音工具完成。")
            HStack(alignment: .top, spacing: 28) {
                voiceToolSelection.frame(maxWidth: .infinity)
                remoteHero.frame(width: 240)
            }
        case 1:
            pageHeading("02 / 连接手边的遥控器", "让 Mac 发现它", "当前只支持 Chromecast 语音遥控器。按键与声音，都要连上。")
            connection
        case 2:
            pageHeading("03 / 只开启需要的权限", "每一项，都说明白", "完成授权后，再回来检查一次。权限与设备连接是两件事。")
            permissions
        case 3:
            pageHeading("04 / 两种设置，各有分工", "按你的习惯开始说话", "遥控器决定你怎么按，语音工具决定 vRemoter 怎么发送快捷键。")
            voiceSettings
        case 4:
            pageHeading("05 / 试着说一句", "说一句，看看文字", "")
            speechTest
        case 5:
            pageHeading("06 / 手边的每一枚按键", "配置常用按键", "点击真实遥控器画布中的按键或动作，就能编辑。也可以保留已有配置，直接继续。")
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
            Button("试着说一句话") { beginSetup(at: 4) }.disabled(model.voiceActive)
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
                Button("稍后继续") { deferSetup() }.disabled(model.voiceActive)
                Spacer()
                if step > 0 { Button("上一步") { step -= 1 } }
                Button(step == 6 ? "开始使用" : "下一步") { advanceSetup() }
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
        testArmed && model.receivedAudioPackets > testAudioBaseline && model.completedVoiceSessions > testSessionBaseline && !model.voiceActive && model.voicePresentation.phase == .ended && prerequisitesReady && !testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var canAdvance: Bool {
        switch step {
        case 0, 3: return configuration.isValid
        case 1: return connected
        case 2: return model.accessibilityGranted && model.inputMonitoringGranted && model.bluetoothGranted
        case 4, 6: return speechEvidence.canComplete && prerequisitesReady && model.voicePresentation.phase == .ended
        default: return true
        }
    }

    private var voiceToolSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                toolCard(.doubao, title: "豆包输入法", subtitle: "已支持的语音输入工具", symbol: "sparkles")
                toolCard(.custom, title: "其他工具", subtitle: "选择你自己的语音应用", symbol: "app")
            }
            if configuration.inputTool == .custom {
                ConsoleCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(toolTitle).font(.headline).lineLimit(2)
                            Spacer()
                            Button("选择应用…") { chooseVoiceApplication() }
                        }
                        if !configuration.customApplicationPath.isEmpty {
                            Button("清除选择") { configuration.customApplicationPath = ""; configuration.customBundleIdentifier = "" }
                        }
                        DisclosureGroup("高级：应用标识") {
                            TextField("应用 Bundle ID", text: $configuration.customBundleIdentifier).textFieldStyle(.roundedBorder)
                                .padding(.top, 8)
                        }
                        Text("兼容性需要实际测试。vRemoter 不执行语音识别，也不自动修改该工具设置。")
                            .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    }
                }
            }
            Button(launchingVoiceApplication ? "正在打开…" : "打开\(toolTitle)") { launchVoiceTool() }
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
        }.buttonStyle(.plain).accessibilityValue(configuration.inputTool == tool ? "已选择" : "未选择")
    }
    private var remoteHero: some View {
        VStack(spacing: 16) {
            if let image = ChromecastMappingPhoto.image { Image(nsImage: image).resizable().scaledToFit().frame(height: 290).cornerRadius(14).accessibilityLabel("Chromecast 语音遥控器正面与侧面") }
            Text("下一句话，从手边开始").font(.system(size: 13, weight: .medium))
        }.padding(20).frame(maxWidth: .infinity).background(ConsoleDesignTokens.hero).cornerRadius(17)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Label("1  打开 Mac 的蓝牙设置，在系统设置中完成配对", systemImage: "dot.radiowaves.left.and.right")
                    Label("2  同时按住返回键和主页键，等待指示灯闪烁", systemImage: "hand.tap")
                    Label("3  选择 Chromecast 遥控器，再回来确认两个通道", systemImage: "checkmark.circle")
                    HStack {
                        Button("打开蓝牙设置") { open("x-apple.systempreferences:com.apple.Bluetooth") }
                        Button("重新连接") { model.onReconnectInputs?() }.disabled(model.voiceActive)
                    }
                }.font(.system(size: 13))
            }
            ConsoleCard { connectionStatus }
            ConsoleNotice(text: "若蓝牙访问尚未授权，请在下一步申请；也可在这里先申请，再完成连接。")
            if !model.bluetoothGranted { permissionRow("蓝牙", detail: "连接遥控器的语音服务", granted: false, status: model.bluetoothPermissionStatus, kind: .bluetooth) }
            if !permissionRequestResult.isEmpty { Text(permissionRequestResult).font(.caption).textSelection(.enabled) }
        }
    }
    private var connectionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.remoteDisplayName).font(.system(size: 15, weight: .semibold)).lineLimit(2).help(model.remoteDisplayName)
            HStack(spacing: 28) {
                statusLabel("按键通道", connected: model.hidConnected)
                statusLabel("语音通道", connected: model.bleConnected)
            }
        }
    }
    private func statusLabel(_ title: String, connected: Bool) -> some View {
        Label(title + (connected ? "已连接" : "未连接"), systemImage: connected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 12)).foregroundColor(connected ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionRow("蓝牙", detail: "接收遥控器的语音数据", granted: model.bluetoothGranted, status: model.bluetoothPermissionStatus, kind: .bluetooth)
            permissionRow("辅助功能", detail: "向语音工具发送录音快捷键", granted: model.accessibilityGranted, status: model.accessibilityPermissionStatus, kind: .accessibility)
            permissionRow("输入监控", detail: "接收遥控器按键与触发键", granted: model.inputMonitoringGranted, status: model.inputMonitoringPermissionStatus, kind: .inputMonitoring)
            HStack {
                Text(permissionCheckResult).font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                Spacer()
                Button("重新检查权限") { checkPermissions() }
            }
            if !permissionRequestResult.isEmpty { Text(permissionRequestResult).font(.caption).textSelection(.enabled) }
            if let checked = model.permissionCheckedAt { Text("上次检查：\(checked.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
            ConsoleNotice(text: "只使用遥控器声音，不采集 Mac 麦克风。语音工具的麦克风授权、虚拟音频设备安装，需要在本机单独完成。")
            Text("若列表中没有 App，可在支持“＋”的设置页面添加打包后的 vRemote.app。请从固定位置运行；系统要求重启时，请退出并重新打开。")
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, status: String, kind: PermissionKind) -> some View {
        ConsoleCard {
            HStack(spacing: 16) {
                Image(systemName: granted ? "checkmark.shield.fill" : "shield").font(.system(size: 22)).foregroundColor(granted ? ConsoleDesignTokens.success : ConsoleDesignTokens.accent)
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText) }
                Spacer(minLength: 8)
                Text(status).font(.system(size: 12)).foregroundColor(granted ? ConsoleDesignTokens.success : ConsoleDesignTokens.secondaryText)
                if !granted { Button("请求权限") { permissionRequestResult = model.requestPermission(for: kind) }.disabled(model.voiceActive) }
                Button("打开设置") { model.openSettings(for: kind) }
            }.accessibilityElement(children: .contain)
        }
    }

    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            ChromecastHelpLabel(title: "手里的遥控器怎么按", explanation: "这是实体语音键的操作方式，与电脑上语音工具的录音模式独立，可以任意组合。")
            HStack(spacing: 12) {
                voiceModeCard(.toggle, title: "按一下开始，再按一下停止", subtitle: "放开手，也可以继续说话", symbol: "hand.tap")
                voiceModeCard(.hold, title: "按住说话，松开停止", subtitle: "从按下到松开，就是一句话", symbol: "hand.point.up.left")
            }
            ChromecastHelpLabel(title: "\(toolTitle)怎么开始录音", explanation: "先打开语音工具设置，查看它的录音模式和快捷键，再在这里选择相同设置。这里不会修改语音工具。")
            ConsoleCard {
                VStack(spacing: 18) {
                    Picker("工具内的录音模式", selection: $configuration.inputToolTriggerMode) {
                        Text("按一下切换开始 / 停止").tag(InputToolTriggerMode.toggle)
                        Text("按住快捷键录音").tag(InputToolTriggerMode.hold)
                    }
                    Divider()
                    Picker("录音快捷键", selection: $configuration.triggerKey) { ForEach(InputTriggerKey.allCases) { Text($0.title).tag($0) } }
                }
            }
            HStack { Text("请与语音工具内的设置保持一致").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText); Spacer(); Button("打开\(toolTitle)") { launchVoiceTool() }.disabled(launchingVoiceApplication) }
            ConsoleNotice(text: "两种模式可以不同。例如遥控器按一下开始，工具按住录音：vRemoter 负责转换。工具的模式和快捷键仍须两边匹配。")
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
        }.buttonStyle(.plain).accessibilityValue(configuration.remoteVoiceMode == mode ? "已选择" : "未选择")
    }

    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音频通道").font(.system(size: 14, weight: .semibold))
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(model.remoteDisplayName) → 虚拟音频设备 → \(toolTitle)").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Picker("输出到虚拟音频设备", selection: Binding(get: { audio.selectedOutputUID ?? "" }, set: {
                        _ = audio.selectOutputRoute(uid: $0.isEmpty ? nil : $0); invalidateTest(); routeRevision += 1
                    })) {
                        Text("关闭输出 / 未选择").tag("")
                        ForEach(audio.outputRoutes, id: \.uid) { route in Text(route.name).tag(route.uid) }
                    }.id(routeRevision).disabled(model.voiceActive)
                    Text("请在语音工具中选择同一个麦克风设备。不会自动修改系统默认麦克风。").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Divider()
                    HStack {
                        ChromecastHelpLabel(title: "遥控器麦克风增益", explanation: "只改变遥控器音量，不改变识别算法。范围 0–20 倍，默认 10 倍；过高可能失真。")
                        Spacer(); Text(String(format: "%.1f×", audio.remoteGain)).monospacedDigit()
                    }
                    Slider(value: Binding(get: { Double(audio.remoteGain) }, set: { audio.setRemoteGain(Float($0)); routeRevision += 1 }), in: 0...20)
                        .accessibilityLabel("遥控器麦克风增益").disabled(model.voiceActive)
                    HStack {
                        Button("刷新设备") { audio.refreshOutputRoutes(); routeRevision += 1 }
                        Spacer()
                        Button("可选：测试音诊断") { message = audio.playTestTone() ? "测试音已发送，请在语音工具中观察输入电平。测试音不能证明识别成功。" : "测试音未发送，请检查虚拟设备。" }.disabled(model.voiceActive || !audio.isOutputDeviceAvailable)
                    }
                }
            }
            if !audio.isOutputDeviceAvailable { ConsoleNotice(text: "尚无可用虚拟设备。请按项目安装说明安装 vRemoteDr 2ch 或兼容设备，再刷新；不会自动安装或重启音频服务。", isError: true) }
        }
    }

    private var speechTest: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 22) {
                ChromecastVoiceKeyPhoto()
                VStack(alignment: .leading, spacing: 8) {
                    Text("找到这枚黑色语音键").font(.system(size: 15, weight: .semibold))
                    Text("带白色圆点图案，在返回键右侧。").font(.system(size: 12)).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Text(voiceModeTitle).font(.system(size: 13, weight: .medium)).foregroundColor(ConsoleDesignTokens.accentText)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("试着说「你好，今天也从一句话开始」").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button("打开\(toolTitle)") { launchVoiceTool() }.disabled(model.voiceActive || launchingVoiceApplication)
                }
                TextEditor(text: $testText).focused($speechFieldFocused).font(.system(size: 16))
                    .frame(minHeight: 120, maxHeight: 160).padding(10)
                    .background(ConsoleDesignTokens.surface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ConsoleDesignTokens.line))
                    .accessibilityLabel("语音试用输入框")
                Text(testArmed ? "光标放在这里，用实体语音键说话，然后结束。文字由所选语音工具输入。" : "先打开语音工具，再准备本次测试。这里不会自动生成文字。")
                    .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
            }
            HStack(spacing: 12) {
                if model.voiceActive {
                    Button("停止本次说话") { model.onStopMicrophone?() }.buttonStyle(ConsolePrimaryButtonStyle())
                } else if canConfirmSpeech {
                    Button(confirmedSpeech ? "已确认，可以继续" : "我确认文字来自刚才的语音识别") { confirmedSpeech = true }
                        .buttonStyle(ConsolePrimaryButtonStyle()).disabled(confirmedSpeech)
                    Button("再试一次") { armSpeechTest() }
                } else {
                    Button(testArmed ? "重新准备本次测试" : "准备好了，开始测试") { armSpeechTest() }
                        .buttonStyle(ConsolePrimaryButtonStyle()).disabled(!prerequisitesReady)
                    if testArmed { Text("已准备，请按实体语音键").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
                }
            }
            if !audio.isOutputDeviceAvailable { ConsoleNotice(text: "先展开“没有输入成功？”选择虚拟音频设备；语音工具也要选择同一设备。", isError: true) }
            DisclosureGroup("没有输入成功？", isExpanded: $troubleshooting) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("1. 打开语音工具，把光标放到上方输入框\n2. 核对两边的录音模式与快捷键\n3. 选择同一个虚拟麦克风，结束说话后再确认文字").font(.system(size: 12))
                    audioSettings
                    ProgressView(value: normalizedLevel).accessibilityLabel("真实遥控器输入电平")
                    Text(String(format: "实时输入 %.1f dB", model.remoteLevelDB)).font(.caption)
                    Label(testArmed && model.receivedAudioPackets > testAudioBaseline ? "本次已收到真实音频数据" : "等待本次真实音频数据", systemImage: "waveform")
                    Label(testArmed && model.completedVoiceSessions > testSessionBaseline ? "本次会话已结束" : "等待结束本次说话", systemImage: "stop.circle")
                    Text(audio.routeDiagnostics).font(.caption).textSelection(.enabled)
                    HStack {
                        Button("检查权限") { checkPermissions() }
                        Button("核对说话方式") { step = 3 }
                    }
                    Text(permissionCheckResult).font(.caption)
                }.padding(.top, 14)
            }.font(.system(size: 12))
            Text("应用只检查真实音频数据和会话结束；识别结果由你确认。手动输入、粘贴或测试音都不能证明识别成功。")
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private var normalizedLevel: Double { model.remoteLevelDB.isFinite ? max(0, min(1, (model.remoteLevelDB + 60) / 60)) : 0 }

    private var completion: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: speechEvidence.canComplete ? "checkmark.circle.fill" : "exclamationmark.circle").font(.system(size: 46))
                .foregroundColor(speechEvidence.canComplete ? ConsoleDesignTokens.success : ConsoleDesignTokens.error)
            pageHeading("07 / 设置完成", speechEvidence.canComplete ? "下一句话，从手边开始" : "请再确认一次实际说话", "识别结果由你确认。以后可以随时在设置中调整或重新测试。")
            ConsoleCard {
                VStack(spacing: 18) {
                    summaryRow("使用的遥控器", model.remoteDisplayName)
                    Divider(); summaryRow("语音工具", toolTitle)
                    Divider(); summaryRow("遥控器语音键", voiceModeTitle)
                    Divider(); summaryRow("工具录音快捷键", configuration.triggerKey.title + " · " + (configuration.inputToolTriggerMode == .hold ? "按住录音" : "按一下切换"))
                }
            }
            if !canAdvance { Button("返回实际说话测试") { step = 4 } }
            Text("普通按键配置已保存，可在“遥控器”页面继续调整。").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
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
                            Text("显示名称").font(.system(size: 12))
                            TextField(RemoteDisplayName.defaultName, text: $remoteNameDraft).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("应用内遥控器名称").onSubmit { saveRemoteName() }
                            Button("保存") { saveRemoteName() }.disabled(!remoteNameValidationMessage.isEmpty)
                        }.disabled(model.voiceActive)
                    }
                }
                if !remoteNameValidationMessage.isEmpty { Text(remoteNameValidationMessage).font(.caption).foregroundColor(ConsoleDesignTokens.error) }
                Divider()
                HStack {
                    Text("名称仅用于 vRemoter，不修改系统蓝牙名称或绑定实体设备。").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    Spacer()
                    Button("蓝牙设置") { open("x-apple.systempreferences:com.apple.Bluetooth") }
                    Button("重新连接") { model.onReconnectInputs?() }.disabled(model.voiceActive)
                }
            }
        }
    }
    private var mapping: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("按键映射").font(.title2).bold()
                Toggle("自定义按键", isOn: Binding(get: { mappingStore.isEnabled(.chromecast) }, set: { model.setRemoteMappingEnabled($0, remote: .chromecast) }))
                    .toggleStyle(.switch)
                Spacer()
            }
            Text("遥控器：\(model.remoteDisplayName)").font(.callout)
                .lineLimit(2).help(model.remoteDisplayName)
            Divider()
            ChromecastMappingCanvas(selectedButton: selectedButton, selectedGesture: selectedGesture,
                observedButton: model.lastButtonID, voiceActive: model.voiceActive,
                voiceModeTitle: configuration.remoteVoiceMode == .hold ? "按住说话，松开停止" : "按一下开始，再按一下停止",
                onSelect: { selectedButton = $0; selectedGesture = nil },
                onEdit: { button, gesture in
                    selectedButton = button; selectedGesture = gesture; editorRevision += 1
                },
                onVoiceSettings: { if setup { step = 3 } else { page = .voice } })
            Text("点击单击、双击或长按格子，在下方编辑当前动作；点击照片中的按键定位。绿色表示最近收到的按键报告。")
                .font(.caption).foregroundColor(.secondary)
            if let gesture = selectedGesture,
               let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == selectedButton && !$0.voiceControlled }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("编辑：\(button.title) · \(gesture.title)").font(.headline)
                        Spacer()
                        Button("关闭编辑") { selectedGesture = nil }
                    }
                    ChromecastGestureEditor(button: button, gesture: gesture)
                        .id(button.id + gesture.rawValue)
                    Toggle("单击动作按住连发", isOn: Binding(get: {
                        mappingStore.holdRepeats(for: button, remote: .chromecast)
                    }, set: {
                        mappingStore.setHoldRepeats($0, for: button, remote: .chromecast)
                    }))
                    Text("双击或长按动作存在时，单击连发会暂停。长按滚动会在 0.55 秒后持续，松开立即停止；可选上、下、左、右。切换应用每次手势只执行一次。").font(.caption)
                }.padding(16).background(Color.accentColor.opacity(0.08)).cornerRadius(12)
                    .id("chromecast-inline-editor")
            }
            Text("音量 / 电源 / 信源若设成红外控制，Mac 可能收不到报告。请在 Chromecast 的遥控器设置中检查控制方式。").font(.caption)
            Button("恢复 Chromecast 默认按键") { confirmResetMappings() }
            Text("修改后自动保存；已有配置会被覆盖，可先在设置页导出备份。").font(.caption)
        }.disabled(model.voiceActive)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("外观").font(.headline)
            ConsoleCard {
                HStack {
                    VStack(alignment: .leading, spacing: 5) { Text("外观主题").fontWeight(.medium); Text("立即生效，或跟随系统自动切换").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }
                    Spacer(); ConsoleAppearancePicker(selection: $appearance)
                }
            }
            Text("启动与显示").font(.headline)
            ConsoleCard {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("登录 Mac 后自动启动", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { enabled in
                        do { try LaunchAtLogin.setEnabled(enabled) } catch { message = error.localizedDescription }
                        routeRevision += 1
                    })).toggleStyle(.switch).id(routeRevision)
                    Divider()
                    Toggle("在程序坞中显示 vRemoter", isOn: Binding(get: { DockVisibilityPreference.isVisible() }, set: { visible in
                        if DockVisibilityController.apply(visible) { DockVisibilityPreference.setVisible(visible); routeRevision += 1 }
                        else { message = "无法更改程序坞显示，请稍后重试。" }
                    })).toggleStyle(.switch).id(routeRevision)
                    Text("隐藏后仍可从菜单栏打开主窗口。关闭窗口不会退出应用。").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                }
            }
            Text("配置备份").font(.headline)
            ConsoleCard {
                VStack(spacing: 18) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("导出配置").fontWeight(.medium); Text("保存外观、语音方式、显示名称和按键映射").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button("导出…") { _ = exportSettings() } }
                    Divider()
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("导入配置").fontWeight(.medium); Text("验证 Chromecast v1 配置后，请你确认覆盖").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button("导入…") { importSettings() } }
                }
            }.disabled(model.voiceActive)
            ConsoleNotice(text: "不包含权限、配对记录、录音、日志或登录项。HTML 原型的 JSON 与原生 Chromecast v1 配置不能互相导入。")
            Text("恢复与重来").font(.headline)
            ConsoleCard {
                VStack(spacing: 18) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("恢复默认设置").fontWeight(.medium); Text("覆盖应用偏好和 Chromecast 按键；可先导出备份").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button("恢复默认…") { resetSettings() }.foregroundColor(ConsoleDesignTokens.error) }
                    Divider()
                    HStack { VStack(alignment: .leading, spacing: 5) { Text("重新进行首次引导").fontWeight(.medium); Text("保留现有配置，重新检查与实际说话").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText) }; Spacer(); Button("重新开始") { beginSetup() } }
                    if UserDefaults.standard.bool(forKey: "chromecast.onboarding.inProgress") {
                        Divider()
                        HStack { Text("继续尚未完成的引导"); Spacer(); Button("继续引导") { setup = true } }
                        HStack { Text("放弃本次引导并恢复开始前配置").font(.caption); Spacer(); Button("恢复原配置…") { cancelSetup() } }
                    }
                }
            }.disabled(model.voiceActive)
            Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development") · 配置格式 v1")
                .font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
        }
    }
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("连接与会话").font(.headline)
            ConsoleCard {
                VStack(alignment: .leading, spacing: 14) {
                    connectionStatus
                    Divider()
                    Text(model.voicePresentation.detail.isEmpty ? model.status : model.voicePresentation.detail)
                    Text("真实音频数据：\(model.receivedAudioPackets) 次 · 本地完成会话：\(model.completedVoiceSessions) 次").font(.caption)
                    Text(audio.routeDiagnostics).font(.caption).textSelection(.enabled)
                    Text("本地会话结束不等于外部工具完成识别；请查看工具的录音状态与文字。").font(.caption).foregroundColor(ConsoleDesignTokens.secondaryText)
                    HStack {
                        Button("重新连接遥控器") { model.onReconnectInputs?() }.disabled(model.voiceActive)
                        Button("停止音频并重新检查") { model.onStopMicrophone?(); checkPermissions(); audio.refreshOutputRoutes(); routeRevision += 1 }
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
        guard confirmReplacement(title: "恢复引导前的配置？", detail: "本次引导中修改的语音、外观、名称和按键配置会被覆盖。系统权限、配对与登录项不变。", action: "恢复原配置"), !model.voiceActive else { return }
        ChromecastSettingsArchive.restore(backup); reloadConfiguration()
        UserDefaults.standard.removeObject(forKey: "chromecast.onboarding.backup")
        UserDefaults.standard.set(false, forKey: "chromecast.onboarding.inProgress")
        setup = false; step = 0; furthestStep = 0; message = "已恢复引导开始前的配置。"
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
        let missing = [("蓝牙", model.bluetoothGranted), ("辅助功能", model.accessibilityGranted), ("输入监控", model.inputMonitoringGranted)].filter { !$0.1 }.map { $0.0 }
        permissionCheckResult = missing.isEmpty ? "所需权限均已授权" : "仍需开启" + missing.joined(separator: "、") + "；若系统要求重启，请退出并重新打开。"
        if !missing.isEmpty { invalidateTest() }
    }
    private var remoteNameValidationMessage: String {
        do { _ = try RemoteDisplayName.normalizedAlias(remoteNameDraft); return "" }
        catch RemoteDisplayName.ValidationError.tooLong { return "名称最多 \(RemoteDisplayName.maximumLength) 个字符，请缩短后保存。" }
        catch { return "名称不能包含换行、控制字符或文字方向控制符。" }
    }
    private func saveRemoteName() {
        guard !model.voiceActive else { return }
        do { try RemoteDisplayName.set(remoteNameDraft); remoteNameDraft = RemoteDisplayName.alias(); model.refreshRemoteDisplayName(); message = "遥控器名称已保存。留空保存可恢复默认名称。" }
        catch { message = remoteNameValidationMessage }
    }
    private func launchVoiceTool() {
        guard !model.voiceActive, !launchingVoiceApplication else { return }
        launchingVoiceApplication = true
        VoiceApplicationLauncher().launch(configuration: configuration) { result in
            DispatchQueue.main.async {
                launchingVoiceApplication = false
                switch result { case .success(let success): message = success.message; case .failure(let error): message = error.localizedDescription }
            }
        }
    }
    private func chooseVoiceApplication() {
        let panel = NSOpenPanel(); panel.title = "选择你使用的语音应用"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, !model.voiceActive else { return }
        let identifier = Bundle(url: url)?.bundleIdentifier
        guard VoiceApplicationLaunchEnvironment.workspace.isValidApplication(url, identifier) else { message = "所选文件不是可运行的应用，请选择已安装的 .app。"; return }
        configuration.customApplicationPath = url.path; configuration.customBundleIdentifier = identifier ?? ""
        message = "已选择应用，请核对录音快捷键与虚拟麦克风。"
    }
    @discardableResult private func exportSettings() -> Bool {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Chromecast-vRemoter-v1.plist"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do { try ChromecastSettingsArchive.exportData().write(to: url, options: .atomic); message = "配置已导出。"; return true }
        catch { message = error.localizedDescription; return false }
    }
    private func importSettings() {
        guard !model.voiceActive else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedFileTypes = ["plist"]
        guard panel.runModal() == .OK, let url = panel.url, !model.voiceActive else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size < 1_000_000 else { throw ChromecastSettingsArchive.ArchiveError.invalid }
            let values = try ChromecastSettingsArchive.validate(Data(contentsOf: url))
            guard confirmReplacement(title: "导入这份配置？", detail: "\(url.lastPathComponent) 将替换当前应用偏好与 Chromecast 按键配置。不包含系统权限、配对、录音、日志或登录项。", action: "导入配置"), !model.voiceActive else { return }
            ChromecastSettingsArchive.restore(values); reloadConfiguration()
            message = "配置已导入。请重新检查虚拟设备并实际说话测试。"
        } catch { message = error.localizedDescription }
    }
    private func resetSettings() {
        guard confirmReplacement(title: "恢复默认设置？", detail: "将覆盖应用外观、程序坞偏好、语音配置、遥控器名称与 Chromecast 按键。系统权限、配对与登录项不会改变。", action: "恢复默认"), !model.voiceActive else { return }
        ChromecastSettingsArchive.restore([:]); mappingStore.reset(.chromecast); reloadConfiguration()
        message = "已恢复默认设置。请重新检查音频通道和说话方式。"
    }
    private func confirmResetMappings() {
        guard confirmReplacement(title: "恢复 Chromecast 默认按键？", detail: "当前单击、双击、长按与连发配置会被覆盖。", action: "恢复默认按键"), !model.voiceActive else { return }
        mappingStore.reset(.chromecast); selectedGesture = nil; message = "已恢复 Chromecast 默认按键。"
    }
    /// Cancel is the default; export is optional and never authorizes replacement.
    private func confirmReplacement(title: String, detail: String, action: String) -> Bool {
        guard !model.voiceActive else { return false }
        while true {
            let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = title
            alert.informativeText = detail + "\n如需保留现有设置，请先导出备份。"
            alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "先导出备份…"); alert.addButton(withTitle: action)
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
            } else { Text("黑色语音键\n位于返回键右侧").font(.caption).padding(12) }
        }.frame(width: 160, height: 112).clipped().cornerRadius(12)
            .accessibilityLabel("遥控器实图：返回键右侧的黑色圆形按键是语音键")
    }
}

private struct ChromecastGlobalVoiceHeader: View {
    @ObservedObject var model: ConsoleViewModel
    @State private var showingDetail = false
    private var phase: VoiceSessionPresentation.Phase { model.voicePresentation.phase }
    private var title: String {
        switch phase { case .idle: return "语音待机"; case .opening: return "正在准备"; case .recording: return "正在说话"; case .ending: return "正在结束"; case .ended: return "已结束说话"; case .error: return "语音异常" }
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
                        } else { Text(phase == .ended ? "识别结果请查看语音工具" : "查看状态").font(.system(size: 10)) }
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("全局语音状态：" + title)
                .popover(isPresented: $showingDetail, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title).font(.headline)
                        Text(model.voicePresentation.detail.isEmpty ? "按实体遥控器语音键开始。" : model.voicePresentation.detail)
                        Text("会话结束仅表示本地音频已结束；文字识别与输入结果需要在语音工具中确认。").font(.caption)
                        if model.voiceActive { Button("停止说话") { model.onStopMicrophone?() } }
                        Button("关闭") { showingDetail = false }
                    }.padding(18).frame(width: 320)
                }
            if model.voiceActive {
                Button { model.onStopMicrophone?() } label: { Image(systemName: "stop.fill").font(.system(size: 11)).padding(8) }
                    .buttonStyle(.plain).background(ConsoleDesignTokens.surface).cornerRadius(7).accessibilityLabel("停止当前说话")
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
        }.frame(width: 24, height: 28).accessibilityLabel("真实遥控器输入电平")
    }
    private func duration(at date: Date) -> String {
        let seconds = Int(model.voicePresentation.elapsed(at: date))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ChromecastGestureEditor: View {
    let button: RemoteButtonDefinition
    let gesture: RemoteButtonGesture
    @ObservedObject private var store = RemoteMappingStore.shared
    @State private var record = false
    @State private var errorText = ""
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
                     ? "长按超过 0.55 秒后持续滚动，松开立即停止，不受单击连发开关影响。"
                     : "无额外手势时，单击映射按住可持续滚动，不受单击连发开关影响；配置双击或长按后，单击和双击各滚动一步。")
                    .font(.caption).foregroundColor(.secondary)
            }
            if let failure = store.lastActionError { Text(failure).font(.caption).foregroundColor(.orange) }
            if !errorText.isEmpty { Text(errorText).font(.caption).foregroundColor(.orange) }
        }.sheet(isPresented: $record) {
            KeyboardShortcutCaptureView(buttonTitle: button.title + " · " + gesture.title, onCancel: { record = false }, onSave: {
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
            .accessibilityLabel(title + "，查看说明")
            .accessibilityHint("打开说明弹出窗口")
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.headline)
                    Text(explanation).fixedSize(horizontal: false, vertical: true)
                    Button("知道了") { showingHelp = false }
                }.padding(18).frame(width: 340)
            }
        }
    }
}
