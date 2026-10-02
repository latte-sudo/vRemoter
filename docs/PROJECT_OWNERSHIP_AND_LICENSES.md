# 项目归属、复用与许可清单

审计日期：2026-10-02。审计起点：`ac3890f`；原始上游基线：`15076345d955fcc81dae659150d1702b50b8010a`。

这是当前 fork 的工程来源与发布检查表，不是权属证明或法律意见。清理旧界面、推广和商店资源不会消除仍然保留代码的许可条件，也不应把继承的实现改称全部原创。实际删除与保留范围见 [CLEANUP_REVIEW.md](CLEANUP_REVIEW.md)。

## 1. 可以独立维护的部分，以及必须保留的来源说明

- 这个仓库可以作为用户自己的项目继续维护、修改和重新命名；保留的 MIT 代码仍须带原作者的版权和许可文字。MIT 文字没有要求继续展示旧产品界面、赞助按钮、商城或原作者的更新服务；版权通知与这些推广入口应分开处理。用户姓名、公司名称与新增代码的版权声明尚未指定，不代填。
- 新的原生引导和设置实现以用户批准的 `docs/prototypes/vremoter-onboarding-settings.html` 为界面依据。该原型自身为离线 HTML/CSS/JavaScript，没有外部脚本、远程字体或 npm 依赖。
- 原型、原生新增文件和后续改动的开发记录不等同于第三方素材的权属证明。新 UI 使用现有功能层，也不改变其来源。
- `docs/REUSE_AND_REPLACEMENT_LEDGER.md` 记录了 SayAll/remote-mic-app 的流程与视觉布局参考，以及“未复制源代码、未取得或复制不可用的 Chromecast 私有模块”的边界。该边界应继续保持；不能从参考项目的公开代码许可推定私有模块有使用授权。

## 2. 仍须保留或核对的许可与版权

