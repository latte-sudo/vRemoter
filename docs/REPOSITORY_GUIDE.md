# Remote Voice Utility 项目目录与文件详解

这份指南面向要阅读、修改、测试或接手本项目的开发者，按实际文件内容解释“这个目录负责什么、每个文件为什么存在、代码怎样连起来、修改后该验证什么”。当前项目是 macOS 12+ 的 Chromecast Voice Remote 音频与快捷键工具：它传输遥控器语音到选定虚拟输入链路，并触发外部语音工具；识别由外部工具完成。

当前可见名称为 Remote Voice Utility / 遥控器语音工具 / 遙控器語音工具，均是描述性占位名，不是已确定的最终品牌或新增贡献者署名。当前设计参考是基于已批准 v7 布局、扩展三语与简化文案的离线 HTML v8 中性副本；原始 v8 保持逐字节不变作为历史归档。生产界面是 AppKit 承载的 SwiftUI。运行时只启用遥控器音频，包括旧版本升级场景；代码中仍有通用 Mac capture 实现，不能据此误判当前产品支持混音。当前没有在线服务、外部 Swift package、Xcode 工程文件或 SwiftPM test target。

本指南不表示已经完成 macOS 原生编译、视觉、权限、实体遥控器、语音识别、安装或正式发行验收。驱动构建尤其仍有来源、对应源码、GPL 分发与签名/公证阻塞，见[发布与权利审查](PROJECT_OWNERSHIP_AND_LICENSES.md)及[当前验收清单](CHROMECAST_ACCEPTANCE.md)。

## 阅读路线

- 初次接手：先读第 1 节目录，再读第 2 节架构流程、根 README 和 PRODUCT
- 改界面：查看第 4 节 Swift 文件及第 5 节大文件拆解，再查原型、设计 token 和几何测试
- 修语音/卡键：读 BLE → ATVV → controller → AudioPipe 流程，先补虚拟调度器/资源租约回归
- 改映射：从 RemoteMappingSupport、RemoteButtonGestures、RemoteButtonMappingController 三层入手
- 准备发布：读 Packaging、Driver、许可文件与第 14 节；不要直接把开发 PKG 当正式安装包

## 1 清单口径与完整目录

快照日期：2026-10-02；以 `2c88332` 为提交基线，清单包含其后的本轮品牌中性化工作区改动。文件范围为 Git 保留的已跟踪文件与本轮新增、准备纳入版本控制的文件；排除 Git 管理目录、构建缓存、被忽略产物和用户运行时数据，不计已删除路径。本轮从此前 150 个文件移除 21 个上游品牌设计文件和 8 张帮助截图，新增 5 个文件，合计 **126 个文件**，其中 **45 个生产 Swift 文件**、**22 个 Swift 自测文件与 1 份自测说明**。这个快照描述文件状态，不代表相关检查或实机验收已通过。

| 位置 | 文件数 | 主要职责 |
| --- | ---: | --- |
| 根目录 | 15 | 产品/许可/版本、SwiftPM、构建安装及测试入口 |
| .github | 1 | macOS 持续集成 |
| Sources | 48 | 45 个原生 Swift 文件与 3 个应用语言表 |
| SelfTests | 23 | 分层回归与运行边界说明 |
| Tools | 13 | 源码、品牌/打包、模型检查、占位图生成和 HID 诊断 |
| Packaging | 5 | App 身份、三语用途说明、PKG 安装钩子 |
| Driver | 4 | 实验驱动构建/安装/卸载与风险说明 |
| Resources | 4 | 通用占位图及说明、活动遥控器图、原生权限示意说明 |
| docs | 13 | 本指南、产品工程说明、验收、当前中性原型与历史 v8 |

下面是完整保留文件树，不含被忽略生成物。后续表格每个路径均链接到实际文件；文件树提供位置，表格提供职责和修改边界。

```text
vremoter-chromecast-v1/
├── .github/
│   └── workflows/
│       └── chromecast-validation.yml
├── .gitignore
├── CHANGELOG.md
├── Driver/
│   ├── README.md
│   ├── build-driver.sh
│   ├── install-driver.sh
│   └── uninstall-driver.sh
├── LICENSE
├── PRODUCT.md
├── Package.swift
├── Packaging/
│   ├── Info.plist
│   ├── en.lproj/
│   │   └── InfoPlist.strings
│   ├── pkg-scripts/
│   │   └── postinstall
│   ├── zh-Hans.lproj/
│   │   └── InfoPlist.strings
│   └── zh-Hant.lproj/
│       └── InfoPlist.strings
├── README.md
├── Resources/
│   ├── AppIcon/
│   │   ├── README.md
│   │   └── placeholder-app-icon.png
│   ├── PermissionGuides/
│   │   └── README.md
│   └── RemoteImages/
│       └── chromecast-front-and-volume-enhanced.png
├── SelfTests/
│   ├── AppAppearanceControllerTests.swift
│   ├── AppAppearanceTests.swift
│   ├── AudioResourceLeaseTests.swift
│   ├── AudioRouteConfigurationTests.swift
│   ├── ChromecastArchiveTests.swift
│   ├── ChromecastMappingLayoutTests.swift
│   ├── ChromecastVoice/
│   │   ├── TransportTests.swift
│   │   └── main.swift
│   ├── DockVisibilityTests.swift
│   ├── Gestures/
│   │   ├── README.md
│   │   ├── RemoteButtonGestureTests.swift
│   │   ├── RemoteButtonMappingControllerTests.swift
│   │   └── RemoteMappingStoreTests.swift
│   ├── KeyboardTriggerStateTests.swift
│   ├── LocalizationTests.swift
│   ├── MenuBarVoiceReceptionTests.swift
│   ├── OnboardingEvidenceTests.swift
│   ├── OnboardingProgressTests.swift
│   ├── PermissionRequestTests.swift
│   ├── RemoteDisplayNameTests.swift
│   ├── VoiceApplicationLauncherTests.swift
│   ├── VoiceSessionPresentationTests.swift
│   └── main.swift
├── Sources/
│   └── vRemote/
│       ├── ATVV/
│       │   ├── ADPCMDecoder.swift
│       │   ├── ATVVProtocol.swift
│       │   └── BridgeError.swift
│       ├── ATVVStreamLifecycle.swift
│       ├── AppAppearance.swift
│       ├── AppAppearanceController.swift
│       ├── AppStorage.swift
│       ├── AudioPipe.swift
│       ├── AudioResourceLease.swift
│       ├── AudioRouteConfiguration.swift
│       ├── BLEBridge.swift
│       ├── ChromecastConsoleView.swift
│       ├── ChromecastMappingCanvas.swift
│       ├── ChromecastMappingLayout.swift
│       ├── ChromecastRemoteHIDBridge.swift
│       ├── ChromecastSettingsArchive.swift
│       ├── ChromecastVoiceSessionController.swift
│       ├── ChromecastVoiceStateMachine.swift
│       ├── ConsoleDesignTokens.swift
│       ├── DebugWindowController.swift
│       ├── DockVisibility.swift
│       ├── DockVisibilityController.swift
│       ├── DoubaoAudioStateMonitor.swift
│       ├── InputTrigger.swift
│       ├── KeyboardTriggerObserver.swift
│       ├── KeyboardTriggerState.swift
│       ├── LaunchAtLogin.swift
│       ├── Localization.swift
│       ├── Log.swift
│       ├── MacPermissionRequester.swift
│       ├── MenuBarStatusIcon.swift
│       ├── MenuBarVoiceReception.swift
│       ├── OnboardingProgress.swift
│       ├── OnboardingSpeechEvidence.swift
│       ├── PermissionRequestSupport.swift
│       ├── RemoteButtonGestures.swift
│       ├── RemoteButtonMappingController.swift
│       ├── RemoteDisplayName.swift
│       ├── RemoteMappingSupport.swift
│       ├── RemoteVoiceSupport.swift
│       ├── Resources/
│       │   ├── en.lproj/
│       │   │   └── Localizable.strings
│       │   ├── zh-Hans.lproj/
│       │   │   └── Localizable.strings
│       │   └── zh-Hant.lproj/
│       │       └── Localizable.strings
│       ├── VoiceApplicationLauncher.swift
│       ├── VoiceConfiguration.swift
│       ├── VoiceSessionPresentation.swift
│       ├── WavRecorder.swift
│       └── main.swift
├── THIRD_PARTY_NOTICES.md
├── TODO.md
├── Tools/
│   ├── check-app-bundle.py
│   ├── check-branding.py
│   ├── check-localization.py
│   ├── check-mapping-layout.py
│   ├── check-native-interface.py
│   ├── check-runtime-cleanup.py
│   ├── generate-placeholder-icon.py
│   ├── hid-report-probe.swift
│   ├── run-gesture-tests.sh
│   ├── test-chromecast-models.sh
│   ├── test-localization.sh
│   ├── test-package-contents.py
│   └── test-voice-launcher.sh
├── VERSION
├── build-dmg.sh
├── build-pkg.sh
├── docs/
│   ├── CHROMECAST_ACCEPTANCE.md
│   ├── CHROMECAST_SCROLL_ACTIONS.md
│   ├── CLEANUP_REVIEW.md
│   ├── LOCALIZATION.md
│   ├── NATIVE_INTERFACE_IMPLEMENTATION.md
│   ├── PERMISSION_REQUESTS.md
│   ├── PROJECT_OWNERSHIP_AND_LICENSES.md
│   ├── REPOSITORY_GUIDE.md
│   ├── chromecast-audio-resource-lifecycle.md
│   └── prototypes/
│       ├── README.md
│       ├── remote-voice-utility-onboarding-settings.html
│       ├── test-vremoter-onboarding-settings.cjs
│       └── vremoter-onboarding-settings.html
├── install-app.sh
├── package-app.sh
├── run-chromecast-voice-tests.sh
└── run-self-tests.sh
```

## 2 架构与关键调用流程

### 2.1 三条边界要分清

1. 连接分为 HID 普通按键和 BLE ATVV 语音，两条连接状态各自上报；一个 connected 布尔值不能证明全链路可用
2. 语音有传输流、应用会话和页面展示三个状态层，分别由 ATVVStreamLifecycle、ChromecastVoiceStateMachine/controller、VoiceSessionPresentation 管理；它们不是同一件事
3. 接收到 PCM、送入虚拟设备、外部工具正在录音、最终识别文本正确，是不同证据。程序不实现语音识别，也不能从测试音或手打文字推导识别成功

### 2.2 启动与生命周期

```text
NSApplication → AppController.applicationDidFinishLaunching
  → AppStorage.prepare / AppAppearanceController / DockVisibilityController
  → 将保存和已缓存的 AudioPipe 输入都设为 mac=false、remote=true
  → 建立菜单栏、ConsoleViewModel 与跨模块回调
  → ChromecastVoiceSessionController.start
  → KeyboardTriggerObserver.start
  → ChromecastRemoteHIDBridge.start + BLEBridge.start
  → 发现虚拟输出（发现本身不启动 IOProc）
  → 打开 DebugWindowController 中的 ChromecastConsoleView
```

关闭控制台只关闭窗口，不退出菜单栏进程。睡眠/停止/退出要结束语音、释放合成键和映射重复；应用终止还要撤销输入观察、BLE/HID、音频设备与定时器。修改启动逻辑必须保留“先禁用已缓存 Mac input，再启动任何会话”的顺序，不能仅写 UserDefaults。

### 2.3 连接与遥控器音频

```text
BLEBridge.start
  → 优先取保存的 peripheral UUID，并验证 Chromecast Remote 名称提示
  → 必要时扫描、连接、发现 service/characteristics
  → ATVV capabilities 协商 → 选择 ADPCM 16 kHz 或 8 kHz
  → 控制通知 → ATVVProtocol.parseControl → ATVVStreamLifecycle
  → 有效 AUDIO_START / AUDIO_SYNC → 解码器建立本流状态
  → 有效 PCM → onPCMReceived + AudioPipe.feed + 可选 WavRecorder
```

BLEBridge 使用 main queue；流控制中有去重、MIC_OPEN 去抖、保活与 generation 保护的关闭超时。AUDIO_SYNC 可能在 START 前到达，因此不能在每次 START 时无条件丢弃新同步。关闭中的流不再接纳 PCM。HID 模型号和 BLE 名称匹配是当前方案，尚未形成多个实体遥控器之间的明确身份绑定。

