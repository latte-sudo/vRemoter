# 项目归属、复用与许可清单

审计日期：2026-10-02。审计起点：`ac3890f`；原始上游基线：`15076345d955fcc81dae659150d1702b50b8010a`。

本轮原生迁移与后续清理已移除旧推广、赞助、商城、自动更新、TelemetryDeck、旧站点，以及 X6 专用运行代码和封版 UI 设计。应用仍保留 MIT 来源代码、提取后的共享键盘/语音能力与现有虚拟驱动路线；品牌和图标没有更换。

这是当前 fork 的工程来源与发布检查表，不是权属证明或法律意见。清理旧界面、推广和商店资源不会消除仍然保留代码的许可条件，也不应把继承的实现改称全部原创。实际删除与保留范围见 [CLEANUP_REVIEW.md](CLEANUP_REVIEW.md)。

## 1. 可以独立维护的部分，以及必须保留的来源说明

- 这个仓库可以作为用户自己的项目继续维护、修改和重新命名；保留的 MIT 代码仍须带原作者的版权和许可文字。MIT 文字没有要求继续展示旧产品界面、赞助按钮、商城或原作者的更新服务；版权通知与这些推广入口应分开处理。用户姓名、公司名称与新增代码的版权声明尚未指定，不代填。
- 新的原生引导和设置实现以用户批准的 `docs/prototypes/vremoter-onboarding-settings.html` 为界面依据。该原型自身为离线 HTML/CSS/JavaScript，没有外部脚本、远程字体或 npm 依赖。
- 原型、原生新增文件和后续改动的开发记录不等同于第三方素材的权属证明。新 UI 使用现有功能层，也不改变其来源。
- 下方复用台账集中保留了 SayAll/remote-mic-app 的流程与视觉布局参考，以及“未复制源代码、未取得或复制不可用的 Chromecast 私有模块”的边界。该边界应继续保持；不能从参考项目的公开代码许可推定私有模块有使用授权。

## 2. 仍须保留或核对的许可与版权