| 来源 / 证据 | 本项目文件或用途 | 许可与版权 | 保留 / 发布要求 |
| --- | --- | --- | --- |
| [vRemoter 上游基线 LICENSE](https://github.com/VincentKingHsu/vRemoter/blob/15076345d955fcc81dae659150d1702b50b8010a/LICENSE)；本地 `LICENSE` 内容一致 | 继承的应用、工具与打包脚本，详见下方文件范围 | MIT；`Copyright (c) 2026 Sima Qingfeng` | 不删除或替换原版权人；在源代码分发和含有实质部分代码的二进制分发中附版权与完整 MIT 许可文字 |
| [fanxeon/mi-ao LICENSE](https://github.com/fanxeon/mi-ao/blob/main/LICENSE)；本地三个文件首行及 `THIRD_PARTY_NOTICES.md` | `Sources/vRemote/ATVV/ADPCMDecoder.swift`、`ATVVProtocol.swift`、`BridgeError.swift`；音频协议解析仍在用 | MIT；`Copyright (c) 2026 FanXeon@Poemcoder with Codex` | 保留三个文件的作者头；分发包含完整 MIT 授权文字，不能只留下 GitHub 链接 |
| [b0o/ATVVoice LICENSE](https://github.com/b0o/ATVVoice/blob/main/LICENSE)；本地 `THIRD_PARTY_NOTICES.md` | 已有说明称 ATVV 协议与 IMA/DVI ADPCM 实现受其启发；本次未完成逐行来源比对 | MIT；`Copyright (c) 2026 Maddison Cohodas` | 保守保留现有署名和 MIT 文字。现有说明不证明直接复制，亦不足以自行断言可以删除署名 |
| [BlackHole v0.4.1 LICENSE](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/LICENSE)、[源文件头](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/BlackHole/BlackHole.c) | `Driver/build-driver.sh` 复制/修改本机 `BlackHole2ch.driver`；`build-pkg.sh` 打包生成的 `vRemoteDriver.driver`；应用通过 CoreAudio 使用虚拟设备 | GNU GPL v3；源文件头为 `Copyright (C) 2019 Existential Audio Inc.` | 驱动不受本仓库 MIT 替代。保留驱动版权、GPL 全文、修改说明与对应源码；详见第 4 节。实际输入二进制的版本与版权仍需逐包核验 |
| [TelemetryDeck 固定 revision LICENSE](https://github.com/TelemetryDeck/SwiftSDK/blob/bc7467592166e8f93fbde0140d2757b0635e1712/LICENSE)、[Package.swift](https://github.com/TelemetryDeck/SwiftSDK/blob/bc7467592166e8f93fbde0140d2757b0635e1712/Package.swift) | 清理前 `Package.swift`/`Package.resolved` 唯一 SwiftPM 外部依赖，版本 `2.9.10`；`AnalyticsSupport.swift` | **修改版 MIT，移除了署名保留条款**；`Copyright (c) 2020 Daniel Jilg` | 不应误报成标准 MIT 的强制署名要求。该固定版本明确不要求在副本中附许可；移除依赖与初始化后不再进入新构建。其 Package.swift 没有外部依赖 |
| [Google Voice over BLE v1.0（现有记录中的镜像）](https://wangefan.github.io/linux_kernel_driver/resources/Google_Voice_over_BLE_spec_v1.0.pdf) | 协议参考；没有 PDF 文件打包进仓库 | 没有在本次查得独立再分发授权；参考资料不是代码许可 | 保留资料来源，避免把镜像或协议资料标成 MIT；若要复制文档、图表或大量文字，另核实授权 |
| Apple SDK / 系统资源 | `AppKit`、`SwiftUI`、`CoreBluetooth`、`CoreAudio`、`AVFoundation`、`CoreGraphics`、`ApplicationServices`、`IOKit` 等系统调用与系统符号/字体 | 平台 SDK/系统资源，不是本仓库自行授权的第三方源码 | 仓库未跟踪 SDK、字体文件或 framework 二进制；发布时按适用 Apple 工具和资源条款检查，不把系统符号/字体称为用户原创 |

### 继承功能代码的范围

不能因为重写了窗口，就删除以下功能实现的来源说明。清理起点这些文件已存在于上游；当前修改可能改变内容，但不会自动消除来源：

- 传输与音频：`ATVV/*`、`BLEBridge.swift`、`ChromecastRemoteHIDBridge.swift`、`AudioPipe.swift`、`WavRecorder.swift`
- 系统集成：`AppStorage.swift`、`InputTrigger.swift`、`DoubaoAudioStateMonitor.swift`、`LaunchAtLogin.swift`、`Localization.swift`、`Log.swift`
- 映射和应用胶水：`RemoteMappingSupport.swift`、`main.swift`、`DebugWindowController.swift` 中保留的权限帮助、快捷键录制及窗口/模型代码
- 仍待拆分的旧命名实现：`X6SearchSuppressor.swift` 的键盘触发监听、`X6SessionCoordinator.swift` 中被 Chromecast 使用的共享类型；删除旧类后，提取出来的代码仍保留来源
- 安装及开发工具：`Driver/*`、`Packaging/*`、`package-app.sh`、`build-pkg.sh`、`build-dmg.sh`、`install-app.sh`、`run-self-tests.sh` 及未删除的原有工具

新增的 Chromecast 状态机、设置档案、引导证据、主题/程序坞设置、测试等已由 Git 历史区分；新增文件名不应被当作完全独立创作的法律结论。本次不更换仓库的整体许可。

## 3. 图像、图标、原型与品牌

| 文件 / 资源族 | 当前来源证据 | 处理原则 |
| --- | --- | --- |
| `Resources/RemoteImages/chromecast-front-and-volume-enhanced.png` 与原型中的内嵌遥控器图 | 现有替换台账记录为用户提供图片，经 AI 增强正面并重建侧面音量示意 | 当前 UI 所需，应保留。未确认原照片拍摄者、商业分发授权或 AI 修复细节的实物准确性；AI 增强不自动清除原图权利。正式发布前由用户确认或替换 |
| `Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png` | 上游品牌图，清理前被 `LogoAsset` 与打包脚本直接使用 | 不能无替代直接删除，否则丢失应用图标/打包失败；让用户指定新图标。根 MIT 未提供可独立核对的品牌/商标授权证明 |
| 其余 `Design/vRemoter-Logo-v1/*`、`Design/vRemoter-UI-v1-Frozen/*`、`Design/UIv1_bak.fig` | 上游设计历史和 Figma 插件，没有单独资产权利清单 | 不属于原生运行时；可在确认无打包引用后移除。不能把保留图形重新署名为用户原创 |
| `Resources/PermissionGuides/*.png` | 上游 macOS / 豆包界面截图；`README.md` 仅说明如何替换截图 | 权限帮助仍会读取，保留或以用户自己的最新截图替换；没有逐图作者或额外许可证据 |
| `Resources/RemoteImages/chromecast-voice-remote.png`、`x6-remote.png` | 上游遥控器商品图，独立来源未记录 | 旧映射视图删除并确认无引用后可移除；保留或对外使用时须核实照片来源 |
| `Resources/Commerce/*`、`Resources/buymeacoffee/*`、旧 `docs/assets/*` | 上游营销、收款二维码、品牌、截图和商品图 | 不是许可强制保留内容。停用旧推广后整组移除其代码/页面/打包引用；不要把原收款渠道替换成未经指定的新渠道 |
| `docs/prototypes/vremoter-onboarding-settings.html` | 用户批准并归档的离线 UI 原型；[原型说明](prototypes/README.md) | 保留作实现与交互验收依据。其内嵌图片遵循本表第一行；系统字体栈没有分发字体文件。内联 SVG 图标未标注第三方图标库来源，本次未逐个建立创作来源，不能仅凭没有外部依赖称全部图形原创 |
| SayAll / `HD838A/remote-mic-app` | [固定参考提交](https://github.com/HD838A/remote-mic-app/tree/5a10bba28bd1514892a2a7400ae594629f728da7)；GPL-3.0-only 软件与独立品牌许可 | 参考了交互和视觉布局，没有为本实现复制其源代码或私有 Chromecast 模块。其鸭子图标等品牌资产另受 [LOGO-LICENSE.en.md](https://github.com/HD838A/remote-mic-app/blob/5a10bba28bd1514892a2a7400ae594629f728da7/LOGO-LICENSE.en.md) 限制，**不得借用为本项目图标**。今后复制任何代码或资源前须重新审查 |

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

审计起点 `package-app.sh` 未复制根 `LICENSE` 或 `THIRD_PARTY_NOTICES.md`；这是必须补上的打包缺口。下方集中 MIT 通知可随应用附带（仅适用于所列 MIT 部分，**不替代 BlackHole GPL**）。Maddison 的行在逐行来源复核前保守保留。

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
