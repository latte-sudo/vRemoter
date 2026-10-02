# 原生 UI 迁移清理审计

日期：2026-10-02。基准：`ac3890f`（已归档批准的 HTML 原型）。

本审计把“未在运行时使用”“可以随本轮迁移删除”“仍被构建/帮助/测试使用”分开记录。条目是代码和资源审查结论，不代表这些删除已经全部执行；实际执行记录放在末尾。许可与权属清单见 [PROJECT_OWNERSHIP_AND_LICENSES.md](PROJECT_OWNERSHIP_AND_LICENSES.md)。

## 1. 已查证、可以成组清理的旧功能

| 类别 | 文件 / 声明 | 删除前必须同时解除的连接 |
| --- | --- | --- |
| 旧商城 | `Sources/vRemote/CommerceSupport.swift`；`DebugWindowController.swift` 的 `PurchaseView`、`PurchaseQRCode`、`CommerceStore` 扩展；`Resources/Commerce/` | `ConsoleModal.purchase`、`ConsoleModalContent` 分支、模型/窗口 `showPurchase()`、`main.swift --purchase-demo`；移除 plist `VRCommerceConfigURL` 和打包复制 |
| 原作者赞助/收款 | `Sources/vRemote/DonationSupport.swift`；`DonationProvider`、`DonationPromptView`、`DonationView`；`Resources/buymeacoffee/` | 模型的 `donationPromptShownInSession`、`evaluateDonationPrompt()`、提示/开窗/关闭方法；`refreshPermissions()` 内调用；modal 分支、菜单项与 `openDonation()`；打包复制 |
| 原作者更新渠道 | `Sources/vRemote/UpdateSupport.swift`；`SelfTests/Fixtures/releases-current.json`、`releases-new.json` | `main.swift` 的 `updateWindow`、菜单、`openVersionUpdates()`、更新演示参数、延时自动检查；plist `VRReleasesURL`；同时处理旧下载站，不把原渠道当作用户自己的更新服务 |
| 原作者统计 | `Sources/vRemote/AnalyticsSupport.swift`；SwiftPM `TelemetryDeck` dependency | 删除所有 `AppAnalytics.configure/signal` 调用，plist `VRTelemetryDeckAppID` / `VRTelemetryDeckNamespace`，再更新 `Package.swift` 与 `Package.resolved`。只清空 App ID 不等于移除 SDK |
| 旧商城测试数据 | `SelfTests/Fixtures/commerce-two-stores.json` | 当前测试脚本及源码无读取引用；与商城功能删除一起移除 |
| 旧主窗口 | `DebugWindowController.swift` 的 `StudioMixerView`、`ConsolePageSelector`、`KeyMappingView`、`DeviceSelectionRow`、`MappingRow` | 唯一 `NSHostingView` 根已是 `ChromecastConsoleView`；这些私有视图只在旧根中互相引用。删除后检查 `ConsolePage` / `selectedPage` 等只服务旧根的状态 |
| 旧混音与商品插图控件 | `RemoteProductImage`、`InputChannelView`、`OutputChannelView`、`MeterView`、`RemoteImageAsset`；旧根专用 `StatusTone`、`StatusPill`、`StatusRow` | 按声明删除，不按易变化的行号；确认新原生 UI 不再引用，然后清理旧 `Resources/RemoteImages/chromecast-voice-remote.png` 与 `x6-remote.png` |

“商城当前禁用”“X6 没启动”“没有菜单入口”都不等于该文件不存在执行路径；以上结论基于实际查找调用关系。

### DebugWindowController 必须保留的共享部分

- `ConsoleViewModel`、`DebugWindowController` 的新窗口和状态同步
- `PermissionKind`、`GuideAsset`、`PermissionGuideView`、`GuideScreenshot` 以及权限帮助仍需要的 `ConsoleModal` / `ConsoleModalContent`
- `KeyboardShortcutCaptureView`、`KeyboardEventCaptureView`、`KeyboardCaptureNSView`，仍由新的按键配置调用
- 以上帮助/录制控件依赖的 `ConsoleTheme`、`ConsoleButtonStyle`、`ConsoleButtonTone`、`panelBackground`（若统一到新设计令牌，须确认新旧调用已全部替换）
- `LogoAsset` 仍被 `main.swift` 和 `DockVisibilityController.swift` 使用；图标未替换前不直接删除