| 来源 / 证据 | 本项目文件或用途 | 许可与版权 | 保留 / 发布要求 |
| --- | --- | --- | --- |
| [vRemoter 上游基线 LICENSE](https://github.com/VincentKingHsu/vRemoter/blob/15076345d955fcc81dae659150d1702b50b8010a/LICENSE)；本地 `LICENSE` 内容一致 | 继承的应用、工具与打包脚本，详见下方文件范围 | MIT；`Copyright (c) 2026 Sima Qingfeng` | 不删除或替换原版权人；在源代码分发和含有实质部分代码的二进制分发中附版权与完整 MIT 许可文字 |
| [fanxeon/mi-ao LICENSE](https://github.com/fanxeon/mi-ao/blob/main/LICENSE)；本地三个文件首行及 `THIRD_PARTY_NOTICES.md` | `Sources/vRemote/ATVV/ADPCMDecoder.swift`、`ATVVProtocol.swift`、`BridgeError.swift`；音频协议解析仍在用 | MIT；`Copyright (c) 2026 FanXeon@Poemcoder with Codex` | 保留三个文件的作者头；分发包含完整 MIT 授权文字，不能只留下 GitHub 链接 |
| [b0o/ATVVoice LICENSE](https://github.com/b0o/ATVVoice/blob/main/LICENSE)；本地 `THIRD_PARTY_NOTICES.md` | 已有说明称 ATVV 协议与 IMA/DVI ADPCM 实现受其启发；本次未完成逐行来源比对 | MIT；`Copyright (c) 2026 Maddison Cohodas` | 保守保留现有署名和 MIT 文字。现有说明不证明直接复制，亦不足以自行断言可以删除署名 |
| [BlackHole v0.4.1 LICENSE](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/LICENSE)、[源文件头](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/BlackHole/BlackHole.c) | `Driver/build-driver.sh` 复制/修改本机 `BlackHole2ch.driver`；`build-pkg.sh` 打包生成的 `vRemoteDriver.driver`；应用通过 CoreAudio 使用虚拟设备 | GNU GPL v3；源文件头为 `Copyright (C) 2019 Existential Audio Inc.` | 驱动不受本仓库 MIT 替代。保留驱动版权、GPL 全文、修改说明与对应源码；详见第 4 节。实际输入二进制的版本与版权仍需逐包核验 |
| [TelemetryDeck 固定 revision LICENSE](https://github.com/TelemetryDeck/SwiftSDK/blob/bc7467592166e8f93fbde0140d2757b0635e1712/LICENSE)、[Package.swift](https://github.com/TelemetryDeck/SwiftSDK/blob/bc7467592166e8f93fbde0140d2757b0635e1712/Package.swift) | 清理前 `Package.swift`/`Package.resolved` 唯一 SwiftPM 外部依赖，版本 `2.9.10`；`AnalyticsSupport.swift` | **修改版 MIT，移除了署名保留条款**；`Copyright (c) 2020 Daniel Jilg` | 不应误报成标准 MIT 的强制署名要求。该固定版本明确不要求在副本中附许可；本轮已删除依赖、锁文件及初始化，当前应用 Package.swift 无外部依赖。该 SDK 自身的 Package.swift 也没有外部依赖 |
| [Google Voice over BLE v1.0（现有记录中的镜像）](https://wangefan.github.io/linux_kernel_driver/resources/Google_Voice_over_BLE_spec_v1.0.pdf) | 协议参考；没有 PDF 文件打包进仓库 | 没有在本次查得独立再分发授权；参考资料不是代码许可 | 保留资料来源，避免把镜像或协议资料标成 MIT；若要复制文档、图表或大量文字，另核实授权 |
| Apple SDK / 系统资源 | `AppKit`、`SwiftUI`、`CoreBluetooth`、`CoreAudio`、`AVFoundation`、`CoreGraphics`、`ApplicationServices`、`IOKit` 等系统调用与系统符号/字体 | 平台 SDK/系统资源，不是本仓库自行授权的第三方源码 | 仓库未跟踪 SDK、字体文件或 framework 二进制；发布时按适用 Apple 工具和资源条款检查，不把系统符号/字体称为用户原创 |

### 继承功能代码的范围

不能因为重写了窗口，就删除以下功能实现的来源说明。清理起点这些文件已存在于上游；当前修改可能改变内容，但不会自动消除来源：

- 传输与音频：`ATVV/*`、`BLEBridge.swift`、`ChromecastRemoteHIDBridge.swift`、`AudioPipe.swift`、`WavRecorder.swift`
- 系统集成：`AppStorage.swift`、`InputTrigger.swift`、`DoubaoAudioStateMonitor.swift`、`LaunchAtLogin.swift`、`Localization.swift`、`Log.swift`
- 映射和应用胶水：`RemoteMappingSupport.swift`、`main.swift`、`DebugWindowController.swift` 中保留的权限帮助、快捷键录制及窗口/模型代码
- 已提取/改名的共享实现：`KeyboardTriggerObserver.swift` 的键盘触发监听来自已删除的 `X6SearchSuppressor.swift`；`RemoteVoiceSupport.swift` 的共享语音类型来自已删除的 `X6SessionCoordinator.swift`。删除旧类和 X6 Search gate 不会移除保留代码的来源与 MIT 条件
- 安装及开发工具：`Driver/*`、`Packaging/*`、`package-app.sh`、`build-pkg.sh`、`build-dmg.sh`、`install-app.sh`、`run-self-tests.sh` 及未删除的原有工具

新增的 Chromecast 状态机、设置档案、引导证据、主题/程序坞设置、测试等已由 Git 历史区分；新增文件名不应被当作完全独立创作的法律结论。本次不更换仓库的整体许可。

## 3. 图像、图标、原型与品牌

| 文件 / 资源族 | 当前来源证据 | 处理原则 |
| --- | --- | --- |
| `Resources/RemoteImages/chromecast-front-and-volume-enhanced.png` 与原型中的内嵌遥控器图 | 现有替换台账记录为用户提供图片，经 AI 增强正面并重建侧面音量示意 | 当前 UI 所需，应保留。未确认原照片拍摄者、商业分发授权或 AI 修复细节的实物准确性；AI 增强不自动清除原图权利。正式发布前由用户确认或替换 |
| `Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png` | 上游品牌图，清理前被 `LogoAsset` 与打包脚本直接使用 | 不能无替代直接删除，否则丢失应用图标/打包失败；让用户指定新图标。根 MIT 未提供可独立核对的品牌/商标授权证明 |
| 其余 `Design/vRemoter-Logo-v1/*` | 保留的上游品牌设计历史和 Figma 插件，没有单独资产权利清单 | 本轮不更换品牌，全部保留；不能把图形重新署名为用户原创 |
| 已删除的 `Design/vRemoter-UI-v1-Frozen/*`、`Design/UIv1_bak.fig` | 被当前原型取代的上游 X6 / 混音器 UI 设计 | 无应用/打包引用，本轮已移除。删除设计不影响保留源代码与品牌资产的来源要求 |
| `Resources/PermissionGuides/*.png` | 上游 macOS / 豆包界面截图；`README.md` 仅说明如何替换截图 | 权限帮助仍会读取，保留或以用户自己的最新截图替换；没有逐图作者或额外许可证据 |
| `Resources/RemoteImages/chromecast-voice-remote.png`、`x6-remote.png` | 上游遥控器商品图，独立来源未记录 | 已随旧映射视图移除；如以后从历史恢复或对外使用，仍须核实照片来源 |
| `Resources/Commerce/*`、`Resources/buymeacoffee/*`、旧 `docs/assets/*` | 上游营销、收款二维码、品牌、截图和商品图 | 已整组移除及解除代码/页面/打包引用。删除这些营销内容不等于删除许可证；没有创建新收款渠道 |
| `docs/prototypes/vremoter-onboarding-settings.html` | 用户批准并归档的离线 UI 原型；[原型说明](prototypes/README.md) | 保留作实现与交互验收依据。其内嵌图片遵循本表第一行；系统字体栈没有分发字体文件。内联 SVG 图标未标注第三方图标库来源，本次未逐个建立创作来源，不能仅凭没有外部依赖称全部图形原创 |
| SayAll / `HD838A/remote-mic-app` | [固定参考提交](https://github.com/HD838A/remote-mic-app/tree/5a10bba28bd1514892a2a7400ae594629f728da7)；GPL-3.0-only 软件与独立品牌许可 | 参考了交互和视觉布局，没有为本实现复制其源代码或私有 Chromecast 模块。其鸭子图标等品牌资产另受 [LOGO-LICENSE.en.md](https://github.com/HD838A/remote-mic-app/blob/5a10bba28bd1514892a2a7400ae594629f728da7/LOGO-LICENSE.en.md) 限制，**不得借用为本项目图标**。今后复制任何代码或资源前须重新审查 |

## Reference and replacement ledger

This section consolidates the former reuse ledger and mapping-layout reference
notes; deleting those duplicate documents does not remove their provenance.

| Item | Retained facts and next review |
| --- | --- |
| vRemoter source | Fork of upstream `15076345d955fcc81dae659150d1702b50b8010a`; inherited MIT notice remains, including renamed/extracted shared implementations |
| SayAll layout/workflow reference | `HD838A/remote-mic-app` at `5a10bba28bd1514892a2a7400ae594629f728da7`; public `RemoteMappingCanvas.swift`, `SettingsView.swift` and the screenshots below informed behavior/layout. No reference source, private Chromecast module, photo or branding was copied for this implementation |
| Reference screenshot evidence | In that reference repository: `Screenshots/settings-page/sidebar-profile-login-20260922/light/mapping-1020x772.png` and `Testing/artifacts/chromecast-layout/mapping-zh-Hans-light-1400x2000.png`. These are external reference paths, not missing local assets |
| Current Chromecast image | User-provided photo enhanced at the front with a reconstructed side-volume illustration; verify rights, physical proportions/buttons and production quality before distributing |
| Existing brand and permission screenshots | Current icon/help and all branding design sources remain; superseded remote/promotional assets and frozen UI design are removed. Retention is not a new trademark or screenshot permission grant |
| Speech tool compatibility | Existing Doubao observation remains; custom tools use explicit configuration and a human-confirmed real trial. Tool selection/launch alone is not verified compatibility |
| Virtual driver | Existing modified BlackHole route retained, not rewritten or cleared for a new release; source/notices/license route remain open below |
| Retired services and X6 | Commerce/update/donation/telemetry/site and X6 transport/coordinator/profile removed. Import only ignores known historical X6 fields in v1 Chromecast archives; unrelated on-disk data is not erased |

Any later reuse of reference source, logos or unavailable private modules requires
its own source/license review. The current cleanup does not change that boundary.

## 4. BlackHole 驱动：发布前必须单独处理

已查明的工程事实：

1. 仓库没有跟踪 `.driver`、`.pkg`、`.dmg`、`.framework` 或 `.xcframework` 二进制，也没有 BlackHole 的完整源码树。
2. `Driver/build-driver.sh` 从 `/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver` 拷贝已安装驱动，修改名称、标识符、UUID 以及传输类型，再做本地临时签名。脚本**不核对输入版本、来源 commit 或 SHA-256**；因此 `THIRD_PARTY_NOTICES.md` 所称的 0.4.1 不能保证任意机器输入都真是 0.4.1。
3. `build-pkg.sh` 把修改驱动放入安装包。`build-dmg.sh` 是仅应用包；它仍需要实际可用的虚拟音频设备才能完成相关语音路径。
4. “原 GPL 许可会随 ditto 复制保留”目前只有既有说明；本次未生成或检查最终驱动包，不能宣称最终安装包通知完整。

GPLv3 第 4–6 节要求分发时保留相关版权/许可、标明修改，并按适用方式提供对应源码（包含生成、安装和修改所需内容）。仅交付二进制补丁脚本并不证明已提供完整对应源码。GPLv3 第 5 节也区分独立聚合与形成一个更大程序，不能仅凭“单独 `.driver` 文件”或“通过 CoreAudio 调用”自行得出整个分发方式已获许可的结论。参见 [GNU GPLv3 正文](https://www.gnu.org/licenses/gpl-3.0.html) / [OSI 正文镜像](https://opensource.org/license/gpl-3.0)。

BlackHole 的 [v0.4.1 开发者说明](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/README.md#developer-guides) 明确要求非 GPL-3.0 项目联系其取得许可。**本次不判定 MIT 应用加此修改驱动的发行路线已合规。** 正式分发前应确定采用满足 GPL 的具体方案、另行获得许可，或使用经审查的替代驱动；需要时由法律顾问确认。

建议发布门槛：固定真实输入版本/哈希；获得对应源码并能从源码重建全部修改；补足 GPL 全文、版权和注明日期的修改清单；确认对应源码随二进制的提供方式；检查最终 PKG 内容。未完成前不以此文档声称已能商用分发。

## 5. 最小保留通知与打包要求

以下内容不同于旧的营销界面，不应随清理删除：

1. 原根 `LICENSE` 全文和 Sima Qingfeng 版权行。
2. 三个 `ATVV` 文件中的 FanXeon 作者头，以及该代码使用的完整 MIT 许可。
3. 现有 `THIRD_PARTY_NOTICES.md` 中 mi-ao、ATVVoice、Google 协议资料与 BlackHole 的来源记录；需要更新状态时保留事实，不笼统删除。
4. 对每个实际随包分发的 BlackHole 衍生驱动，保留其 GPL/版权通知与修改和源码交付信息。
5. 将通知作为真实文件放入应用包，例如 `Contents/Resources/Licenses/`；源仓库有 LICENSE 并不证明 DMG/PKG 收件人已取得通知。构建后检查实际包内容。

审计起点 `package-app.sh` 未复制根 `LICENSE` 或 `THIRD_PARTY_NOTICES.md`；本轮已新增三份文件（含本文）到 `Contents/Resources/Licenses/` 的复制步骤，并在 `THIRD_PARTY_NOTICES.md` 中补足完整 MIT 文字。静态脚本检查不等于已验证 macOS 成品包。下方集中 MIT 通知亦可随应用附带（仅适用于所列 MIT 部分，**不替代 BlackHole GPL**）。Maddison 的行在逐行来源复核前保守保留。

```text
MIT License

Copyright (c) 2026 Sima Qingfeng
Copyright (c) 2026 FanXeon@Poemcoder with Codex
Copyright (c) 2026 Maddison Cohodas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 6. 用户仍需指定 / 确认的项目身份

- 产品显示名称与新增贡献的署名名称；暂存旧名称不表示用户已选择继续使用该品牌
- 有权使用的应用图标和菜单栏图标；以及遥控器照片可对外分发的来源
- 用户控制的反向域名 bundle ID、安装包 ID、驱动 ID（如需更改）；修改前设计设置迁移、登录项和 macOS 权限重授予方案
- Developer ID / 团队及签名、公证策略；不沿用 `local.simaqingfeng.vRemote` 的身份假称属于用户
- 用户自己的发布仓库、更新清单地址和下载站；在得到指定并完成校验前关闭旧上游更新渠道
- 是否以后需要统计、购买或赞助功能；本轮清理不创建新的收款、商店或分析账户

重命名包标识不是简单搜索替换：`AppStorage`、登录启动、签名 designated requirement、驱动设备 UID、设置导入与旧版本升级都可能受影响。此文档只列出决策，不擅自选定身份或变更用户设备。

### 具体要确认的字段

“发布前要决定”不表示所有字段必须改名。开发测试可以保留现值；若选择独立品牌、并存安装或新的签名身份，再一起修改相互依赖的字段并做迁移测试。

| 项目 | 仓库文件 / key | 当前值 | 什么时候要处理 |
| --- | --- | --- | --- |
| 产品显示名称 | `Packaging/Info.plist`：`CFBundleDisplayName`、`CFBundleName`；`ChromecastConsoleView.swift`、`DebugWindowController.swift`、`main.swift` 中显示文案 | `vRemoter` | 独立品牌发布前决定保留或换名；不是删除来源署名 |
| 应用图标 | `package-app.sh` 图标输入；`Packaging/Info.plist`：`CFBundleIconFile`；`DebugWindowController.swift`：`LogoAsset` | 输入 `Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png`；输出 `vRemoterLogo.png` / `vRemoter.icns` | 发布前确认使用权或提供自己的图标；与显示名称一起决定 |
| Swift 包 / 可执行 target | `Package.swift`：package `name`、`.executableTarget(name:)` | 两者均为 `vRemote`；没有单独显式 `products` 数组 | 可选内部命名；若改，须同步二进制路径、构建测试和安装脚本 |
| 可执行文件 / app 目录 | `Packaging/Info.plist`：`CFBundleExecutable`；`package-app.sh`、`build-pkg.sh`、`build-dmg.sh`、`install-app.sh` | 可执行文件 `vRemote`；`vRemote.app`；本地安装为 `~/Applications/vRemote.app`，PKG payload 为 `/Applications/vRemote.app` | 可选；独立并存安装时应明确目录，不能只改显示名后意外覆盖旧 app |
| 应用 bundle ID | `Packaging/Info.plist`：`CFBundleIdentifier` | `local.simaqingfeng.vRemote` | 发布前决定是否沿用身份或迁移到用户控制的命名空间；独立并存通常需要独立身份。不是声称法律上所有 fork 都必须改 ID |
| 登录启动项 | `Sources/vRemote/LaunchAtLogin.swift`：`label` | `local.simaqingfeng.vRemote.login`；对应 `~/Library/LaunchAgents/<label>.plist` | 改应用身份/并存策略时一并决定，迁移时处理旧项，避免重复启动 |
| 应用签名 | `package-app.sh`：`codesign --sign`、`--requirements` | 临时签名 `-`；designated requirement 为 `identifier "local.simaqingfeng.vRemote"` | 开发可保持；选新 bundle ID 时同步 requirement。正式发布前确定用户的 Developer ID 与公证/分发方案，本脚本当前不完成公证 |
| 安装包身份 / 签名 | `build-pkg.sh`：`pkgbuild --identifier`、`INSTALLER_SIGN_IDENTITY` | `local.simaqingfeng.vRemoter.pkg`；签名变量未设置时输出未签名 PKG | 仅发布 PKG 时需要决定；改 ID 要考虑已有安装 receipts/升级。签名身份由用户指定，不复制原作者身份 |
| 版本号与构建号 | `VERSION`；`Packaging/Info.plist`：`CFBundleShortVersionString`、`CFBundleVersion` | `1.1.1`；`1.1.1`；`111` | 发布前决定本 fork 的版本策略，保持两处版本一致，并为后续发布递增 build；本轮未伪造新版本 |
| 分发文件名 / DMG 卷名 | `build-pkg.sh`、`build-dmg.sh` | `vRemoter-<version>.pkg` / `.dmg`；卷名 `vRemoter <version>` | 如果改公开产品名，一起更新；本轮没有生成正式发布包 |
| 本地日志 / 设置目录 | `Sources/vRemote/AppStorage.swift` | `~/Library/Logs/vRemote`、`vRemote.log`、`~/Library/Application Support/vRemote`（含 `Recordings`） | 可选兼容性选择；换名时设计迁移，不因清理代码而删除现有数据 |
| 更新 / 商城 / 统计 | 原 plist 的 `VRReleasesURL`、`VRCommerceConfigURL`、`VRTelemetryDeckAppID`、`VRTelemetryDeckNamespace` | **本轮均已删除**，没有新服务地址或账户 | 以后确实需要时再由用户指定；独立应用无需为了改名重建这些功能 |

### 驱动身份是另一项延后决定

下列字段全部来自 `Driver/build-driver.sh` 的现有补丁规则，本轮没有修改。仅给应用换名，不要求同时改已安装且工作正常的音频设备名称。

| 字段 | 当前脚本输出 / 关联文件 | 注意事项 |
| --- | --- | --- |
| 驱动包 / Bundle ID / 名称 | `vRemoteDriver.driver`；`audio.local.vRemoteDriver2chXX`；`vRemote Driver` | `Driver/install-driver.sh`、`uninstall-driver.sh`、`Packaging/pkg-scripts/postinstall` 和 `build-pkg.sh` 都引用当前包路径 |
| 工厂 UUID | `B7C4C615-9E72-4C83-A329-71C4E50E4A91`，入口名仍为 `BlackHole_Create` | 若另做独立驱动身份需一致更新 Info.plist 及源代码；不随意改 BlackHole 执行入口 |
| 设备 UID / 次设备 UID | `vRemoteDr%ich_UID`、`vRemoteDr%ich_2_UID`（`%i` 为声道数格式位） | 用户保存的音频路由可能绑定 UID；改动要迁移和实机验证 |
| Model UID / Box 名称 | `vRemoteDr%ich_ModelUID`、`vRemoteDr Box` | 保留与驱动实现一致；当前二进制替换依赖同字节长度 |
| 音频设备显示名 | `vRemoteDr %ich`；2 声道时 `vRemoteDr 2ch` | `AudioRouteConfiguration.swift`、`DoubaoAudioStateMonitor.swift`、帮助文案和测试也使用默认名；变更需联动 |

如果决定更改上述驱动身份，优先建立可重建的源码方案，不能把当前等长二进制补丁脚本当作任意重命名工具。这个决定仍受第 4 节的 GPL 与分发条件约束。
