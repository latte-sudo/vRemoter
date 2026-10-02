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
    @State private var testText = ""
    @State private var testAudioBaseline = 0
    @State private var testSessionBaseline = 0
    @State private var testArmed = false
    @State private var confirmedSpeech = false
    @State private var selectedButton = "03"
    private let steps = ["欢迎", "连接遥控器", "权限", "音频通道", "语音工具", "实际说话测试", "普通按键", "完成"]
    private var audio: AudioPipe { AudioPipe.shared }

    var body: some View {
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
                    case 1: connection
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
            permissionRow("蓝牙：连接遥控器", granted: model.bluetoothGranted, kind: .bluetooth)
            permissionRow("辅助功能：发送语音快捷键", granted: model.accessibilityGranted, kind: .accessibility)
            permissionRow("输入监控：接收遥控器按键", granted: model.inputMonitoringGranted, kind: .inputMonitoring)
            Text("本轮只使用遥控器音频，不采集 Mac 麦克风。语音工具自身的麦克风权限由该工具申请。驱动安装需要管理员确认；这里不会自动安装或重启音频服务。")
            Button("重新检查并连接") { model.refreshPermissions(); model.onReconnectInputs?(); audio.refreshOutputRoutes() }.disabled(model.voiceActive)
        }
    }
    private func permissionRow(_ title: String, granted: Bool, kind: PermissionKind) -> some View {
        HStack { Label(title, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle"); Spacer(); Button("打开设置") { model.openSettings(for: kind) } }
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
                TextField("应用 Bundle ID，例如 com.example.voice", text: $configuration.customBundleIdentifier)
                Text("自定义工具的兼容性需要实际测试。vRemoter 不执行语音识别，也不自动修改该工具设置。").font(.caption)
            }
            Picker("遥控器操作方式", selection: $configuration.remoteVoiceMode) {
                Text("按一下开始，再按一下停止").tag(RemoteVoiceMode.toggle)
                Text("按住说话，松开停止").tag(RemoteVoiceMode.hold)
            }
            Picker("语音工具的快捷键行为", selection: $configuration.inputToolTriggerMode) {
                Text("按一下切换开始 / 停止").tag(InputToolTriggerMode.toggle)
                Text("按住快捷键录音，松开停止").tag(InputToolTriggerMode.hold)
            }
            Picker("匹配工具内设置的快捷键", selection: $configuration.triggerKey) {
                ForEach(InputTriggerKey.allCases) { Text($0.title).tag($0) }
            }
            Text("请在所选工具里选择同一个虚拟麦克风，并让快捷键和行为与这里一致。遥控器操作方式与工具快捷键行为是两个独立设置。")
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
        HStack(alignment: .top, spacing: 24) {
            VStack {
                ChromecastKeyMap(selected: $selectedButton, observed: model.lastButtonID)
                    .frame(width: 280, height: 420)
                Text("点击键位选择配置。亮起表示接收到该按键报告；侧面图为示意。音量 / 电源 / 信源若设置成红外模式，Mac 可能收不到报告。").font(.caption)
            }.frame(width: 280)
            VStack(alignment: .leading, spacing: 12) {
                Text("普通按键配置").font(.headline)
                Toggle("启用 Chromecast 按键映射", isOn: Binding(get: { RemoteMappingStore.shared.isEnabled(.chromecast) }, set: { model.setRemoteMappingEnabled($0, remote: .chromecast); routeRevision += 1 }))
                Picker("选择按键", selection: $selectedButton) {
                    ForEach(RemoteProfiles.chromecastButtons) { Text($0.title).tag($0.id) }
                }
                if let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == selectedButton }) {
                    if button.voiceControlled {
                        Text("语音键只使用“连接与语音”中的说话方式，不增加双击或长按快捷动作，以免拖慢开口响应。")
                    } else {
                        Toggle("按住连发（高级手势存在时暂停）", isOn: Binding(get: {
                            RemoteMappingStore.shared.holdRepeats(for: button, remote: .chromecast)
                        }, set: {
                            RemoteMappingStore.shared.setHoldRepeats($0, for: button, remote: .chromecast); routeRevision += 1
                        }))
                        ForEach(RemoteButtonGesture.allCases, id: \.self) { gesture in
                            ChromecastGestureEditor(button: button, gesture: gesture)
                        }
                    }
                }
                Text("只在配置双击时等待第二次点击。长按动作与按住连发互斥；未配置额外手势时保留立即响应。").font(.caption)
                Button("恢复 Chromecast 默认按键") { RemoteMappingStore.shared.reset(.chromecast); routeRevision += 1 }
                Text("修改后自动保存；已有配置会被新配置覆盖，可先在设置页导出备份。").font(.caption)
            }.disabled(model.voiceActive)
        }
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置与诊断").font(.headline)
            Toggle("登录时启动", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { enabled in
                do { try LaunchAtLogin.setEnabled(enabled) } catch { message = error.localizedDescription }
                routeRevision += 1
            })).id(routeRevision)
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
        configuration = AppStorage.voiceConfiguration
        model.setRemoteMappingEnabled(RemoteMappingStore.shared.isEnabled(.chromecast), remote: .chromecast)
        model.onVoiceConfigurationChanged?()
        audio.refreshOutputRoutes(); routeRevision += 1; invalidateTest()
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