### 2.4 应用语音会话与输出

```text
物理 ATVV 语音边沿 / 配置的物理键盘触发
  → ChromecastVoiceStateMachine 产生 begin/end/requestHostOpen 等 Effect
  → ChromecastVoiceSessionController
      先 AudioPipe.setRemoteActive(true) 成功
      再按目标 hold/toggle 模式合成快捷键（物理键盘路径避免重复发起）
      等真实 PCM；豆包模式另等实际录音状态
  → VoiceSessionPresentation → 全局头部、时长、停止入口
```

- 遥控器 hold/toggle 和目标工具 hold/toggle 分开配置，共四种组合
- 当前 controller 上限：主机开麦最多 3 次、开麦确认 1 秒、首 PCM 2 秒、目标开始/停止确认各 1.5 秒、会话安全上限 120 秒
- 正常结束先关闭来源，再保留约 120 ms 输出尾音，结束目标快捷键后释放路由；强制停止保证立即释放已持有的旧键
- controller 捕获启动时配置，配置改变不能用“新触发键”释放“旧按下键”
- 未释放成功时保留 closing/error 与可用 Stop，不能只把 UI 改 idle；自定义工具停止状态为未确认，豆包仍录音时警告而不盲目再切换
- AudioPipe 使用稳定 UID 选择输出，缺失已选设备时失败关闭，不回退扬声器或修改系统默认输入/输出
- 测试音单独租用输出、不抓 Mac 麦克风、不能进入活跃会话；旧测试音结束回调不能释放后来的语音租约

### 2.5 按键映射与合成输入

```text
HID report 0x01 → ChromecastRemoteHIDBridge.handleReport
  → 普通键 ID + down/up → RemoteButtonMappingController
  → 快照 RemoteMappingStore 动作 + RemoteButtonGestureRecognizer
  → RemoteMappingAction.post
      键盘 / 媒体键 / 一次完整 Command+Tab / 像素滚动 / 指定 .app
```

默认手势时序为双击窗口 300 ms、长按 550 ms、普通按住重复起始 450 ms、重复间隔 70 ms。高级双/长映射会推迟普通单击并暂停普通单击连发；连续滚动拥有自己的重复语义。迟到 timer 只发一个当前动作，不补发一串过期动作。松手或取消不补最后一格滚动。

映射启用时 HID manager 使用 seize 模式避免原生媒体动作和新映射同时触发；禁用时保留系统原始行为。controller 按下时抓取动作快照，编辑/导入/重置/睡眠中取消时释放原动作，并要求松手后重新按下才能启动新的滚动。语音卡始终走 ATVV，会拒绝普通映射写入。

### 2.6 真实试用和 UI 状态

AppController 将新 PCM 包、结束会话计数与类型化状态传给 ConsoleViewModel。七步引导为：选择工具 → 连接 → 权限 → 说话方式 → 真实试用 → 按键 → 就绪。OnboardingSpeechEvidence 比较“本次 armed 的基线”与新事件；还要求非空文字、用户确认和有效环境。权限/连接/配置变化、重试、文字编辑会按情况使证据失效。进度可恢复，但证据不跨重启复用。

MenuBarVoiceReception 只由真实新 PCM 刷新，要求仍处于有效 streaming/phase；0.75 秒未收到包便失效。AppController 在接收时用 common run-loop timer 更新，停止后撤掉 timer。绿点只表示最近收到音频，不代表识别成功。

### 2.7 设置与导入边界

原生备份为 version 1、device=chromecast 的 plist；内部部分结构使用 JSON Data。validate 在任何写入前检查小于 1 MB、settings 少于 300 项、白名单、值类型/长度、枚举和按键/action payload。UI 随后显示默认取消且可先导出的确认，再调用 restore，重新加载映射/路由/外观/触发键并使试用证据失效。

允许内容主要是语言、语音设置、触发键、虚拟输出 UID、增益、主题、Dock、app 内昵称及 Chromecast 映射。配对、密码、系统权限、日志、录音、登录项不在备份内。历史 v1 Chromecast 档案的五类已知旧设备字段可被丢弃；未知字段与旧设备独立档案拒绝。当前恢复不抹除磁盘上无关的旧偏好。语言有额外可读性保护：新备份可恢复明确语言，旧备份缺语言字段或恢复默认时保留当前语言，而非突然回到用户不理解的界面。

### 2.8 平台依赖

| 边界 | 使用位置 | 影响 |
| --- | --- | --- |
| Foundation | 协议、纯状态、配置、文件与调度 | 多数模型可由 swiftc 单独测试 |
| AppKit + SwiftUI | 窗口、视图、打开应用、图标、设置面板 | 生产 App 需要 macOS SDK |
| CoreBluetooth | BLEBridge、权限申请/查询 | 蓝牙连接和 TCC 需真实 Mac |
| IOKit.hid | HID bridge、独立 probe | 设备报告、独占集合和权限需实机 |
| CoreGraphics / ApplicationServices | 观察、发键、滚动、AX 权限 | 纯构造测试不能证明投递到目标 App |
| CoreAudio / AudioToolbox / AVFoundation / CoreMedia | AudioPipe、豆包状态、保留的通用 capture | 设备格式、资源释放、系统 API 需支持的 macOS 验收 |
| zsh / macOS CLI 工具 | App、DMG、PKG 和驱动脚本 | sips/iconutil/codesign/pkgbuild/hdiutil 不能由 Linux 源码检查替代 |

### 2.9 三语资源与原地切换

AppLanguage 只保存应用自己的语言偏好，支持跟随系统、简体中文、繁体中文、英文；系统中文脚本 Hans/Hant 优先于地区，TW/HK/MO 在没有显式脚本时选繁体，其他不支持语言回退英文。L10n 用稳定语义 key 加位置占位符加载字符串，用户昵称、设备名、文件名与诊断值保持原样，不重新解释用户文本里的占位符。

当前三份 Localizable.strings 各含 479 个语义 key。SwiftPM 通过 process(Resources) 生成资源 bundle，开发 executable 读取 Bundle.module；手工 App 打包把三份语言表直接放入 Contents/Resources 的 .lproj 目录，避免携带过期第三方 bundle。Packaging 的 InfoPlist.strings 是系统用途说明，Sources 的 Localizable.strings 才是应用正文。

语言修改广播 appLanguageDidChange，LanguageStore 让 SwiftUI 原地刷新，AppController/DebugWindowController 刷新菜单和标题；正在进行的会话保留状态、错误与时间戳。VoiceSessionPresentation 持有本地化 key，因此不能仅翻译已缓存的旧文本；归档恢复若改变语言也必须发通知。换语言不代表已重新授权、重新识别或重启连接。

### 2.10 描述性名称与兼容身份

- 可见窗口、菜单、三语用途说明及 App 本地化元数据使用描述性占位名；原生和当前原型保留最终名称待定提示。通用图标替代旧独立品牌资产，不替换继承实现的作者头或许可文字
- vRemote Swift target、可执行文件和 .app 路径，以及既有 bundle/signing/login-item/PKG/driver ID、偏好 key、数据目录与原型存储格式继续保留。它们是兼容接口，不是当前可见品牌或新的权属声明
- 此次 DMG 只改用户看到的卷名；分发文件名等技术字段的协调迁移仍在 TODO。改显示名不会自动迁移设置、授权、路由、登录项或用户数据
- 选择最终名称/署名、用户控制的命名空间及升级或并存策略后，必须一起设计迁移、回滚与 macOS 验收；不要批量替换历史和通知里的旧名称

## 3 根目录与持续集成

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [.github/workflows/chromecast-validation.yml](../.github/workflows/chromecast-validation.yml) | macos-14 上执行 swift build、协议/模型/20 次语音回归、几何/原生/清理契约、Node 20 当前与历史原型回归、品牌/来源/兼容契约与占位图逐字节重建检查、三语源码/运行时测试、SwiftPM 与实际 App 的 --localization-self-test、隔离打包、真实 App 打包及资源通知校验。push 仅配置 feat/chromecast-first-run，pull_request 也触发；仓库权限为 contents: read。 | 新增测试须接入此 workflow；实际成功以当前候选 commit 的 run 为准，不代表原生视觉、权限弹窗或硬件通过。 |
| [.gitignore](../.gitignore) | 排除 SwiftPM、dist、驱动构建、App/driver/dSYM、日志、录音和配对标识等生成或私人数据。 | 新增工具产物时更新；被忽略不等于本机一定存在，也不表示可以删除用户数据。 |
| [CHANGELOG.md](../CHANGELOG.md) | 保留上游 1.0.0 至 1.1.1 历史，包括当时的双遥控器、旧安装建议与功能。它是历史记录，不是本分支当前支持清单。 | 发布新版本时追加真实发布记录；不要按旧条目恢复已移除功能或宣称当前 PKG 可分发。 |
| [LICENSE](../LICENSE) | 根 MIT 许可及 Sima Qingfeng 版权行；覆盖继承实现的基本来源通知。 | 保留全文；新增贡献和发行许可决策需要与第三方通知配套，不把驱动视为 MIT。 |
| [PRODUCT.md](../PRODUCT.md) | 当前产品边界：Chromecast-only、七步引导、四页设置、独立 hold/toggle 语义、远程音频和安全停止；列明暂不支持的宏、多设备绑定等。 | 先在此确认需求是否属于当前产品，再改运行时代码与验收。 |
| [Package.swift](../Package.swift) | Swift tools 5.9、macOS 12 最低版本、defaultLocalization=en，一个 vRemote executable target，源目录 Sources/vRemote，process(Resources) 将三语字符串表作为 SwiftPM 资源；Debug 定义 DEBUG。没有外部 Swift package 或 testTarget。 | 调整编译/资源布局时修改；新增 Swift 文件自动进入 target，测试由脚本显式选文件编译。Bundle.module 为 SwiftPM 生成的资源入口，不是第三方依赖。 |
| [README.md](../README.md) | 项目入口：支持范围、Mac 环境、构建安装、首次使用、排障、测试命令和发布阻塞项。解释 HID 与 BLE 分开、实际 PCM 与识别结果分开。 | 修改开发流程、运行条件、用户可见能力时同步；不要把历史 CI 或原型通过写成实机验收。 |
| [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) | 继承实现、提取的中性公共代码、mi-ao / ATVVoice / ATVV 来源与 MIT 文字，以及 BlackHole GPL、历史依赖与品牌资源移除记录。 | 新增或移除依赖、复制代码、变更驱动输入时核对；package-app.sh 将本文件实际随包复制。 |
| [TODO.md](../TODO.md) | 暂缓的实体遥控器与电脑身份绑定设计，以及最终产品名、贡献署名、图标、命名空间和协调迁移清单；包括 HID/BLE 关联、稳定身份、既有设置/路由/登录项/TCC 兼容。 | 开始多设备或最终命名设计时从这里接续；现有 VID/PID、昵称和保存的 BLE UUID 不等于实现身份绑定，占位名也不代表已选择新作者或完成技术身份迁移。 |
| [VERSION](../VERSION) | 当前文本版本号 1.1.1。 | 发布时与 Packaging/Info.plist 核对；现有 DMG/PKG 脚本实际从 plist 读取版本，改此文件不会单独改变包版本。 |
| [build-dmg.sh](../build-dmg.sh) | 调用 package-app.sh，准备 App 与 Applications 链接，用 hdiutil 创建 UDZO 格式 app-only DMG，卷名为 Remote Voice Utility <version>，并移除 staging；既有分发文件名暂留以待协调迁移。 | 修改 DMG 布局、命名或卷名时使用；覆盖同版本生成 DMG，不是签名/公证发布流水线。 |
| [build-pkg.sh](../build-pkg.sh) | 先构建 App 和修改版驱动，将两者放入 Applications 与系统 HAL payload，调用 pkgbuild；可由 INSTALLER_SIGN_IDENTITY 触发 productsign。 | 改安装包时同时检查 postinstall、Driver 和许可；不设置签名身份会生成未签名 PKG，含驱动的发布路线仍阻塞。 |
| [install-app.sh](../install-app.sh) | 将已构建 App 复制到当前用户 Applications 中，最后校验签名。 | 仅在明确要替换本地已安装 App 时运行；会先删除同名目标目录，不构建、不安装驱动、不授权 TCC。 |
| [package-app.sh](../package-app.sh) | 构建 release，重建 dist/build/vRemote.app；复制三份 Localizable.strings 及对应 InfoPlist.strings、通用占位图、唯一活动遥控器图与三份许可；将占位 PNG 复制为 AppIcon.png 并生成 AppIcon.icns，清扩展属性并 ad-hoc 签名。权限帮助由原生绘制，不再复制截图目录。 | 本地化直接复制到 Contents/Resources/<locale>.lproj，不通配打包 SwiftPM 缓存 bundle。改变资源/身份时跑两类打包检查；会重建生成 App，不装驱动、不公证。 |
| [run-chromecast-voice-tests.sh](../run-chromecast-voice-tests.sh) | 在临时目录将生产语音状态机、会话控制器、ATVV、资源租约与测试适配器编译为独立程序；退出时清理临时目录。 | VREMOTE_VOICE_TEST_REPETITIONS 为 1–100，默认 1；缺 swiftc 明确退出 127。此测试不调用真实 CoreAudio/BLE 或发键。 |
| [run-self-tests.sh](../run-self-tests.sh) | 用 swiftc 编译 ATVV 的三个生产文件与 SelfTests/main.swift，执行 .build/vremote-self-test。 | 协议与 ADPCM 改动的最小回归入口；脚本使用 zsh，纯协议逻辑本身不需要遥控器。 |