## 2. X6：明确可拆除的旧运输层，与必须保留的共享能力

| 对象 | 审计结论 | 安全处理 |
| --- | --- | --- |
| `X6HIDBridge.swift`、`main.swift` 的 X6 HID/BLE 延迟实例、旧双设备选择/状态分支 | 产品当前仅启动 Chromecast 的 HID/BLE；仍有声明及旧模型/菜单关联，编译会包含这些代码 | 从运行胶水和旧 UI 清理完整引用后删除 X6 专用运输层；保持当前 Chromecast VID/PID、HID 抑制和映射路径 |
| `X6SessionCoordinator.swift` 的类主体 | 已由 Chromecast 专用 controller 承担实际会话；但文件不是整体未用 | 先提取 `RemoteMicrophoneOpenResult`、`DoubaoAudioStateProviding` 和 `DoubaoAudioStateMonitor` 的协议遵循，再决定删除旧 class |
| `X6SearchSuppressor.swift` | **当前仍在运行**；主程序将其键盘触发事件回调接到 Chromecast controller，并执行 start/stop/reconnect | 保留键盘观察能力；可在有回归验证的情况下改为中性命名并删除未使用的 X6 Search gate。仅因文件名前缀为 X6 不能删除 |
| `BLEBridge.swift` | Chromecast 活跃的 CoreBluetooth / ATVV 传输，不是 X6 专用遗留 | 保留；可更正历史注释，不能删其音频、keep-alive、生命周期处理 |
| `VoiceSessionSelfTest.swift` 与主程序 `--voice-session-self-test` 入口 | 旧测试依赖 X6 coordinator；不是自动运行的当前 Chromecast 专用套件 | 删除旧 coordinator 时同步迁移或删除旧 CLI 测试入口，并保留当前 Chromecast 控制器/传输回归覆盖；不能用编译失败的历史测试占位 |
| `RemoteMappingSupport.swift` 的 `.x6`、`x6Buttons`、旧持久化 key | 旧 profile 与当前共享映射持久化混在一起；`SelfTests/Gestures/RemoteMappingStoreTests.swift` 明确验证重置 Chromecast 不破坏旧 X6 数据 | 可以取消可操作的 X6 profile；不要顺手删除用户磁盘偏好、导入格式兼容性或 reset isolation 测试 |

`run-chromecast-voice-tests.sh` 会直接编译当前 controller/state machine/ATVV，并在 `SelfTests/ChromecastVoice/main.swift` 使用平台适配桩。共享类型提取时注意测试桩已有同名类型，避免重复声明。

## 3. 非应用运行时的旧站点与设计资源

以下文件不是 Swift target 或当前 CI 的输入，可以在用户批准的“去掉原项目推广”范围内成组删除，但必须先处理 README / 页面互相引用：

- 旧站点：`docs/index.html`、`docs/app.js`、`docs/styles.css`、`docs/config/commerce.json`
- 旧站点资源：`docs/assets/brand/`、`commerce/`、`donate/`、`guides/`、`remotes/`、`screenshots/`
- 旧发布服务配置：`Server/Caddyfile`、`Server/index.html`、`Server/releases.json`
- 上游运营说明：`OPERATIONS.md`（包含原作者域名、服务器与发布流程）；不能继续把它当作本 fork 的部署授权或操作指令
- `README.md` 的原官网、下载、发布、商城和截图引用需要替换为本 fork 当前说明；不借此修改部署服务器或发布线上站点

下列设计历史没有应用读取引用，但属于是否继续保留源设计的决策项：

- `Design/UIv1_bak.fig`
- `Design/vRemoter-UI-v1-Frozen/` 全部文件
- `Design/vRemoter-Logo-v1/` 中除 `vRemoter-app-icon-v9.png` 外的插件、说明和旧版本输出

`Tools/generate-qr.swift` 没有构建、CI 或源码调用，是通用手动 QR 生成工具；本轮移除商业入口后用途较弱。`Tools/hid-report-probe.swift` 也是手动工具，但仍能辅助当前遥控器调试。二者不应只因没有静态引用就一概认定无价值。

