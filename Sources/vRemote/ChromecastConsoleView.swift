import AppKit
import SwiftUI

struct ChromecastConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
    @State private var page = 0
    @State private var setup = UserDefaults.standard.bool(forKey: "chromecast.onboarding.inProgress") || !UserDefaults.standard.bool(forKey: "chromecast.onboarding.completed")
    @State private var step = max(0, min(7, UserDefaults.standard.integer(forKey: "chromecast.onboarding.step")))
    @State private var backup: [String: Any] = [:]
    @State private var configuration = AppStorage.voiceConfiguration
    @State private var routeRevision = 0
    @State private var routeFingerprint = ""
    @State private var message = ""
    @State private var launchingVoiceApplication = false
    @State private var testText = ""
    @State private var testAudioBaseline = 0
    @State private var testSessionBaseline = 0
    @State private var testArmed = false
    @State private var confirmedSpeech = false
    @State private var selectedButton = "03"
    @State private var selectedGesture: RemoteButtonGesture?
    @State private var editorRevision = 0
    @State private var permissionCheckResult = "尚未重新检查"
    @ObservedObject private var mappingStore = RemoteMappingStore.shared
    private let steps = ["欢迎", "连接遥控器", "权限", "音频通道", "语音工具", "实际说话测试", "普通按键", "完成"]
    private var audio: AudioPipe { AudioPipe.shared }

    var body: some View {
        ScrollViewReader { scroll in
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading) {
                    Text("vRemoter · Chromecast").font(.title2).bold()
                    Text(model.status).foregroundColor(.secondary)
                }
                Spacer()
                if model.voiceActive { Button("停止说话") { model.onStopMicrophone?() } }
                if !setup { Button("重新引导") { beginSetup() } }
            }
            Divider()
            if setup { onboarding } else {
                Picker("功能", selection: $page) {
                    Text("连接与语音").tag(0); Text("按键配置").tag(1); Text("设置与诊断").tag(2)
                }.pickerStyle(.segmented)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if page == 0 { connection; audioSettings; voiceSettings }
                        else if page == 1 { mapping }
                        else { settings }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            if !message.isEmpty { Text(message).font(.callout).foregroundColor(.orange).textSelection(.enabled) }
            Spacer(minLength: 0)
        }
        .padding(24)
        .sheet(item: $model.activeModal) { modal in
            ConsoleModalContent(model: model, modal: modal)
        }
        .onAppear {
            if setup { UserDefaults.standard.set(true, forKey: "chromecast.onboarding.inProgress") }
            if setup, let data = UserDefaults.standard.data(forKey: "chromecast.onboarding.backup"),
               let saved = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                backup = saved
            } else {
                backup = ChromecastSettingsArchive.snapshot()
                saveSetupBackup()
            }
            routeFingerprint = currentRouteFingerprint
            audio.onConfigurationChanged = {
                if !audio.isOutputDeviceAvailable && model.voiceActive { model.onStopMicrophone?() }
                let fingerprint = currentRouteFingerprint
                if fingerprint != routeFingerprint { invalidateTest(); routeFingerprint = fingerprint }
                routeRevision += 1
            }
            audio.refreshOutputRoutes()
        }
        .onChange(of: configuration) { _ in
            guard !model.voiceActive else { return }
            AppStorage.voiceConfiguration = configuration
            AppStorage.inputTriggerKey = configuration.triggerKey
            model.inputTriggerKey = configuration.triggerKey
            model.onVoiceConfigurationChanged?()
            invalidateTest()
        }
        .onChange(of: step) { value in UserDefaults.standard.set(value, forKey: "chromecast.onboarding.step") }
        .onChange(of: model.bleConnected) { connected in if !connected { invalidateTest() } }
        .onChange(of: editorRevision) { _ in
            DispatchQueue.main.async {
                withAnimation { scroll.scrollTo("chromecast-inline-editor", anchor: .bottom) }
            }
        }
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("首次使用 · \(step + 1) / \(steps.count) · \(steps[min(step, steps.count - 1)])").font(.headline)
            ProgressView(value: Double(step), total: 7)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case 0:
                        Text("把 Chromecast 遥控器变成无线麦克风和快捷键遥控器").font(.title2)
                        Text("引导会检查连接与权限，选择音频通道和语音工具，最后请你实际说一句话。仅连接成功或听到测试音，不代表语音识别已经成功。")
                    case 1:
                        connection
                        permissions
                    case 2: permissions
                    case 3: audioSettings
                    case 4: voiceSettings
                    case 5: speechTest
                    case 6: mapping
                    default:
                        Text(canAdvance ? "测试通过，可以完成设置" : "测试已失效，请返回实际说话测试").font(.title2)
                        Text("已检查真实音频数据和会话结束；识别结果由你在本次测试中确认。以后可以随时重新引导、重新测试或恢复配置。")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("取消并恢复原配置") {
                    model.onStopMicrophone?(); ChromecastSettingsArchive.restore(backup)
                    reloadConfiguration(); setup = false; step = 0
                    UserDefaults.standard.removeObject(forKey: "chromecast.onboarding.backup")
                    UserDefaults.standard.set(false, forKey: "chromecast.onboarding.inProgress")
                    UserDefaults.standard.set(0, forKey: "chromecast.onboarding.step")
                }
                Spacer()
                if step > 0 { Button("上一步") { step -= 1 } }
                Button(step == 7 ? "开始使用" : "下一步") {
                    if step == 7 {
                        UserDefaults.standard.set(true, forKey: "chromecast.onboarding.completed")
                        setup = false; step = 0
                    UserDefaults.standard.removeObject(forKey: "chromecast.onboarding.backup")
                    UserDefaults.standard.set(false, forKey: "chromecast.onboarding.inProgress")
                    } else { step += 1 }
                }.disabled(!canAdvance)
            }.disabled(model.voiceActive)
        }
    }
    private var canAdvance: Bool {
        switch step {
        case 1: return model.bleConnected && model.hidConnected
        case 2: return model.accessibilityGranted && model.inputMonitoringGranted && model.bluetoothGranted
        case 3: return audio.isOutputDeviceAvailable
        case 4: return configuration.isValid
        case 5, 7: return OnboardingSpeechEvidence(armed: testArmed,
            receivedAudioPackets: model.receivedAudioPackets, baselineAudioPackets: testAudioBaseline,
            endedSessions: model.completedVoiceSessions, baselineEndedSessions: testSessionBaseline,
            voiceActive: model.voiceActive, routeAvailable: audio.isOutputDeviceAvailable,
            remoteConnected: model.bleConnected, text: testText, userConfirmedRecognition: confirmedSpeech).canComplete
        default: return true
        }
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chromecast Voice Remote").font(.headline)
            Text("在系统蓝牙设置里配对遥控器。连接后会自动接入语音服务；断开连接会停止本次说话并释放快捷键。")
            Label(model.hidConnected ? "按键通道已连接" : "等待按键通道", systemImage: model.hidConnected ? "checkmark.circle" : "circle")
            Label(model.bleConnected ? "语音通道已连接" : "等待语音通道", systemImage: model.bleConnected ? "checkmark.circle" : "circle")
            Button("打开蓝牙设置") { open("x-apple.systempreferences:com.apple.Bluetooth") }
        }
    }
    private var permissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("需要的权限").font(.headline)
            permissionRow("蓝牙：连接遥控器", granted: model.bluetoothGranted, status: model.bluetoothPermissionStatus, kind: .bluetooth)
            permissionRow("辅助功能：发送语音快捷键", granted: model.accessibilityGranted, status: model.accessibilityPermissionStatus, kind: .accessibility)
            permissionRow("输入监控：接收遥控器按键", granted: model.inputMonitoringGranted, status: model.inputMonitoringPermissionStatus, kind: .inputMonitoring)
            Text("本轮只使用遥控器音频，不采集 Mac 麦克风。语音工具自身的麦克风权限由该工具申请。驱动安装需要管理员确认；这里不会自动安装或重启音频服务。")
            HStack {
                Button("重新检查权限") { checkPermissions() }
                Button("重新连接遥控器") { model.onReconnectInputs?() }.disabled(model.voiceActive)
            }
            Text(permissionCheckResult).font(.callout)
            if let checked = model.permissionCheckedAt {
                Text("上次检查：\(checked.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundColor(.secondary)
            }
            Text("修改系统权限后，请返回这里重新检查；重新连接只重试遥控器通道，不会授予权限。").font(.caption)
        }
    }
    private func permissionRow(_ title: String, granted: Bool, status: String, kind: PermissionKind) -> some View {
        HStack {
            Label(title, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
            Spacer()
            Text(status).fontWeight(.medium)
                .foregroundColor(granted ? .green : .orange)
            Button("打开设置") { model.openSettings(for: kind) }
        }
        .accessibilityElement(children: .contain)
    }
    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音频通道").font(.headline)
            Text("声音来源：Chromecast 遥控器 → 虚拟音频设备 → 语音工具")
            Picker("输出到虚拟设备", selection: Binding(get: { audio.selectedOutputUID ?? "" }, set: {
                _ = audio.selectOutputRoute(uid: $0.isEmpty ? nil : $0); invalidateTest(); routeRevision += 1
            })) {
                Text("关闭输出 / 未选择").tag("")
                ForEach(audio.outputRoutes, id: \.uid) { route in Text(route.name).tag(route.uid) }
            }.id(routeRevision).disabled(model.voiceActive)
            HStack {
                Button("刷新设备") { audio.refreshOutputRoutes(); routeRevision += 1 }
                Button("播放 1 秒测试音") { message = audio.playTestTone() ? "测试音已发送到虚拟设备。请在语音工具的输入电平中确认；这不是识别测试。" : "测试音未发送：请检查虚拟设备。" }.disabled(model.voiceActive)
            }
            Text(audio.routeDiagnostics).font(.caption).textSelection(.enabled)
            HStack {
                Text("遥控器增益")
                Slider(value: Binding(get: { Double(audio.remoteGain) }, set: { audio.setRemoteGain(Float($0)); routeRevision += 1 }), in: 0...20)
                Text(String(format: "%.1f×", audio.remoteGain)).monospacedDigit().frame(width: 55)
            }.disabled(model.voiceActive)
            ProgressView(value: max(0, min(1, (model.remoteLevelDB + 60) / 60)))
            Text(String(format: "实时输入 %.1f dB · 接收数据 %d 次", model.remoteLevelDB, model.receivedAudioPackets)).font(.caption)
            if !audio.isOutputDeviceAvailable { Text("未发现可用虚拟设备。请先按项目安装说明安装 vRemoteDr 2ch / 兼容虚拟音频设备，再刷新。不会自动切换系统默认麦克风。").foregroundColor(.orange) }
        }
    }
    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你准备在哪个工具里说话？").font(.headline)
            Picker("语音工具", selection: $configuration.inputTool) {
                Text("豆包输入法").tag(VoiceInputTool.doubao)
                Text("其他工具（自定义）").tag(VoiceInputTool.custom)
            }
            if configuration.inputTool == .custom {
                HStack {
                    Button("选择语音应用…") { chooseVoiceApplication() }
                    if !configuration.customApplicationPath.isEmpty {
                        Text(URL(fileURLWithPath: configuration.customApplicationPath).deletingPathExtension().lastPathComponent)
                        Button("清除选择") { configuration.customApplicationPath = "" }
                    }
                }
                TextField("应用 Bundle ID（高级，可由选择应用自动填写）", text: $configuration.customBundleIdentifier)
                Text("自定义工具的兼容性需要实际测试。vRemoter 不执行语音识别，也不自动修改该工具设置。").font(.caption)
            }
            Button(launchingVoiceApplication ? "正在打开…" : "打开所选语音工具") {
                launchingVoiceApplication = true
                message = "正在请求系统打开所选语音工具…"
                VoiceApplicationLauncher().launch(configuration: configuration) { result in
                    DispatchQueue.main.async {
                        launchingVoiceApplication = false
                        switch result {
                        case .success(let success): message = success.message
                        case .failure(let error): message = error.localizedDescription
                        }
                    }
                }
            }.disabled(launchingVoiceApplication)
            ChromecastHelpLabel(title: "1. 手里的遥控器：如何操作语音键", explanation: "这是你按实体遥控器上黑色语音键的方式。选择按住说话时，从按下到松开是一句话；选择按一下开始时，第二次按下才结束。它与电脑软件的录音快捷键模式独立。")
            Picker("实体语音键", selection: $configuration.remoteVoiceMode) {
                Text("按一下开始，再按一下停止").tag(RemoteVoiceMode.toggle)
                Text("按住说话，松开停止").tag(RemoteVoiceMode.hold)
            }
            Text(configuration.remoteVoiceMode == .hold ? "例：按住遥控器语音键说「你好」，说完松开。" : "例：按一下遥控器语音键，说「你好」，再按一下结束。")
                .font(.callout).foregroundColor(.secondary)
            ChromecastHelpLabel(title: "2. 电脑上的语音工具：录音快捷键模式", explanation: "请先打开豆包输入法或自定义语音工具的设置，查看它的录音快捷键是按住录音还是按一次开始、再按一次结束，然后在这里选同一种模式。vRemoter 会把实体遥控器的操作转换为工具需要的快捷键按下与松开。")
            Picker("工具内的录音模式", selection: $configuration.inputToolTriggerMode) {
                Text("按一下切换开始 / 停止").tag(InputToolTriggerMode.toggle)
                Text("按住快捷键录音，松开停止").tag(InputToolTriggerMode.hold)
            }
            Text(configuration.inputToolTriggerMode == .hold ? "例：工具要求一直按住 Fn 才录音，就选「按住快捷键录音」。这里不会改变遥控器的按法。" : "例：工具要求按一下 Fn 开始、再按一下 Fn 结束，就选「按一下切换」。这里不会改变遥控器的按法。")
                .font(.callout).foregroundColor(.secondary)
            ChromecastHelpLabel(title: "3. 与工具内设置一致的快捷键", explanation: "这里发送的按键必须与语音工具里设置的录音快捷键完全相同。例如工具内是 Fn，这里也选 Fn；如果工具使用其他快捷键，请先确认支持和兼容性，再实际说话测试。")
            Picker("录音快捷键", selection: $configuration.triggerKey) {
                ForEach(InputTriggerKey.allCases) { Text($0.title).tag($0) }
            }
            Text("最后：在语音工具中把麦克风选为上方同一个虚拟音频设备（例如 vRemoteDr 2ch），打开一个可输入文字的地方，再用遥控器实际说一句话。")
            Text("可以组合使用：遥控器「按一下开始」＋工具「按住快捷键录音」。vRemoter 负责转换；工具的模式和快捷键仍须在两边匹配。").font(.caption)
        }.disabled(model.voiceActive)
    }
    private var speechTest: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("实际说一句话").font(.headline)
            Text("点击“开始本次测试”，把光标放到下方文本框，再用遥控器说话并结束。确认出现的是本次识别内容。手动键入、粘贴和测试音都不能证明识别成功。")
            Button("开始 / 重做本次测试") {
                model.onStopMicrophone?(); testText = ""; confirmedSpeech = false
                testAudioBaseline = model.receivedAudioPackets; testSessionBaseline = model.completedVoiceSessions; testArmed = true
            }.disabled(model.voiceActive)
            TextEditor(text: $testText).frame(height: 100).border(Color.secondary)
            Label(model.receivedAudioPackets > testAudioBaseline && testArmed ? "本次已收到遥控器音频数据" : "等待本次真实音频数据", systemImage: "waveform")
            Label(model.completedVoiceSessions > testSessionBaseline && testArmed ? "本次说话会话已结束" : "等待结束说话", systemImage: "stop.circle")
            Toggle("我确认上方文字是刚才语音工具识别的结果", isOn: $confirmedSpeech)
            Text("识别文本来源由你确认；应用只自动检查音频数据和会话结束，不会把手动输入当成自动验证通过。").font(.caption)
        }
    }
    private var mapping: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("普通按键配置").font(.headline)
            Toggle("启用 Chromecast 按键映射", isOn: Binding(get: { mappingStore.isEnabled(.chromecast) }, set: { model.setRemoteMappingEnabled($0, remote: .chromecast) }))
            Text("每张卡片显示当前单击、双击和长按动作。点击动作在下方编辑；点击照片上的圆点定位对应按键。绿色表示刚收到按键报告。")
                .font(.callout)
            HStack(alignment: .center, spacing: 12) {
                mappingColumn(["03", "05", "07", "0B", "0A", "0E", "01"])
                VStack(spacing: 10) {
                    ChromecastKeyMap(selected: $selectedButton, observed: model.lastButtonID)
                        .frame(width: 240, height: 360)
                    Text("Chromecast Voice Remote\n正面与侧面音量键").font(.caption).multilineTextAlignment(.center)
                    Text("已定位：\(RemoteProfiles.chromecastButtons.first(where: { $0.id == selectedButton })?.title ?? selectedButton)")
                        .font(.caption).foregroundColor(.accentColor)
                    if let observed = model.lastButtonID {
                        Label("收到：\(RemoteProfiles.chromecastButtons.first(where: { $0.id == observed })?.title ?? observed)", systemImage: "waveform")
                            .font(.caption).foregroundColor(.green)
                    }
                }
                mappingColumn(["06", "04", "0C", "0D", "08", "0F", "11"])
            }
            HStack(alignment: .top) {
                Image(systemName: "mic.fill").foregroundColor(model.voiceActive ? .green : .accentColor)
                VStack(alignment: .leading, spacing: 5) {
                    Text("语音键 · 独立配置").fontWeight(.semibold)
                    Text(configuration.remoteVoiceMode == .hold ? "当前：按住说话，松开停止" : "当前：按一下开始，再按一下停止")
                    Text("语音键不配置双击、长按或普通快捷动作，保持开口响应及时。").font(.caption)
                }
                Spacer()
                Button("设置说话方式") { if setup { step = 4 } else { page = 0 } }
            }.padding(12).background(Color.accentColor.opacity(0.06)).cornerRadius(10)
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
                    Toggle("此按键按住连发", isOn: Binding(get: {
                        mappingStore.holdRepeats(for: button, remote: .chromecast)
                    }, set: {
                        mappingStore.setHoldRepeats($0, for: button, remote: .chromecast)
                    }))
                    Text("双击或长按动作存在时，按住连发会暂停。只在配置双击时等待第二次点击；未配置额外手势时立即响应。").font(.caption)
                }.padding(16).background(Color.accentColor.opacity(0.08)).cornerRadius(12)
                    .id("chromecast-inline-editor")
            }
            Text("音量 / 电源 / 信源若设成红外控制，Mac 可能收不到报告。请在 Chromecast 的遥控器设置中检查控制方式。").font(.caption)
            Button("恢复 Chromecast 默认按键") { mappingStore.reset(.chromecast) }
            Text("修改后自动保存；已有配置会被覆盖，可先在设置页导出备份。").font(.caption)
        }.disabled(model.voiceActive)
    }

    private func mappingColumn(_ identifiers: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(identifiers, id: \.self) { identifier in
                if let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == identifier }) {
                    ChromecastMappingCard(button: button, selected: selectedButton == identifier,
                        observed: model.lastButtonID == identifier, selectedGesture: selectedButton == identifier ? selectedGesture : nil) { gesture in
                        selectedButton = identifier
                        selectedGesture = gesture
                        editorRevision += 1
                    }
                }
            }
        }.frame(maxWidth: .infinity)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置与诊断").font(.headline)
            Toggle("登录时启动", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { enabled in
                do { try LaunchAtLogin.setEnabled(enabled) } catch { message = error.localizedDescription }
                routeRevision += 1
            })).id(routeRevision)
            Toggle("在程序坞中显示 vRemoter", isOn: Binding(get: { DockVisibilityPreference.isVisible() }, set: { visible in
                if DockVisibilityController.apply(visible) {
                    DockVisibilityPreference.setVisible(visible); routeRevision += 1
                } else { message = "无法更改程序坞显示，请稍后重试。" }
            })).id(routeRevision)
            Text("隐藏程序坞图标后，菜单栏仍可打开主窗口和设置。").font(.caption)
            permissions
            Text("版本：\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development") · 配置格式 v1")
            HStack {
                Button("导出配置备份") { exportSettings() }
                Button("导入配置") { importSettings() }
                Button("重置本轮设置") {
                    backup = ChromecastSettingsArchive.snapshot()
                    ChromecastSettingsArchive.restore([:]); RemoteMappingStore.shared.reset(.chromecast)
                    reloadConfiguration(); message = "已恢复默认设置。可点击撤销恢复刚才的配置。"
                }
                Button("撤销最近重置 / 导入") { ChromecastSettingsArchive.restore(backup); reloadConfiguration() }
            }.disabled(model.voiceActive)
            Button("重新进行首次引导") { beginSetup() }.disabled(model.voiceActive)
            Button("停止音频并重新检查") { model.onStopMicrophone?(); model.refreshPermissions(); audio.refreshOutputRoutes(); routeRevision += 1 }
            Text("诊断：HID \(model.hidConnected ? "已连接" : "未连接") · BLE \(model.bleConnected ? "已连接" : "未连接") · 音频数据 \(model.receivedAudioPackets) · 完成会话 \(model.completedVoiceSessions)").textSelection(.enabled)
            Text("导入仅接受 Chromecast v1 配置，不会导入权限、日志、录音、设备配对或登录项。系统权限和驱动需要在本机单独检查。").font(.caption)
        }
    }
    private func checkPermissions() {
        model.refreshPermissions()
        let missing = [("蓝牙", model.bluetoothGranted), ("辅助功能", model.accessibilityGranted), ("输入监控", model.inputMonitoringGranted)]
            .filter { !$0.1 }.map { $0.0 }
        permissionCheckResult = missing.isEmpty ? "检查完成：所需权限均已授权。" : "检查完成：仍需开启" + missing.joined(separator: "、") + "。若系统提示重启应用，请退出并重新打开。"
    }
    private var currentRouteFingerprint: String {
        "\(audio.selectedOutputUID ?? "")|\(audio.isOutputDeviceAvailable)|\(audio.remoteGain)"
    }
    private func beginSetup() {
        UserDefaults.standard.set(true, forKey: "chromecast.onboarding.inProgress")
        backup = ChromecastSettingsArchive.snapshot(); saveSetupBackup(); step = 0; invalidateTest(); setup = true
    }
    private func saveSetupBackup() {
        if let data = try? PropertyListSerialization.data(fromPropertyList: backup, format: .binary, options: 0) {
            UserDefaults.standard.set(data, forKey: "chromecast.onboarding.backup")
        }
    }
    private func invalidateTest() { testArmed = false; confirmedSpeech = false; testText = "" }
    private func reloadConfiguration() {
        _ = DockVisibilityController.apply(DockVisibilityPreference.isVisible())
        configuration = AppStorage.voiceConfiguration
        model.setRemoteMappingEnabled(RemoteMappingStore.shared.isEnabled(.chromecast), remote: .chromecast)
        model.onVoiceConfigurationChanged?()
        audio.refreshOutputRoutes(); routeRevision += 1; invalidateTest()
    }
    private func chooseVoiceApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择你使用的语音应用"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let identifier = Bundle(url: url)?.bundleIdentifier
        guard VoiceApplicationLaunchEnvironment.workspace.isValidApplication(url, identifier) else {
            message = "所选文件不是可运行的应用，请选择已安装的 .app。"
            return
        }
        configuration.customApplicationPath = url.path
        configuration.customBundleIdentifier = identifier ?? ""
        message = "已选择 \(url.deletingPathExtension().lastPathComponent)。请打开应用确认录音快捷键和虚拟麦克风。"
    }

    private func exportSettings() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Chromecast-vRemoter-v1.plist"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ChromecastSettingsArchive.exportData().write(to: url, options: .atomic); message = "配置已导出。" }
        catch { message = error.localizedDescription }
    }
    private func importSettings() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let values = try ChromecastSettingsArchive.validate(Data(contentsOf: url))
            backup = ChromecastSettingsArchive.snapshot(); ChromecastSettingsArchive.restore(values)
            reloadConfiguration(); message = "配置已导入。请重新检查虚拟设备并实际说话测试；可撤销本次导入。"
        } catch { message = error.localizedDescription }
    }
    private func open(_ url: String) { if let url = URL(string: url) { NSWorkspace.shared.open(url) } }
}