## 4 生产代码逐文件说明

Sources/vRemote 是一个 executable target，没有以目录隔离成多个 Swift module。文件分层是工程职责约定；类型仍在同一目标内可直接引用。以下按协作关系分组，避免按字母顺序误把传输、应用状态和 UI 状态混成一层。

### 4.1 应用入口与系统整合

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/main.swift](../Sources/vRemote/main.swift) | AppController 是应用组合根和 NSApplicationDelegate/NSMenuDelegate：创建菜单栏、组装 HID/BLE/键盘/语音/音频/窗口回调，维护状态、睡眠清理和退出。文件末另有语言资源 smoke-check 分支，正常启动 NSApplication 并处理 SIGTERM。 | 启动顺序、跨模块事件、菜单行为在此改；先读下方大文件拆解，重点回归升级禁用 Mac capture、实际 PCM 绿点及 shutdown。 |
| [Sources/vRemote/AppStorage.swift](../Sources/vRemote/AppStorage.swift) | 基础 UserDefaults key、默认开关、标准日志/应用支持/录音路径、目录准备、占用统计、明确清理和大小格式化。默认日志/录音/Mac input 关，remote input 开。 | 新增本地数据需明确生命周期与隐私；clearFiles 是删除操作，应留在明确用户清理路径，不随代码清理运行。 |
| [Sources/vRemote/Localization.swift](../Sources/vRemote/Localization.swift) | 稳定 AppLanguage 值 system/zh-Hans/zh-Hant/en，解析系统首选语言与 script/region；LanguageStore 通过通知增加 revision 令界面原地刷新；L10n 按语义 key 查找三语表，优先 App bundle、SwiftPM 用 Bundle.module，缺值回退英文/key，安全替换 {0} 等占位。 | 新增文案用稳定 key 同步三份表；动态用户文字不做翻译/再插值。切换语言不改系统 locale、不重建根视图、不重启/中断语音；资源加载、key/占位 parity 与原生视觉分别验证。 |
| [Sources/vRemote/LaunchAtLogin.swift](../Sources/vRemote/LaunchAtLogin.swift) | 生成/删除用户 LaunchAgents plist，以 /usr/bin/open 当前 .app，通过 launchctl bootout/bootstrap 注册；不是 ServiceManagement 登录项 API。 | 改 bundle 路径/登录项 label 需迁移考虑；会改变用户持久启动配置，失败时回滚新 plist，纯 SwiftPM 运行没有合法 .app 路径。 |
| [Sources/vRemote/AppAppearance.swift](../Sources/vRemote/AppAppearance.swift) | system/light/dark 稳定持久化值；缺失或非法值回到 system。 | 归档兼容与默认值改此处，并跑偏好单测。 |
| [Sources/vRemote/AppAppearanceController.swift](../Sources/vRemote/AppAppearanceController.swift) | 把外观偏好应用到 NSApp.appearance，System 赋 nil 让系统后续主题继续传播；窗口、sheet、panel 继承。 | 实际 AppKit 外观切换在此，不修改 AppleInterfaceStyle；须跑 macOS controller 测试与视觉验收。 |
| [Sources/vRemote/DockVisibility.swift](../Sources/vRemote/DockVisibility.swift) | chromecast.showDockIcon 偏好读写；缺值为 false，保留菜单栏应用默认行为。 | 修改缺省和归档恢复时跑 DockVisibilityTests。 |
| [Sources/vRemote/DockVisibilityController.swift](../Sources/vRemote/DockVisibilityController.swift) | 切换 regular/accessory activation policy，设置应用图标，并异步恢复已聚焦且可见的窗口。 | 处理 Dock 显隐、焦点和图标；不得关掉控制台或丢失菜单栏入口。 |
| [Sources/vRemote/MenuBarVoiceReception.swift](../Sources/vRemote/MenuBarVoiceReception.swift) | 纯绿点判定：streaming 且 phase 为 opening/recording，并在单调时钟 0.75 秒内收到真实 PCM 才为 true；离开接收态立即清历史。 | 改指示时长/生命周期时补状态回归；连接成功、测试音、主机请求均不能点亮。 |
| [Sources/vRemote/MenuBarStatusIcon.swift](../Sources/vRemote/MenuBarStatusIcon.swift) | 用 LogoAsset 的通用占位图绘制 22×18 菜单栏图标，收到语音时叠加绿色圆点；非 template 图像避免系统把绿点染成文本色。 | 只负责画图，接收语义在 MenuBarVoiceReception；浅深菜单栏/高对比和 VoiceOver 文案要实测。 |
| [Sources/vRemote/Log.swift](../Sources/vRemote/Log.swift) | 带锁日志文件、开关、clear 和 5 MiB 达阈值截断；全局单字符串 print 重载写到此日志。 | 排障输出在此统一；日志关闭时此重载不输出，所谓 rotate 当前是截断而非保留多个历史文件。 |

### 4.2 HID BLE 与 ATVV 传输

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/ChromecastRemoteHIDBridge.swift](../Sources/vRemote/ChromecastRemoteHIDBridge.swift) | IOHIDManager 只匹配 VID 0x18D1 / PID 0x9450；映射打开时独占匹配集合，解析 reportID 0x01，零 usage 表示释放，普通键交给映射控制器并反馈 UI 高亮。语音键依赖 ATVV。 | 改 HID 格式、独占开关、断连和睡眠处理；必须实测硬件，IR 配置键不一定向 Mac 发送报告。 |
| [Sources/vRemote/BLEBridge.swift](../Sources/vRemote/BLEBridge.swift) | CoreBluetooth 中央与外设代理；保存/恢复 peripheral UUID、按名称发现，协商 ATVV 特征与 capabilities，开关麦/保活/关闭超时，解码帧后送 AudioPipe，同时发布连接、电平和真实 PCM 回调。 | 改连接、控制 reason、重试和流生命周期时联测 ATVVStreamLifecycle 与语音控制器；有 Bluetooth、持久 UUID 和可选录音副作用。 |
| [Sources/vRemote/ATVVStreamLifecycle.swift](../Sources/vRemote/ATVVStreamLifecycle.swift) | 纯传输状态：isStreaming/isClosing/physicalButtonDown/awaitingHostStart/generation/streamID；start、stop、requestedClose 决定接收 PCM、物理释放和超时归属。 | 改重复 START/STOP、防旧关闭影响新流时配 TransportTests；STOP 本身无 stream ID，不能声称能区分任意乱序包。 |
| [Sources/vRemote/ATVV/ATVVProtocol.swift](../Sources/vRemote/ATVV/ATVVProtocol.swift) | 定义 ATVVVersion、ATVVCodec、ATVVCapabilities、ATVVControlEvent 和协议处理器；协商优先 16 kHz，支持 8 kHz，生成版本相关开关/保活命令，解析控制和解码音频。v0.4 每包含 predictor，v1.0 保持连续 ADPCM 状态及序号。 | 协议更改先跑 SelfTests/main 和 TransportTests；prepare/begin/applyAudioSync 的顺序决定是否保留 START 前新同步或误用旧状态。保留作者头。 |
| [Sources/vRemote/ATVV/ADPCMDecoder.swift](../Sources/vRemote/ATVV/ADPCMDecoder.swift) | IMA/DVI ADPCM 解码的 predictor、step index、step/index 表；每字节高 nibble 先解，输出 Int16，索引限制 0–88、sample 限幅。 | 音频失真或协议 nibble 顺序问题入口；是纯 Foundation 实现，无硬件/文件副作用，保留作者头。 |
| [Sources/vRemote/ATVV/BridgeError.swift](../Sources/vRemote/ATVV/BridgeError.swift) | 协议层最小 LocalizedError，只保留 protocolFailure(String)，供能力/命令前置条件失败显示。 | 新增协议错误需与调用处 do/catch 同步；保留来源说明，不把 transport 失败都静默吞掉。 |

### 4.3 语音会话与音频资源

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/RemoteVoiceSupport.swift](../Sources/vRemote/RemoteVoiceSupport.swift) | RemoteMicrophoneOpenResult 表达 sent、alreadyStreaming、retryAfter、unavailable、failed；DoubaoAudioStateProviding 为观察器和测试注入边界，真实 monitor 通过 extension 遵循。 | 跨传输/控制器契约改变时同步生产实现和测试；不能在测试里重新定义同名契约掩盖接口漂移。 |
| [Sources/vRemote/ChromecastVoiceStateMachine.swift](../Sources/vRemote/ChromecastVoiceStateMachine.swift) | 纯应用会话状态，RemoteVoiceMode 与 InputToolTriggerMode 定义在此；物理 START reason 0x03 才可新建遥控器会话，reason 0x00 只能确认主机请求，STOP 0x02 区分 hold 停止与 toggle 续流。 | 先用纯 Effect 序列检验手势策略，再在 controller 执行副作用；保留 generation 和物理键锁存。 |
| [Sources/vRemote/ChromecastVoiceSessionController.swift](../Sources/vRemote/ChromecastVoiceSessionController.swift) | 单个语音会话的副作用编排：启动输出、目标快捷键、真实 PCM/豆包录音确认、有限 MIC_OPEN 重试、收尾尾音、平衡 key-up、错误与停止确认。 | 所有入口按主队列契约调用；改时必须跑多次虚拟调度器回归和四种遥控器/目标工具模式组合。 |
| [Sources/vRemote/VoiceConfiguration.swift](../Sources/vRemote/VoiceConfiguration.swift) | Codable 语音配置：遥控器模式、目标快捷键模式、Doubao/custom、Bundle ID、触发修饰键与 .app 路径；isValid 校验，旧档案缺路径可兼容；AppStorage extension 同步旧触发键。 | 新增配置字段需考虑解码默认值、归档白名单、UI、launcher 和测试；自定义工具不使用豆包专用的权威录音判断。 |
| [Sources/vRemote/VoiceSessionPresentation.swift](../Sources/vRemote/VoiceSessionPresentation.swift) | controller 所有的类型化展示快照：Phase/Failure/TargetStopStatus/Event、真实录音起止时间与错误栈；保存 detailKey 和 fallback detailText，读取 detail 时本地化，使当前/结束状态能原地换语种；elapsed 在结束后冻结。 | 修改状态/计时优先改此模型与三语 key；页面不能从本地化文本猜状态，换语言或切页不能重置会话时间或丢掉错误。 |
| [Sources/vRemote/VoiceApplicationLauncher.swift](../Sources/vRemote/VoiceApplicationLauncher.swift) | 注入式 VoiceApplicationLaunchEnvironment 隔离 AppKit；launch 按选中路径/正在运行/LaunchServices/豆包安装候选解析，验证可执行 .app 后激活或异步打开，返回类型化结果。 | 工具打开失败、移动路径和新工具适配改此处；启动成功只证明启动，不证明虚拟麦克风、快捷键或识别兼容。 |
| [Sources/vRemote/DoubaoAudioStateMonitor.swift](../Sources/vRemote/DoubaoAudioStateMonitor.swift) | 观察特定输入法进程的 CoreAudio process object、IsRunningInput 和 Devices；Snapshot 分为 unavailable/inactive/active，报告实际设备名，绑定与撤销系统监听器。 | 豆包身份、录音状态与设备诊断问题入口；它读取状态，不录音、不识别、不杀进程，目标系统 API 可用性必须实机检查。 |
| [Sources/vRemote/AudioPipe.swift](../Sources/vRemote/AudioPipe.swift) | 单例输出管线：枚举/选择虚拟设备、16-bit PCM 增益与重采样、缓冲、CoreAudio IOProc、资源租约、1 秒测试音、设备监听及诊断；包含通用 Mac capture 代码但当前产品禁用。 | 路由、音质、资源泄漏和终止失败在此排查；渲染锁与设备 start/stop 锁分离，禁止在 render callback 内直接销毁输出。 |
| [Sources/vRemote/AudioResourceLease.swift](../Sources/vRemote/AudioResourceLease.swift) | 纯资源所有权策略：session/testTone 加 generation Token，过期回调不能释放新租约；shouldCaptureMac 要求启用、活跃会话和 session owner 同时成立。 | 所有资源完成/超时交叉问题先补租约单测；模型通过不等于真实 IOProc 已销毁。 |
| [Sources/vRemote/AudioRouteConfiguration.swift](../Sources/vRemote/AudioRouteConfiguration.swift) | AudioRouteIssue 以类型化原因/系统错误码区分用户消息和展开诊断，AudioOutputRoute 保存 UID、名称、格式与问题，换语言不改变路由身份；保存 UID 和 0–20 倍增益，默认 10；仅首次选择默认 vRemoteDr 2ch，生成 440 Hz、1 秒、约 -20 dBFS 带淡入淡出测试音。 | 修改路由默认值和增益/测试音时改；保存空 UID 表示用户明确关闭，不得自动切换到扬声器或其他设备。 |
| [Sources/vRemote/WavRecorder.swift](../Sources/vRemote/WavRecorder.swift) | 可选开发录音：createNext 生成时间戳文件名，保存单声道 16-bit WAV 与原始 ATVV .raw.bin，close 回写 RIFF 长度并关闭句柄。 | 仅在明确启用调试录音时创建；当前 WAV header 固定 16 kHz，若验证 8 kHz codec 应专门检查录音标签，不把其当通用采样率导出器。 |