必须保留新的 `docs/*.md` 工程说明、`docs/prototypes/` 已批准设计及其测试，不删除整个 `docs/` 目录。

## 4. 不能在本轮盲删的资源 / 待用户决定清单

1. **产品图标与名称**：`Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png` 是当前打包图标；用户需提供自有图标及产品名。授权不明不等于自动改用另一个项目的 logo。
2. **权限帮助截图**：`Resources/PermissionGuides/` 八张 PNG 被帮助页面按名字读取；保留或以新截图完整替换。需要确认来源及 macOS/豆包版本适用性。
3. **用户提供的遥控器图片**：`chromecast-front-and-volume-enhanced.png` 被当前 mapping canvas 引用，也是新原型的视觉素材来源；确认可对外分发及实物准确性前保留，不以 AI 修复代替权利检查。
4. **BlackHole 衍生驱动**：`Driver/*`、驱动安装后处理和 PKG 路径仍是音频路线的一部分；是否分发该驱动、采用 GPL 路线或另行取得许可，需要发布前决策。删除它会改变安装和语音功能范围。
5. **应用/驱动身份与旧偏好**：bundle ID、登录启动 ID、driver UID、用户配置和旧 X6 偏好涉及迁移与系统权限，不擅自改名、清空或卸载。
6. **设计历史与手动工具**：上一节列出的 Figma 设计历史、QR 生成工具是否还要留作编辑来源；不影响当前程序，可由用户决定最终删/留。
7. **旧发布说明**：`CHANGELOG.md`、`VERSION` 和原有文档可以保留作历史，也可改为新的版本策略；不能借清理伪造发布记录或已完成签名/公证的状态。

应保留的法律文本是 `LICENSE`、作者源文件头和准确的第三方通知；它们不属于“推广残留”。

## 5. 构建、打包与 CI 覆盖

审计起点的调用链：

- `swift build`：编译 `Sources/vRemote` 所有 Swift 文件，非入口可达性不会把不合法引用从类型检查中自动排除
- `.github/workflows/chromecast-validation.yml`：`macos-14`，`swift build` → `zsh run-self-tests.sh` → `bash Tools/test-chromecast-models.sh`（语音重复 20 次）→ `git diff --check`
- `Tools/test-chromecast-models.sh`：权限、布局、路由、程序坞、主题、别名、手势、语音、启动目标和引导证据测试；macOS 上额外运行 AppKit 设置存储/controller 测试
- `package-app.sh`：release build → app、Info.plist、SwiftPM 资源包、语言文件、图标、权限图、商业/赞助/遥控器资源 → 临时签名
- `build-dmg.sh`：调用 `package-app.sh`，只装 app
- `build-pkg.sh`：调用 `package-app.sh` 与 `Driver/build-driver.sh`，装 app 与 HAL driver；`Packaging/pkg-scripts/postinstall` 处理驱动和 CoreAudio
- `install-app.sh`、`Driver/install-driver.sh` 和 `Driver/uninstall-driver.sh` 会修改本机安装，不是本次审计运行的命令

清理后验收应至少包括：

- [ ] `swift build` 和上述完整 macOS 测试通过；未运行的平台不能宣称通过
- [ ] `node docs/prototypes/test-vremoter-onboarding-settings.cjs` 原型回归仍通过
- [ ] 新 UI 的帮助、录键、返回/取消、重复动作、权限拒绝和设置恢复行为验证
- [ ] 源码、plist、包内容不再含原作者的遥测 ID、自动更新/商城端点、赞助入口或收款图片
- [ ] release app 实际带 `LICENSE` / 第三方许可通知；driver 包另有 GPL/来源与修改信息
- [ ] 实际包里只带当前需要的遥控器图、权限帮助和指定图标
- [ ] 若以后改 bundle ID，另做旧版本设置与登录项迁移、TCC 权限及覆盖升级测试

本次审计本身只读了源码、脚本、配置和版本固定的上游许可，并编写说明；未构建 macOS 安装包、未运行驱动安装/卸载、未接触用户 Mac 或部署服务器。

## 6. 执行记录

审计交付时的静态结论如上。原生实现与清理由实现任务负责；合并前按实际 diff 更新这里的已删、保留和未验证项目，避免把计划当作完成。