private struct ChromecastKeyMap: View {
    @Binding var selected: String
    let observed: String?
    private let points: [(String, CGFloat, CGFloat)] = [
        ("03",0.37,0.085),("04",0.37,0.265),("05",0.205,0.17),("06",0.535,0.17),("07",0.37,0.17),
        ("0B",0.255,0.36),("voice",0.475,0.36),("0A",0.255,0.48),("08",0.475,0.48),
        ("0E",0.255,0.60),("0F",0.475,0.60),("01",0.255,0.71),("11",0.475,0.71),
        ("0C",0.84,0.18),("0D",0.84,0.30)]
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = image {
                    Image(nsImage: image).resizable().scaledToFit()
                }
                ForEach(points, id: \.0) { point in
                    Button { selected = point.0 } label: {
                        Circle().fill(selected == point.0 ? Color.accentColor.opacity(0.65) : Color.black.opacity(0.15))
                            .overlay(Circle().stroke(observed == point.0 ? Color.green : Color.white, lineWidth: observed == point.0 ? 3 : 1))
                            .frame(width: 26, height: 26)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(RemoteProfiles.chromecastButtons.first(where: { $0.id == point.0 })?.title ?? point.0)
                        .help(RemoteProfiles.chromecastButtons.first(where: { $0.id == point.0 })?.title ?? point.0)
                        .position(x: proxy.size.width * point.1, y: proxy.size.height * point.2)
                }
            }
        }
    }
    private var image: NSImage? {
        let filename = "chromecast-front-and-volume-enhanced.png"
        for path in [Bundle.main.resourceURL?.appendingPathComponent("RemoteImages/" + filename),
                     URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/RemoteImages/" + filename)].compactMap({ $0 }) {
            if let image = NSImage(contentsOf: path) { return image }
        }
        return nil
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

private struct ChromecastMappingCard: View {
    let button: RemoteButtonDefinition
    let selected: Bool
    let observed: Bool
    let selectedGesture: RemoteButtonGesture?
    let onEdit: (RemoteButtonGesture) -> Void
    @ObservedObject private var store = RemoteMappingStore.shared

    private var borderColor: Color {
        if observed { return .green }
        if selected { return .accentColor }
        return Color.secondary.opacity(0.25)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: button.symbol).frame(width: 15)
            Text(button.title).fontWeight(.semibold)
            Spacer(minLength: 0)
            if observed { Text("收到").foregroundColor(Color.green).font(.caption2) }
            else if selected { Image(systemName: "scope").foregroundColor(Color.accentColor) }
        }.font(.caption)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            ForEach(RemoteButtonGesture.allCases, id: \.self) { gesture in
                ChromecastMappingGestureCell(
                    buttonTitle: button.title,
                    gesture: gesture,
                    actionTitle: store.targetTitle(for: button, remote: .chromecast, gesture: gesture),
                    selected: selectedGesture == gesture,
                    onEdit: { onEdit(gesture) }
                )
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(9)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(borderColor, lineWidth: observed || selected ? 2 : 1))
    }
}

private struct ChromecastMappingGestureCell: View {
    let buttonTitle: String
    let gesture: RemoteButtonGesture
    let actionTitle: String
    let selected: Bool
    let onEdit: () -> Void

    private var helpText: String { "\(buttonTitle) · \(gesture.title)：\(actionTitle)" }
    private var accessibilityText: String { "\(buttonTitle)，\(gesture.title)，当前动作：\(actionTitle)，编辑" }

    private var label: some View {
        HStack(spacing: 5) {
            Text(gesture.title).foregroundColor(Color.secondary).frame(width: 30, alignment: .leading)
            Text(actionTitle).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "pencil").font(.system(size: 9)).foregroundColor(Color.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 4).padding(.vertical, 2)
        .background(selected ? Color.accentColor.opacity(0.13) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
    }

    var body: some View {
        Button(action: onEdit) { label }
            .buttonStyle(.plain)
            .help(helpText)
            .accessibilityLabel(accessibilityText)
    }
}