### 4.4 物理键盘与普通按键映射

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/InputTrigger.swift](../Sources/vRemote/InputTrigger.swift) | Option/Command/Control/Shift/Fn 键码与 flags；Key.triggerDown/up/tap 通过 CGEvent 发出修饰键，并设置 syntheticMarker 防止被自家观察器当成真实输入。 | 改变快捷键或发键时查 controller 的按下/释放所有权；需要辅助功能，Fn 行为仍需目标工具实测。 |
| [Sources/vRemote/KeyboardTriggerState.swift](../Sources/vRemote/KeyboardTriggerState.swift) | 不依赖系统框架的修饰键边沿模型，按左右实体键维护 keysDown，返回一次 down/up；合成标记和非当前触发键被忽略。 | 左右键同时按、flagsChanged 重复或切换触发键后残留问题；由新键盘边沿测试覆盖。 |
| [Sources/vRemote/KeyboardTriggerObserver.swift](../Sources/vRemote/KeyboardTriggerObserver.swift) | 建立 listenOnly CGEvent tap 观察 keyDown/keyUp/flagsChanged，使用 KeyboardTriggerState 排重/过滤自发事件；配置改变重置，stop 显式移除 run-loop source 并失效 tap。 | 改物理键同步或权限恢复路径；它不拦截、不吞掉无关键，start 会先检查 Accessibility。 |
| [Sources/vRemote/RemoteButtonGestures.swift](../Sources/vRemote/RemoteButtonGestures.swift) | 纯手势识别器 RemoteButtonGestureRecognizer 和配置/事件类型；单击、双击、长按、连发、迟到计时和取消策略，另有应用快捷方式 Codable 元数据。 | 改变 300/550/450/70 ms 时序或冲突优先级从这里开始；不含真实 timer 或 CGEvent 副作用。 |
| [Sources/vRemote/RemoteButtonMappingController.swift](../Sources/vRemote/RemoteButtonMappingController.swift) | 主线程 ordinary-button 生命周期所有者：按下时快照动作、pressedButtons 锁存、可注入时间与调度、generation 取消，以及按映射变更通知释放旧动作。 | 防卡键/停滚、断连、设置编辑中按住的行为入口；所有 timer 必须由 controller 拥有，不要给每个动作另建失控后台 timer。 |
| [Sources/vRemote/RemoteMappingSupport.swift](../Sources/vRemote/RemoteMappingSupport.swift) | Chromecast profile、15 个按键定义、动作枚举、CGEvent/媒体键/滚动/打开应用、用户映射存储、默认方向长滚动迁移及通知集中在此。 | 新增动作要同时更新存储、手势资格、导入校验、编辑 UI 和回归；voice 永久保留，custom payload 不能变为任意 shell 命令。 |

### 4.5 控制台 引导 权限与配置

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/ChromecastConsoleView.swift](../Sources/vRemote/ChromecastConsoleView.swift) | 七步首次引导与四页设置的 SwiftUI 主视图；真实试用证据、全局语音头、工具/路由/映射/名称/权限/外观/配置备份与确认动作。 | 改用户流程在此及纯进度/证据模型；保持 voiceActive 时配置禁用、停止入口可达，不能把原型模拟逻辑带入真实运行时。 |
| [Sources/vRemote/DebugWindowController.swift](../Sources/vRemote/DebugWindowController.swift) | 原生窗口与 ConsoleViewModel 适配层，包含 PermissionKind、LogoAsset、三语原生 PermissionIllustration、权限说明弹窗、键盘快捷键采集 NSView 桥和共享样式。 | 需要窗口、权限导航、资源回退或原生 key capture 时修改；尽管名称为 Debug，它是当前正式控制台入口。 |
| [Sources/vRemote/ConsoleDesignTokens.swift](../Sources/vRemote/ConsoleDesignTokens.swift) | 共享亮/暗语义色、219 pt 侧栏和页面尺寸，ConsoleCard、ConsoleNotice、主按钮样式、三态外观选择器；支持 Reduce Motion。 | 主题与基础排版优先改 token，不把颜色散落到视图；原生色值契约与批准原型关联。 |
| [Sources/vRemote/ChromecastMappingLayout.swift](../Sources/vRemote/ChromecastMappingLayout.swift) | 照片锚点和双列卡片的纯几何配置：Placement + Metrics，15 个固定 ID、左右顺序、坐标、照片与卡片尺寸及连接点计算。 | 布局偏移/添加实体键从这里检查；同步真实图片与几何测试，不在 UI 中复制另一份坐标。 |
| [Sources/vRemote/ChromecastMappingCanvas.swift](../Sources/vRemote/ChromecastMappingCanvas.swift) | SwiftUI 照片画布、热点、连接线、三格手势卡片、保留语音卡片、实际输入高亮；ChromecastMappingPhoto 统一读 app bundle 或源码资源。 | 首次引导和遥控器设置共用；改卡片/图片或窄窗横向滚动时跑几何检查，再做 macOS 渲染验证。 |
| [Sources/vRemote/OnboardingProgress.swift](../Sources/vRemote/OnboardingProgress.swift) | 七步进度 schema 2 的保存/迁移；resumedStep 做边界收敛，重启后最多恢复到真实试用步骤，禁止复用上一次录音证据。 | 改变步骤顺序/数量时同时改迁移与 view；保存位置不代表该步骤已通过。 |
| [Sources/vRemote/OnboardingSpeechEvidence.swift](../Sources/vRemote/OnboardingSpeechEvidence.swift) | canComplete 只在 armed、新 PCM 包、新结束会话、当前非活跃、路由/连接有效、非空文字且用户确认同时满足时为真。 | 新增试用条件先加纯测试；文字不是自动验证过的转写，程序只能验证传输事实和用户确认。 |
| [Sources/vRemote/PermissionRequestSupport.swift](../Sources/vRemote/PermissionRequestSupport.swift) | 当前仅 Bluetooth/Accessibility/Input Monitoring 三种可申请权限；PermissionRequestGate 区分已授权、未判定、未获准、拒绝、受限/未知，并限制重复请求。 | 权限状态语义/重复按钮行为改此模型；Bool false 不能虚构成系统“明确拒绝”。 |
| [Sources/vRemote/MacPermissionRequester.swift](../Sources/vRemote/MacPermissionRequester.swift) | @MainActor 系统申请适配器：AXIsProcessTrustedWithOptions、CGRequestListenEventAccess，以及为 Bluetooth 创建并保留 CBCentralManager；申请后重新读状态。 | 只由明确申请按钮调用；刷新/计时器只读，不可自动请求 Mac 麦克风，也不能把 requested 当 granted。 |
| [Sources/vRemote/ChromecastSettingsArchive.swift](../Sources/vRemote/ChromecastSettingsArchive.swift) | 原生 v1 plist 的白名单、snapshot/restore/exportData/validate；大小、数量、类型、按键、枚举、payload、路径和语音配置验证，兼容过滤已知历史字段。 | 新增可备份偏好必须显式入白名单并补恶意/异常档案测试；先 validate 再确认再 restore，不触及配对/权限/录音/日志/登录项。 |
| [Sources/vRemote/RemoteDisplayName.swift](../Sources/vRemote/RemoteDisplayName.swift) | 只在 app 内展示的昵称；trim、最多 64 个 Swift Character / 4096 UTF-8 bytes，拒绝控制/换行/显式文字方向控制，空值恢复默认名。 | 修改命名规则同步导入和测试；不能拿 displayName 做 HID/BLE 匹配，也不会重命名系统蓝牙设备。 |

### 4.6 三语应用字符串资源

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Sources/vRemote/Resources/en.lproj/Localizable.strings](../Sources/vRemote/Resources/en.lproj/Localizable.strings) | 英文应用文案表，以 console、shell、support 等稳定语义 key 覆盖页面、菜单、状态、错误、帮助和无障碍文字；{0} 等表示可重排动态参数。 | 新增 key 同步另外两表与占位；作为英文/缺失语言回退来源，资源内容不修改设备名、路径或用户输入。 |
| [Sources/vRemote/Resources/zh-Hans.lproj/Localizable.strings](../Sources/vRemote/Resources/zh-Hans.lproj/Localizable.strings) | 简体中文应用文案表，与英文和繁体共用 key，包含首次引导、设置、确认框、系统适配错误和语音状态。 | 日常文案优先在这里编辑中文，同时更新繁体/英文；不可只把 literal 直接塞回 Swift 视图。 |
| [Sources/vRemote/Resources/zh-Hant.lproj/Localizable.strings](../Sources/vRemote/Resources/zh-Hant.lproj/Localizable.strings) | 繁体中文应用文案表，支持明确选择繁体，以及系统 zh-Hant/TW/HK/MO 解析。 | 同 key/占位契约；用自然繁体用语并检查长文案、VoiceOver 和安全确认，不仅做机械字形替换。 |

## 5 大文件内部阅读地图

大文件不建议整体“顺手重构”。先定位职责、列出回调和资源所有权，再为行为补测试。以下使用真实类型/函数名而非易漂移的固定行号。

### 5.1 main.swift

- AppController 成员区集中持有 HID、BLE、keyboard observer、Doubao monitor、voice controller 和窗口，构造 BLEBridge 时传入名称提示、保存文件名、录音前缀与物理边沿模式
- applicationDidFinishLaunching 先初始化本地偏好与外观、禁用 Mac input，再创建菜单并连接生产回调；检查语音问题时从 onAudioStarted/onAudioStopped/onPCMReceived 和 onMicrophoneOpenRequested 这组接线向两边追踪
- makeControlMenu/makeLogMenu/makeRecordingMenu/makeLanguageMenu 只组织菜单项；实际操作由 selector 进入开关、打开目录、明确清空、重启/退出；语言选择通过 appLanguageDidChange 原地刷新菜单，不重启应用
- updateStatus 聚合双通道连接、工具录音、路由和显示名称；updateMenuVoiceIndicator 独立根据 PCM freshness 更新图像、tooltip 与 accessibility label
- wireDebugWindow 将窗口动作连回生产服务；重新连接、语音配置变动、触发键变动和映射开关应在这里看是否完整传递
- stopMicrophoneNow、restartAppNow、applicationWillTerminate 是资源清理的重要路径；文件末显式把 SIGTERM 接入 NSApp 终止流程

### 5.2 ChromecastConsoleView.swift

- ChromecastSettingsPage 定义四个导航目标；主 body 组织 sidebar、全局 header、滚动内容、操作提示、引导 footer 和 sheet，并监听证据失效条件
- 视图内 @State 是当前编辑/引导状态，ConsoleViewModel 是跨页生产快照；ConsoleMessage 保留反馈的语义 key/格式化参数，使换语言后错误继续存在。不能用临时 @State 代替真正会话状态
- onboardingContent/settingsContent 分发页面；映射页直接复用 ChromecastMappingCanvas，不使用 HTML 第六步的非交互占位
- prepareView/beginSetup/saveSetupBackup/cancelSetup 负责引导快照与恢复；OnboardingProgress 才是恢复步骤的兼容策略
- armSpeechTest/invalidateTest 与 OnboardingSpeechEvidence 负责当前试用，configuration、route fingerprint、断连、错误、文字编辑会更新其有效性
- saveVoiceConfiguration/chooseVoiceApplication/launchVoiceTool/saveRemoteName 是具体配置边界；昵称使用保存动作，不随每个键入改蓝牙身份
- exportSettings/importSettings/resetSettings/confirmResetMappings 共用 confirmReplacement 的取消/先导出/明确替换循环，导出成功本身不授权替换
- ChromecastGlobalVoiceHeader 使用 controller 的 elapsed 与真实状态，持续给出停止入口；ChromecastGestureEditor 编辑选中按钮/手势；ChromecastHelpLabel 提供辅助说明

### 5.3 DebugWindowController.swift

- PermissionKind 汇总系统设置 URL、标题、分步说明及是否可由当前版本申请；pageCount 来自 guidance，帮助条目不等于当前需要申请的权限
- LogoAsset 从 App 包的 AppIcon.png 或开发路径 Resources/AppIcon/placeholder-app-icon.png 读取通用占位图；缺图时用几何图形绘制回退，不含旧品牌字母。旧 GuideAsset 与截图读取路径已移除
- ConsoleViewModel 的 @Published 字段把生产连接/电平/权限/会话传给 SwiftUI；refreshPermissions 是读取，requestPermission 才调用 MacPermissionRequester
- DebugWindowController 建立 1160×820 窗口，最小 1080×720，以 NSHostingView 承载主视图；show 时重查权限并开启 1.5 秒只读刷新，windowWillClose 停 timer
- update、voiceStateChanged、receivedAudioPacket、voiceSessionEnded、observedButton 是主程序的数据适配入口，普通按钮高亮 0.25 秒后复位
- KeyboardShortcutCaptureView → KeyboardEventCaptureView → KeyboardCaptureNSView 桥接真实按键采集，生成 RemoteCustomShortcut；这是采集快捷键定义，不是录音触发逻辑
- PermissionGuideView/PermissionIllustration 在三种语言中统一显示明确标注的原生示意，使用本地化标签和导航箭头；它不是实际系统截图，示意中的开关也不设置系统权限。vRemoteDr 2ch 仍是实际技术路由名。ConsoleTheme/ConsoleButtonStyle 提供共享原生辅助界面样式

### 5.4 AudioPipe.swift

- Public input API：feed 将 Int16 转 Float、应用增益与限幅；setRemoteActive 才取得/释放输出，setInputEnabled 同步内存与偏好；当前入口始终禁用 Mac
- Route configuration：refreshOutputRoutes/selectOutputRoute 用 UID 重新发现，验证格式并绑定属性监听；路由丢失触发 onResourcesInvalidated，不能悄悄选另一输出
- Test tone：playTestTone 取得独立 lease，render 消耗完后把 finishTestTone 派发到 main queue，另有 2 秒兜底；token 防止关闭新会话
- Built-in microphone capture：保留 AVCaptureSession 适配与授权代码，受启用状态和 lease 检查控制；产品入口关闭这条路径。改动此块需谨慎核对产品/隐私边界
- Schedule/resample：以 routeGeneration 防止旧缓冲入新输出；线性重采样到当前设备采样率；缓冲压缩/裁剪控制堆积
- CoreAudio direct output：startOutputDevice 创建/启动 IOProc，stopOutputDevice 停止并销毁、使租约失效、清缓冲；销毁失败保留句柄以便重试，不能假装释放成功
- Render：先清零输出、取 tone 或 PCM、限幅并复制到输出声道；routeLock 与 stateLock 分离，防止在持有渲染状态锁时等待 CoreAudio 停止造成死锁
- Discovery/listeners/diagnostics：读取设备/stream 格式、监听设备和绑定路由变化；MIA_DIAGNOSTICS=1 才开启额外诊断，默认没有持续详细 PCM dump

### 5.5 BLEBridge.swift

- start/stop 与 tryDirectConnect/beginScan/connect/matches 管理发现和连接；saved UUID 只是重连优化，仍受名称匹配约束
- centralManager/peripheral delegate 管理设备状态、服务/特征发现、notify 与读写返回
- openMicrophone/closeMicrophone 向协议层要命令，并由 RemoteMicrophoneOpenResult 把“已发、已经 streaming、稍后重试、不可用、失败”传给 controller
- handleControl 把 ATVV event 接入 transport lifecycle；合法 START 才初始化解码/录音/保活与通知；STOP 区分物理释放、完整结束和只本地清理
- handleAudio 只在接受 PCM 时处理非空解码帧，首先发布真实包证据，再统计电平/削波、可选写 WAV/raw 并 feed 音频输出
- finishAudioStreamLocally 统一结束本地流、录音和电平；stopKeepAliveTimer/close timeout/stream generation 要一起考虑，避免旧动作续开新会话

### 5.6 RemoteMappingSupport.swift

- SupportedRemoteID/RemoteProfiles 定义当前唯一型号和物理按键；普通键的 ID 与 HID usage、布局 Placement、归档校验必须一致
- RemoteMappingTarget 负责稳定存储 ID、标题、键盘/媒体映射、滚动和 Command+Tab 事件；applicationSwitchEvents 先完整构造四事件再投递，避免分配失败留下修饰键
- RemoteCustomShortcut 保存键码、flags 和标签；RemoteApplicationShortcut 保存已选 .app 的路径/名字/可选 Bundle ID，未提供脚本/命令执行动作
- RemoteMappingAction 统一 payload、title、repeat/continuous 能力与 post；应用启动错误写入 store 的 lastActionError 供 UI 展示
- RemoteMappingStore 维护每型号/每键/每手势的 UserDefaults，changed 通知 controller 取消当前动作；reset 仅处理当前型号
- installUncustomizedDirectionDefaults 只给完全未自定义方向键加入对应长按滚动。任何存储 action、payload、repeat（包括显式 disabled）都会阻止覆盖，不能仅检测单击映射

## 6 自测目录逐文件说明

这些是由脚本挑选生产文件与测试入口后执行的独立 Swift 程序，并非 XCTest target。测试里有刻意简化的平台替身；它们可以证明业务决策和事件顺序，却不能证明真实系统调用、权限或目标应用交互。

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [SelfTests/AppAppearanceControllerTests.swift](../SelfTests/AppAppearanceControllerTests.swift) | 真实 NSApplication、已有 NSWindow/NSHostingView 与新 panel 的外观继承，反复切换并撤销 system override。 | 仅 macOS 聚合分支执行；仍需真实视觉可读性检查。 |
| [SelfTests/AppAppearanceTests.swift](../SelfTests/AppAppearanceTests.swift) | 独立 UserDefaults 的 system 缺省、非法值回退、三个模式保存与重置。 | 由模型聚合运行；不创建 AppKit 窗口。 |
| [SelfTests/AudioResourceLeaseTests.swift](../SelfTests/AudioResourceLeaseTests.swift) | runAudioResourceLeaseTests 覆盖 idle 无 owner、测试音不拥有 capture、旧 token 不能停止新会话、失效与重复释放。 | 被语音测试主程序调用，不能只把文件编译成独立入口。 |
| [SelfTests/AudioRouteConfigurationTests.swift](../SelfTests/AudioRouteConfigurationTests.swift) | 增益默认/边界/非有限值、UID 保存与显式关闭、缺失已选路由不替代、一秒测试音长度/淡入淡出与采样率边界。 | 模型聚合执行；没有真实设备操作。 |
| [SelfTests/ChromecastArchiveTests.swift](../SelfTests/ChromecastArchiveTests.swift) | schema/device、字段/类型/长度、别名/外观/应用路径、自定义与应用动作 payload、语音键保护、已知历史字段过滤及旧磁盘值不受影响。 | macOS 聚合执行，使用真实 archive/store 加最小系统 stub；导入边界变化必须扩充。 |
| [SelfTests/ChromecastMappingLayoutTests.swift](../SelfTests/ChromecastMappingLayoutTests.swift) | 15 个位置的唯一性、左右排列、尺寸范围与多种画布宽度几何不重叠。 | 模型聚合执行；与 Python 静态检查互补。 |
| [SelfTests/ChromecastVoice/TransportTests.swift](../SelfTests/ChromecastVoice/TransportTests.swift) | TransportHarness 使用生产 ATVVStreamLifecycle 与 ATVVProtocol 模拟控制、PCM、重复边沿和关闭 generation，验证传输安全。 | 被语音主入口调用；关注 close ACK 与 physical release 不可混淆。 |
| [SelfTests/ChromecastVoice/main.swift](../SelfTests/ChromecastVoice/main.swift) | 语音测试总入口与 VirtualScheduler/Harness；使用生产 controller/state machine/contracts，用最小平台替身记录路由/发键/豆包状态。覆盖四种模式、重试、首 PCM、安全超时、尾音和最终脉冲、旧回调隔离与停止确认。 | 根语音脚本执行并可重复 20 次；不是录音、蓝牙或真实快捷键集成测试。 |
| [SelfTests/DockVisibilityTests.swift](../SelfTests/DockVisibilityTests.swift) | 无偏好默认隐藏、读写切换、持久化与重置。 | 模型聚合；不验证 activation policy 实际焦点。 |
| [SelfTests/Gestures/README.md](../SelfTests/Gestures/README.md) | 普通按键测试运行方法、单/双/长/连发时序、迁移/取消/滚动与 Command+Tab 契约及实机边界。 | 维护手势规则时同步；历史措辞不应被理解成当前有可见 Undo 功能。 |
| [SelfTests/Gestures/RemoteButtonGestureTests.swift](../SelfTests/Gestures/RemoteButtonGestureTests.swift) | 纯识别器：默认即时、双击截止、长按、第二击长按、连发冲突、迟到不爆发、release 不补发、取消、连续长滚动。 | Tools/run-gesture-tests.sh 跨平台分支执行。 |
| [SelfTests/Gestures/RemoteButtonMappingControllerTests.swift](../SelfTests/Gestures/RemoteButtonMappingControllerTests.swift) | FakeScheduler/OutputRecorder/Fixture 检验默认方向迁移、按住连续滚动、迟到/已取消回调、编辑/禁用/断连/睡眠，以及平衡 Command+Tab 和滚动 CGEvent 构造。 | 仅 macOS；CGEvent 只构造/检查不 post，仍需真实应用滚动和切换验收。 |
| [SelfTests/Gestures/RemoteMappingStoreTests.swift](../SelfTests/Gestures/RemoteMappingStoreTests.swift) | 真实偏好 store 的单/双/长 payload、旧快捷键兼容、语音键写保护、repeat 冲突、重置与历史偏好隔离。 | 仅 macOS；使用测试 defaults，不应修改用户真实映射。 |
| [SelfTests/KeyboardTriggerStateTests.swift](../SelfTests/KeyboardTriggerStateTests.swift) | 左右修饰键、flagsChanged、重复 down/up、非触发键、自发事件过滤、reset 与不同触发键。 | 模型聚合；不需要 CGEvent tap 或权限。 |
| [SelfTests/MenuBarVoiceReceptionTests.swift](../SelfTests/MenuBarVoiceReceptionTests.swift) | 真实 PCM 到达、streaming/phase 限制、0.75 秒边界、计时倒退、结束清空与新会话隔离。 | 模型聚合；不渲染菜单栏图标。 |
| [SelfTests/OnboardingEvidenceTests.swift](../SelfTests/OnboardingEvidenceTests.swift) | 逐个剔除 fresh PCM、结束会话、连接/路由、确认、文字等条件，确保手打文字本身不能通过。 | 模型聚合；不证明文字确实由识别产生，那一步仍是用户确认。 |
| [SelfTests/OnboardingProgressTests.swift](../SelfTests/OnboardingProgressTests.swift) | 旧步骤到新七步迁移、越界收敛、较后阶段恢复到试用以及进度保存。 | 模型聚合；改步骤结构必须同步。 |
| [SelfTests/PermissionRequestTests.swift](../SelfTests/PermissionRequestTests.swift) | 已授权、首次请求、重复点击、之前拒绝、受限/未知及外部授权变化的 gate 决策。 | 模型聚合；不弹出 macOS 授权框。 |
| [SelfTests/RemoteDisplayNameTests.swift](../SelfTests/RemoteDisplayNameTests.swift) | 默认/trim/空值、中文/emoji/组合字符、长度和 UTF-8 上限、控制/方向字符、持久化/损坏值与 reset。 | 模型聚合；不是蓝牙重命名测试。 |
| [SelfTests/VoiceApplicationLauncherTests.swift](../SelfTests/VoiceApplicationLauncherTests.swift) | 伪环境验证已选应用、运行中激活、注册与安装候选、移动/缺失/非法应用、异步成功失败、旧配置解码。 | 由 test-voice-launcher.sh 运行；不启动实际应用。 |
| [SelfTests/VoiceSessionPresentationTests.swift](../SelfTests/VoiceSessionPresentationTests.swift) | 类型化阶段、真正录音时间、跨页一致、停止状态、时间冻结、错误保留/针对性恢复与新会话重置。 | 模型聚合；防止状态文案或 cleanup 掩盖根本错误。 |
| [SelfTests/main.swift](../SelfTests/main.swift) | ATVV 基线可执行入口：能力和命令、解码连续性、重复 AUDIO_START 清理、START 前新 AUDIO_SYNC 保留以及旧同步不泄漏。 | 由根 run-self-tests.sh 运行。 |
| [SelfTests/LocalizationTests.swift](../SelfTests/LocalizationTests.swift) | 真实三语资源加载、系统语言脚本/地区解析、四种偏好值、非法值回退、不改 AppleLanguages、key parity、通知/LanguageStore revision，以及占位安全和语音/路由状态换语种不变。 | Tools/test-localization.sh 执行；测试临时偏好并恢复标准语言值；不取代三语原生排版、系统弹窗与目标工具验收。 |

## 7 开发工具逐文件说明

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Tools/check-app-bundle.py](../Tools/check-app-bundle.py) | 检查传入 App 实际结构、plist 身份、Mach-O magic/可执行位、ICNS 容器、占位图/本地化与三份许可逐字节一致，拒绝旧品牌、帮助截图及推广/依赖资源。 | 在真实 package-app 之后跑；仅文件格式头和内容验证，不替代 codesign、运行、驱动和 GPL 合规检查。 |
| [Tools/check-mapping-layout.py](../Tools/check-mapping-layout.py) | 无 macOS 的源码/数学契约：15 个唯一位置、左右顺序、锚点范围、多宽度卡片/图片间距、横向滚动和内联编辑入口。 | 适合快速发现布局结构退化；通过不代表 Swift 编译或像素不重叠。 |
| [Tools/check-native-interface.py](../Tools/check-native-interface.py) | 源码契约核对七步、四设置页、颜色与当前中性原型、真实试用门槛、停止/计时/确认、remote-only 启动顺序、侧栏对齐和实际 PCM 绿点。 | UI/流程变更时同步契约；多数检查为字符串和正则，必须另外编译/渲染。 |
| [Tools/check-runtime-cleanup.py](../Tools/check-runtime-cleanup.py) | 检查已移除运行时/推广内容不回流，中性公共组件仍在、无外部包依赖、listen-only 安全、当前权限声明及署名/许可打包等。 | 重构/依赖/清理改动后运行；故意保留历史名字作为“必须不存在”的断言，不是活跃支持。 |
| [Tools/hid-report-probe.swift](../Tools/hid-report-probe.swift) | 独立开发诊断 Probe：用两个十六进制参数匹配 HID，注册设备 report callback，按时间打印报告 ID、长度和原始 bytes，运行 CFRunLoop。 | macOS 上以 swift Tools/hid-report-probe.swift 18d1 9450 使用；可能需要 Input Monitoring，不测试音频，不上传报告。 |
| [Tools/run-gesture-tests.sh](../Tools/run-gesture-tests.sh) | 先跑跨平台纯手势，在 Darwin 再编译映射存储及 controller/非投递 CGEvent 测试；非 macOS 明确输出 SKIP。 | 按键动作和生命周期改动的定向入口；需 Swift 5.9+，不发真实按键或启动应用。 |
| [Tools/test-chromecast-models.sh](../Tools/test-chromecast-models.sh) | 模型回归聚合入口，显式 swiftc 编译菜单绿点、键盘、权限、几何、音频、Dock、外观、名称、手势、展示、引导、语音和 launcher；Darwin 增加 AppKit 外观/归档。 | 新增 SelfTests 文件不会自动执行，必须挂进这里或其子脚本再进 CI；产物在 .build/chromecast-tests。 |
| [Tools/test-package-contents.py](../Tools/test-package-contents.py) | 临时隔离 fixture 用假 swift/ditto/sips/iconutil/xattr/codesign 检查干净及脏目录重建；还验证 checker 拒绝假二进制、变更许可与旧资源。 | 需要 Python 3 + zsh，可在 Linux 跑；产生的 fixture 不是可用 App，结束自动清理。 |
| [Tools/test-voice-launcher.sh](../Tools/test-voice-launcher.sh) | 编译生产配置/launcher 与伪环境单测，产出 .build/chromecast-tests/voice-launcher。 | 打开工具的定位/激活/错误逻辑定向入口；没有真实 LaunchServices 和目标工具验收。 |
| [Tools/test-localization.sh](../Tools/test-localization.sh) | 把三语 .lproj 复制到 .build/localization-tests，swiftc 编译生产 Localization/VoiceSessionPresentation/AudioRouteConfiguration 与独立测试，运行真实目录资源加载。 | Swift 5.9+；缺编译器退出 127。重点验证可执行文件能读到语言表和切换保持状态；不是纯文本 key 检查。 |
| [Tools/check-localization.py](../Tools/check-localization.py) | 离线扫描三语 .strings 的格式/重复/空值/key 与位置/printf 占位一致性、权限文本 parity、Swift 源码 literal/语义 key 覆盖，以及原地刷新/资源入口契约。 | Python 3、无需 Mac；允许明确日志/协议/用户数据边界，不证明译文自然度、Swift 编译或原生视觉；新增文案应扩充三表而非绕过扫描。 |
| [Tools/check-branding.py](../Tools/check-branding.py) | 核对三语显示名/元数据、通用图标、原生帮助示意、旧资源移除和中性 DMG 卷名；锁定兼容 namespace token、历史 v8 与根 LICENSE 的 SHA-256，保留 ATVV/第三方署名与原型存储标识。 | 品牌/资源变更后运行；只验证脚本列明的契约，不能证明所有素材权利、最终品牌、原生显示或 macOS 身份迁移已获确认。 |
| [Tools/generate-placeholder-icon.py](../Tools/generate-placeholder-icon.py) | 仅用 Python 标准库绘制 1024×1024 RGBA PNG：圆角底板、通用遥控器与圆形按钮，无字体或外部图像输入；默认写入 Resources/AppIcon/placeholder-app-icon.png。 | 修改几何或颜色后重新生成；--check 重新渲染并逐字节比较，不改文件。不将开发占位图视为最终品牌或权属证明。 |

## 8 打包与实验驱动逐文件说明

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Driver/README.md](../Driver/README.md) | 实验 HAL 驱动的背景、复制后改身份/transport 的过程、并行安装边界及 GPL/对应源码/来源问题。 | 任何驱动操作前必读；明确当前是二进制补丁，不是可复现源码构建。 |
| [Driver/build-driver.sh](../Driver/build-driver.sh) | 复制已安装 BlackHole2ch.driver 到 Driver/build，通过等长 Perl 二进制替换修改 UID/品牌/设备 transport，并修改 plist factory UUID、临时签名与架构检查。 | 不改变原 BlackHole，但覆盖 Driver/build；未固定输入版本/哈希，硬编码替换依赖特定二进制布局，不能当任意改名器。 |
| [Driver/install-driver.sh](../Driver/install-driver.sh) | 把生成驱动复制到系统 HAL 目录，存在时拒绝覆盖，设置 root:wheel/755/644 并重启 coreaudiod。 | 需要管理员权限并影响系统音频；运行前验证来源、权限和明确安装意图。 |
| [Driver/uninstall-driver.sh](../Driver/uninstall-driver.sh) | 删除指定 vRemoteDriver.driver 并重启 coreaudiod。 | 只针对该驱动，但仍是系统删除及音频中断；不是文档/测试任务需要执行的命令。 |
| [Packaging/Info.plist](../Packaging/Info.plist) | App 显示名 Remote Voice Utility、图标 AppIcon.icns、executable vRemote、bundle ID local.simaqingfeng.vRemote、版本 1.1.1/build 111、macOS 12、LSUIElement 及 Bluetooth/Input Monitoring 用途声明；列出三种本地化，当前无 Mac 麦克风用途声明。 | 身份/权限/最低系统变更时同步签名 requirement、登录项、安装脚本与迁移；系统权限文本在对应 InfoPlist.strings，应用文案在 Sources 的 Localizable.strings。 |
| [Packaging/en.lproj/InfoPlist.strings](../Packaging/en.lproj/InfoPlist.strings) | 英文占位显示名及 Bluetooth 与 Input Monitoring 系统用途描述，打包到 Contents/Resources/en.lproj。 | 系统弹窗文案随实际行为同步；不是整套应用英文翻译资源。 |
| [Packaging/pkg-scripts/postinstall](../Packaging/pkg-scripts/postinstall) | PKG 安装后修复驱动属主/目录/文件权限，重启 coreaudiod，结束旧 vRemote，并尝试以控制台用户启动 /Applications/vRemote.app。 | 执行具有系统音频中断、进程终止和程序启动副作用；只有安装 PKG 才运行，不属于 app-only 测试。 |
| [Packaging/zh-Hans.lproj/InfoPlist.strings](../Packaging/zh-Hans.lproj/InfoPlist.strings) | 简体中文占位显示名及 Bluetooth 与 Input Monitoring 系统用途描述，解释遥控器接收与配置快捷键观察。 | 与英文及 Info.plist 一起修改；不要恢复当前不申请的 Mac capture 声明。 |
| [Packaging/zh-Hant.lproj/InfoPlist.strings](../Packaging/zh-Hant.lproj/InfoPlist.strings) | 繁体中文占位显示名及 Bluetooth 和 Input Monitoring 系统用途描述，随 App 包进入 zh-Hant.lproj。 | 仅系统权限用途文字；跟随真实行为、与简中/英文一致，不申请 Mac 麦克风。 |

### 8.1 产物如何形成

```text
Package.swift + Sources → swift build -c release → .build/release/vRemote
                                       ↓
Packaging + 活动 Resources + 通用占位图 + 三份许可
                                       ↓
package-app.sh → dist/build/vRemote.app（开发临时签名）
              ├→ install-app.sh → 用户 Applications 中替换 App
              ├→ build-dmg.sh → app-only DMG
              └→ build-pkg.sh + Driver/build-driver.sh
                    → App + HAL driver PKG → postinstall 系统操作
```

源码运行可能通过相对路径加载图；可分发 App 必须依赖 Contents/Resources 中实际复制的资源。当前 package-app 不会把整个 Resources 无差别打入包：只复制活动遥控器图、占位 PNG/生成的 ICNS、三语字符串表/权限文本和指定许可；PermissionGuides 目录不再随包复制。已删除的 Design 品牌资产没有运行时入口，HTML 原型、源码与测试也不会自动成为 App 内容。

### 8.2 执行风险分级

| 命令类别 | 主要副作用 | 应如何使用 |
| --- | --- | --- |
| 源码/几何/原型检查 | 只读源码；原型在伪环境执行 | 可作为日常快速回归 |
| Swift 测试/编译 | 写 .build 或临时测试目录 | 不需要真遥控器，但系统框架测试限 macOS |
| package-app / DMG / PKG 构建 | 删除重建指定生成目录/同版本产物，临时签名 | 先确认未把唯一有价值文件放在生成目录；PKG 仍有驱动发布阻塞 |
| install-app | 覆盖已有用户 App | 明确决定升级/替换后再运行 |
| Driver install/uninstall / PKG postinstall | 系统 HAL 写删、改权限、重启音频服务，PKG 还终止/启动 App | 需管理员与明确授权，可能打断当前录音/通话；不属于自动文档验证 |
| LaunchAtLogin | 写删用户持久 LaunchAgent、调用 launchctl | 用户主动开关后执行；归档导入不隐式更改 |
| generate-placeholder-icon.py | 默认重写指定的占位 PNG；--check 只比较 | 仅在有意更新几何图标时生成，提交前核对源码与 PNG 一致 |

## 9 图片与其他资源逐文件说明

当前保留的独立图片只有通用开发占位图与活动遥控器图。权限及语音工具帮助在三种语言中均使用原生、本地化的示意控件，不再读取继承截图。文件格式和尺寸只是工程事实，不构成资产许可或最终品牌批准。

### 9.1 当前资源

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [Resources/AppIcon/README.md](../Resources/AppIcon/README.md) | 通用占位图的用途、生成来源与重建/检查入口，说明它替代旧品牌图但不是最终产品标识。 | 最终命名、图标或生成方式变化时同步；新贡献者署名与资产来源需要明确，不自行改写继承版权。 |
| [Resources/AppIcon/placeholder-app-icon.png](../Resources/AppIcon/placeholder-app-icon.png) | 1024×1024 RGBA PNG，由 Tools/generate-placeholder-icon.py 确定性生成；几何遥控器与圆形按钮，不含旧品牌字母。打包复制为 AppIcon.png，再生成 AppIcon.icns；LogoAsset 开发模式也直接读取。 | 修改生成源码后重建并运行 --check；核对 Dock、菜单栏、深浅外观及最小尺寸。实际显示与发布权利仍须独立审查。 |
| [Resources/PermissionGuides/README.md](../Resources/PermissionGuides/README.md) | 说明八张继承的 macOS/豆包截图已删除；三语帮助改由 DebugWindowController.swift 的 PermissionIllustration 和语言表绘制，示意不承诺与系统版本逐像素一致。 | 帮助流程变化时更新原生示意与三份文案，再实测可读性、Light/Dark 和 VoiceOver；不要为旧缺图回退恢复已移除截图。 |
| [Resources/RemoteImages/chromecast-front-and-volume-enhanced.png](../Resources/RemoteImages/chromecast-front-and-volume-enhanced.png) | 当前唯一原生遥控器图，1024×1536 RGBA PNG；正面与侧音量示意共同支撑 mapping 和语音键照片。来源/权利与物理准确性仍需发布前确认。 | 替换必须保持或重做 normalized anchors、比例和命中区，并运行几何检查与实机照片核对；package-app 只复制此遥控器图。 |

### 9.2 移除资产与历史边界

- 原 Design/vRemoter-Logo-v1 的 21 个文件（Figma 插件、说明/启动器、v5–v9 App 图标与 v2–v9 预览导出）已从当前树移除，不再提供旧品牌打包或开发回退入口
- Resources/PermissionGuides 中八张权限/豆包帮助图已移除；目录仅留说明。此前部分扩展名为 PNG 而内容为 JPEG 的文件也因此不属于当前资源，不能继续把它们列为随包内容
- 已交付的历史 v8 HTML 按原字节保留，可能仍含旧品牌及内嵌设计元素；当前中性副本沿用该布局、图片和交互，不能因改显示名称就断言所有图形为全新原创
- 代码来源、MIT 作者头与第三方通知继续保留。移除图片不等于移除继承实现的署名义务；照片、最终图标、贡献署名和技术身份迁移仍见发布审查及 TODO

## 10 工程文档与原型逐文件说明

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [docs/CHROMECAST_ACCEPTANCE.md](../docs/CHROMECAST_ACCEPTANCE.md) | 当前候选版本的待验收清单：构建包、权限连接、实际语音、按键/UI、设置/隐私、失败路径与发布准备。 | 在确实完成精确版本/设备/系统验收后记录证据；未勾选项不能用源码或原型测试代替。 |
| [docs/CHROMECAST_SCROLL_ACTIONS.md](../docs/CHROMECAST_SCROLL_ACTIONS.md) | 真实照片映射布局、普通键动作、方向长滚动迁移、时序与生命周期安全及对应实机验收。 | 修改键表、坐标、CGEvent、滚动速度/阈值时同步。 |
| [docs/CLEANUP_REVIEW.md](../docs/CLEANUP_REVIEW.md) | 本轮删减范围、保留公共组件、旧档案迁移、已合并文档的去向、打包通知及尚待审查事项。 | 再次清理时核对，避免删除仍供 Chromecast 使用的共享能力或把旧偏好擦掉。 |
| [docs/NATIVE_INTERFACE_IMPLEMENTATION.md](../docs/NATIVE_INTERFACE_IMPLEMENTATION.md) | 基于已批准布局的原生架构、信息结构、真实试用、安全边界、可访问性、主题/Dock/名称、工具启动、归档兼容和升级禁用 Mac capture 的综合说明；三语细节见 LOCALIZATION.md。 | 改原生 UI 或生命周期时更新；设计版本以实际归档 HTML 和最新原型说明为准，不能由旧标题推断当前文件版本。 |
| [docs/PERMISSION_REQUESTS.md](../docs/PERMISSION_REQUESTS.md) | 权限查询和申请 API、明确按钮与重查/重连区别、App 身份/TCC、打包与原生验收边界。 | 权限失败排障入口；不能照终端已授权状态推断打包 App 也被授权。 |
| [docs/PROJECT_OWNERSHIP_AND_LICENSES.md](../docs/PROJECT_OWNERSHIP_AND_LICENSES.md) | 代码/资产来源、参考与替换账、MIT 通知、BlackHole GPL 与对应源码阻塞、品牌/图标/包/签名/登录项/驱动身份决策表。 | 发布、改名、引入资产/参考代码、驱动分发之前必读；是工程审查记录，不是法律合规批准书。 |
| [docs/chromecast-audio-resource-lifecycle.md](../docs/chromecast-audio-resource-lifecycle.md) | 输出/capture lease、测试音、首 PCM、尾音/停止、目标状态确认及 macOS 系统麦克风指示区别。 | 音频资源/卡键/停止错误改动时读；橙色系统指示可能来自另一个录音进程。 |
| [docs/prototypes/README.md](../docs/prototypes/README.md) | 区分当前中性副本与逐字节保留的历史 v8，说明三入口/七步/侧栏/绿点模拟、三语、localStorage/JSON 边界与离线测试方法。 | 核对当前参考和测试入口从此开始；v8 继承批准 v7 布局，名称替换不代表重新批准全部设计或嵌入生产 App。 |
| [docs/prototypes/remote-voice-utility-onboarding-settings.html](../docs/prototypes/remote-voice-utility-onboarding-settings.html) | 当前离线中性原型，从历史 v8 派生，沿用七步/设置布局、三语即时切换和模拟交互；666 个内嵌翻译 key（较历史 v8 增加 1 个占位名 key），可见名称改为三语描述性占位名。图片/CSS/JS 自包含，旧 localStorage 与演示备份标识保留兼容。 | 当前 UI 评审与默认原型回归入口；不请求真实权限，不证明收到 PCM/识别成功。JSON 演示备份与原生 plist 不互通；保留照片/设计来源审查。 |
| [docs/prototypes/test-vremoter-onboarding-settings.cjs](../docs/prototypes/test-vremoter-onboarding-settings.cjs) | Node VM 编译 HTML 脚本，模拟 DOM/localStorage/Blob/语言环境；交互、语言持久化/切换/备份与 v7 继承布局回归历史基线为 81 项，当前中性副本另有 3 项品牌回归、共 84 项；另扫描 183 个英文界面场景。 | Node 18+，无 npm 包/网络；保留脚本名，默认读 remote-voice-utility-onboarding-settings.html，可传文件参数或 VREMOTER_PROTOTYPE_HTML 显式选择；不代替浏览器、SwiftUI 或 PCM。 |
| [docs/prototypes/vremoter-onboarding-settings.html](../docs/prototypes/vremoter-onboarding-settings.html) | 已交付 v8 历史归档，本轮逐字节不变；基于批准 v7 加简体/繁体/英文与 System、即时切换和简化文案，665 个内嵌翻译 key，保留原品牌与演示存储格式。 | 用于历史追溯，不能为通过当前品牌检查而重写；当前 UI 修改应落在中性副本。历史文件存在不等于其旧名称是最终品牌或当前打包资源。 |
| [docs/LOCALIZATION.md](../docs/LOCALIZATION.md) | 三语稳定偏好、系统解析、479 个语义 key/语言、原地刷新、两个资源入口、类型化错误和语言归档保护，以及系统/外部应用/技术诊断/三语原生帮助示意边界。 | 改语言、应用文案、资源打包或热切换时更新；包含静态、Foundation、SwiftPM 与 App executable 验证命令和待完成原生视觉要求。 |

| 文件 | 实际职责与关键实现 | 何时修改及验证边界 |
| --- | --- | --- |
| [docs/REPOSITORY_GUIDE.md](REPOSITORY_GUIDE.md) | 本文：完整目录、逐文件职责、架构与修改/测试导航。 | 新增、移动、删除文件或改变跨模块职责后更新清单、链接与测试矩阵。 |

## 11 测试矩阵与最小验证流程

### 11.1 各入口能证明什么

| 检查入口 | 工具/平台要求 | 主要覆盖 | 无法替代 |
| --- | --- | --- | --- |
| swift build | Swift 5.9+、macOS SDK | 整个 production target 编译链接 | 原生渲染、真实设备/权限/录音 |
| zsh run-self-tests.sh | zsh、swiftc | ATVV/ADPCM 基线 | BLE 回调/特征读写 |
| bash run-chromecast-voice-tests.sh | swiftc、Foundation 可用平台 | 真实 controller + 虚拟调度器、传输与资源策略 | CoreAudio 停毁、真键事件、工具录音 |
| bash Tools/run-gesture-tests.sh | swiftc；部分仅 macOS | 纯手势、macOS store/controller 和非投递 CGEvent | 真实滚动方向、HID cadence、目标应用 |
| bash Tools/test-chromecast-models.sh | swiftc；完整需 macOS | 模型、子测试、archive、AppKit 外观 | 硬件及完整交互验收 |
| bash Tools/test-voice-launcher.sh | swiftc | 注入环境解析/激活/异常 | 真实安装、LaunchServices、工具兼容 |
| python3 Tools/check-mapping-layout.py | Python 3，跨平台 | 位置/顺序/几何与源码契约 | 实际 SwiftUI 像素 |
| python3 Tools/check-native-interface.py | Python 3，跨平台 | 原生 UI 源码与原型/安全集成契约 | Swift 类型检查、绘制/可访问性 |
| python3 Tools/check-runtime-cleanup.py | Python 3，跨平台 | 旧实现移除、公共能力/通知保留 | 生产编译、行为及发行合规 |
| python3 Tools/check-branding.py | Python 3，跨平台 | 占位显示名/图标/帮助示意、旧资源移除、历史 v8/根 LICENSE 哈希、来源与兼容 ID 契约 | 原生渲染、商标/素材权利、最终命名和身份迁移 |
| python3 Tools/generate-placeholder-icon.py --check | Python 3 标准库，跨平台 | 当前 PNG 与确定性生成源码逐字节一致 | macOS ICNS 转换、小尺寸视觉、最终品牌批准 |
| node docs/prototypes/test-vremoter-onboarding-settings.cjs | Node 18+，跨平台 | 当前中性 HTML 的 84 项交互/语言/品牌回归与 183 个英文文案场景；显式历史路径为 81 项 | 浏览器排版、SwiftUI、真实 PCM |
| python3 Tools/test-package-contents.py | Python 3 + zsh，跨平台 | 假工具隔离打包、脏目录重建、检查器拒绝能力 | 真 App、真签名/ICNS 生成、驱动 |
| zsh package-app.sh 后跑 check-app-bundle.py | macOS 工具链 | 真 App 包资源/通知/容器与构建 | Developer ID、公证、安装验收和 GPL |
| git diff --check | Git | 补丁空白错误 | 功能正确性 |
| bash Tools/test-localization.sh | Swift 5.9+，Foundation；Combine 刷新断言在可用平台执行 | 真资源加载、偏好/locale、占位、通知及语音/路由换语种不变 | SwiftPM/App bundle 入口、原生布局与系统权限弹窗 |
| python3 Tools/check-localization.py | Python 3，跨平台 | 三表完整性、占位一致、代码文案/资源刷新契约 | 翻译质量、资源真正加载、Swift/视觉 |
| swift run vRemote --localization-self-test | macOS SwiftPM 构建 | 运行中 executable 从 SwiftPM 资源入口读取三表 | UI、权限、BLE 和语音硬件 |
| App executable --localization-self-test | 已构建的 macOS App | 手工包的 executable 实际找到三表；在创建 App/设备对象前返回 | 原生控件翻译/布局、正式签名与安装 |

### 11.2 日常代码修改后的建议顺序

在仓库根目录执行。先快速静态检查，再在 macOS 跑编译和完整回归；不同脚本的 SKIP/BLOCKED 不能写成 PASS。

```sh
python3 Tools/check-mapping-layout.py
python3 Tools/check-native-interface.py
python3 Tools/check-runtime-cleanup.py
python3 Tools/check-localization.py
python3 Tools/check-branding.py
python3 Tools/generate-placeholder-icon.py --check
node --check docs/prototypes/test-vremoter-onboarding-settings.cjs
node docs/prototypes/test-vremoter-onboarding-settings.cjs
node docs/prototypes/test-vremoter-onboarding-settings.cjs docs/prototypes/vremoter-onboarding-settings.html
python3 Tools/test-package-contents.py
git diff --check
```

macOS 完整开发验证：

```sh
swift build
swift run vRemote --localization-self-test
zsh run-self-tests.sh
VREMOTE_VOICE_TEST_REPETITIONS=20 bash Tools/test-chromecast-models.sh
bash Tools/test-localization.sh
zsh package-app.sh
python3 Tools/check-app-bundle.py dist/build/vRemote.app
dist/build/vRemote.app/Contents/MacOS/vRemote --localization-self-test
```

这组命令会生成构建产物，但不会执行 install-app、驱动安装或发布。SwiftPM target 没有 testTarget，因此不要用一句“swift test 通过”代替仓库实际脚本。新增测试文件也必须加入聚合脚本才会被 CI 运行。

### 11.3 实机验收的最小证据

- 记录确切 commit、macOS、架构、遥控器、输出设备及目标工具版本
- 分别核实 HID/BLE、首次授权和拒绝后的重查/重连、打包 App 的 TCC 身份
- 四种 hold/toggle 组合、真实首 PCM/虚拟输入/识别文本、快速切换与至少 20 次真实启停
- 同时验证声音尾部、所有合成键释放、输出 IOProc 停止、睡眠/断连/路由消失/退出
- 验证菜单绿点只随真实音频、系统橙色指示不能仅凭本地停止就承诺消失
- 对四方向滚动、Command+Tab、IR 键、导入/重置中断、长名称/主题/键盘/VoiceOver 做当前版本验收

完整要求以 [CHROMECAST_ACCEPTANCE.md](CHROMECAST_ACCEPTANCE.md) 为准。本文未把任何未实测项目标为完成。

## 12 常见修改任务从哪里开始

| 想修改什么 | 首先看 | 必须联动 | 建议验证 |
| --- | --- | --- | --- |
| 七步引导/侧栏/页面内容 | ChromecastConsoleView、ConsoleDesignTokens | OnboardingProgress、OnboardingSpeechEvidence、批准原型和原生文档 | 模型+native source checks+macOS 视觉/键盘/VoiceOver |
| 普通键增加动作 | RemoteMappingTarget、RemoteMappingAction | store/gesture capabilities、archive 白名单、editor、文档 | store/controller/CGEvent/归档+真按键 |
| 滚动速度/长按时序 | RemoteButtonGestures、RemoteMappingSupport | controller timer/取消、默认迁移、说明 | 边界/迟到/断连单测+真应用 |
| 遥控器连接不稳定 | BLEBridge、HID bridge | ATVVStreamLifecycle、main 接线、会话失败 | transport/controller+HID probe+设备测试 |
| 录音无声/尾音丢失 | BLEBridge.handleAudio、AudioPipe、voice controller | 目标工具选路、gain、close/tail/key ownership | PCM/租约/虚拟调度器+真实音频 |
| 工具快捷键或自定义工具 | VoiceConfiguration、InputTrigger、VoiceApplicationLauncher | KeyboardTriggerObserver/State、controller、archive | launcher/键盘/四模式+工具实测 |
| 名称或身份 | RemoteDisplayName、三语显示文案或 Packaging/LaunchAtLogin | 昵称、产品占位名、作者署名和 bundle/driver/配对身份分别确认；参考 TODO | 名称/归档/品牌检查；技术身份变化另做迁移与 TCC |
| 添加偏好到备份 | 对应纯偏好模型、ChromecastSettingsArchive | snapshot/restore/validate、UI reload、语言变更通知、确认与旧版本兼容 | 正常/缺字段/非法值/未知 key/重置隔离 |
| 换图标或遥控器图 | Resources/AppIcon、占位图生成脚本或 Resources 活动照片 | package-app、LogoAsset、MappingLayout、来源通知、最终身份 TODO | 图标 --check、branding/bundle checker+大小/热点/浅深视觉 |
| 修改三语与语言切换 | Localization、三份 Localizable.strings | 系统 InfoPlist.strings、LanguageStore、类型化状态/错误、归档语言、SwiftPM/手工包资源 | key/占位检查、LocalizationTests、两个可执行入口资源检查及原生三语视觉 |
| 改发布版本/签名 | VERSION、Packaging/Info.plist、package/build 脚本 | bundle/login/pkg/driver 身份、迁移、许可、公证 | 真 bundle、安装/升级及当前许可审查 |
| 排查日志或录音 | Log、WavRecorder、AppStorage、BLEBridge | 菜单开关和明确清理、采样率/隐私 | 检查本地文件，不上传私密音频作为默认动作 |

### 修改时容易踩的坑

1. 原生界面和 HTML 原型不是同一实现，原型通过不能代替 Swift 编译
2. current source check 是字符串/几何约束，不是全程序静态分析；大改应同步检查而非删除失败断言
3. 原生归档是 plist，原型导出是演示 JSON；两者不能互换
4. 昵称不是绑定键；保存 UUID 也没有解决 HID/BLE 多遥控器关联
5. voice key 不在 ordinary-button recognizer 中；接入第二套长按逻辑会破坏会话所有权
6. Route discovery 不能顺手开启音频；真发键必须在输出成功后；停止要保留可重试状态
7. 常规 print(String) 在生产源码中被 Log.swift 重载，日志默认关闭；“没有终端输出”不一定表示回调没执行
8. 新增/改动语言 key 要同步三份表和动态参数，语言切换不得清除已有失败、试用结果或按键配置
9. WavRecorder 的 16 kHz header 是当前固定实现；协议虽支持 8 kHz，诊断文件也要按实际 codec 检查
10. 占位显示名与新图标不改变兼容 ID、继承版权、照片权利或 GPL 驱动门槛；不要全局替换 vRemote/vRemoter 字样破坏存储、路径、历史或通知
11. VERSION 与打包 plist 是两处数据，脚本取 plist；同步版本前不要只改 VERSION

## 13 被忽略产物与运行时数据

这里说明角色，不将其列入 126 个当前保留/新增项目文件，也不枚举机器上的私人目录内容。

| 路径/模式 | 来源和用途 | 维护边界 |
| --- | --- | --- |
| .build/ | SwiftPM executable、模块缓存、脚本测试二进制 | 可重建缓存；脏产物不能被通配复制进 App |
| __pycache__/ / *.pyc | Python 工具运行时可能产生的字节码缓存 | 临时本机产物，不是需纳入版本控制的项目文件 |
| .swiftpm/ | SwiftPM 本地工作状态 | 机器相关，不当成产品源码 |
| dist/ | 开发 App、图标中间件、DMG/PKG staging 与安装包 | 打包脚本会覆盖特定子目录/同名产物；不保存唯一重要文件 |
| Driver/build/ | 从本机已安装 BlackHole 复制/打补丁的生成驱动 | 不跟踪；来源/版本/哈希仍要单独核验 |
| *.app / *.driver / *.dSYM | App/驱动 bundle 和调试符号 | 生成物；存在不等于已签名、公证或可发布 |
| *.log / *.wav / *.pcm / *.raw / *.raw.bin / Recordings/ | 诊断日志与可能含私人语音的录音 | 默认不提交，不自动分享；清理要尊重实际数据价值 |
| uuid.txt 等配对标识忽略规则 | 避免设备识别数据误入仓库，含历史兼容规则 | 忽略规则的存在不等于运行时仍支持旧设备 |
| DEL/ / .DS_Store | 忽略的临时工作或系统元数据模式 | 本指南不假定存在，也不把它们当正式归档 |

App 的实际数据由 AppStorage 使用用户 Library 的标准 Logs/Application Support 位置；BLEBridge 另保存重连 UUID，LaunchAtLogin 使用用户 LaunchAgents。备份配置不打包这些目录。检查用户错误日志或音频前应了解其隐私，不能把本机运行数据混进源码文档。

## 14 发布前仍需解决的事项

- 应用当前是开发分支与临时签名；正式 Developer ID、公证、完整升级/安装和支持架构验收尚需独立完成
- 当前只明确支持已知 Chromecast Voice Remote VID/PID；实体设备、多台 Mac、改系统蓝牙名和 IR 键都存在边界
- BlackHole 派生驱动输入未固定版本/哈希，仓库没有完整对应源码；现有 binary patch 不证明可复现，也不证明完整 GPL 通知和分发路线已成立
- 驱动、App、PKG 的发布许可安排需明确；App-only 不等于可将驱动按 MIT 分发
- 可见产品名现为描述性占位名、图标为通用几何占位，旧独立品牌图和帮助截图已移除；最终产品名、贡献署名、图标和保留照片的发布权利仍待确认，不替换继承版权人
- vRemote target/executable/app 路径、local.simaqingfeng.vRemote bundle/signing/login-item 体系、PKG/DMG 名称、偏好/归档/数据目录及驱动身份暂为兼容保留；是否更换应连同升级/并存、TCC 重授权和用户数据迁移一起设计及验收
- 三语资源与动态刷新已有实现；完整三语显示、长文本布局、系统权限弹窗及实际工具反馈仍需逐页原生验收
- 诊断 WAV 固定采样率应在扩展 codec 支持时核对；三语原生帮助是示意而非真实系统截图，需要按实际 macOS/工具版本验证说明准确性

这些事项的决策与证据分别保存在[所有权与许可证说明](PROJECT_OWNERSHIP_AND_LICENSES.md)、[TODO](../TODO.md)和[验收清单](CHROMECAST_ACCEPTANCE.md)。不要把清理完成、测试通过或文档完整性当作对外发行批准。

## 15 完整性复核方法

清单将“Git 保留且实际存在的文件 + 本轮未忽略的新文件”与逐文件表格逐项比较，要求每个文件有实际相对链接及明确职责。本轮目标为 **126/126 个文件有说明，0 个遗漏，0 个本地文件链接失效**；目录树与分类统计使用同一清单。文件、工具或资源变化后应重新复核；这个文档完整性目标不能当成编译、测试或发行验收结果。

更新指南时可以从仓库根目录列出准确文件名，避免 Git 对中文文件名的展示转义：

```sh
git ls-files --cached --others --exclude-standard -z
# 对输出去重并只保留实际存在的普通文件；已跟踪但已删除的路径不计
# 从同一集合生成树/目录计数，检查逐文件表格与相对链接覆盖
git diff --check
```

必须区分“文件被提到”和“职责已解释”：仅把路径放入 tree 不是逐文件说明。大文件还需保留内部阅读地图，关键行为要能追到真实类型/函数、调用者、副作用与对应测试。文件重命名后同时更新这里、相关工程说明、构建/测试脚本和相对链接。
