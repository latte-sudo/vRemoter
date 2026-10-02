#!/usr/bin/env python3
"""Source-contract checks, not a replacement for macOS build/UI/hardware tests."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
view = (root / 'Sources/vRemote/ChromecastConsoleView.swift').read_text()
tokens = (root / 'Sources/vRemote/ConsoleDesignTokens.swift').read_text()
prototype = (root / 'docs/prototypes/vremoter-onboarding-settings.html').read_text()
progress = (root / 'Sources/vRemote/OnboardingProgress.swift').read_text()
checks = 0
def check(condition, message):
    global checks
    assert condition, message
    checks += 1
steps = re.search(r'private let steps = \[(.*?)\]', view).group(1)
check(len(re.findall(r'"[^"]+"', steps)) == 7, 'exactly seven onboarding steps')
check('static let stepCount = 7' in progress, 'migration matches UI')
check('return min(normalized, trialStep)' in progress, 'resume cannot reuse persisted trial proof')
for title in ['语音和音频', '遥控器', '权限与诊断', '设置']:
    check(f'return "{title}"' in view, 'four native settings destinations')
for name, light, dark in re.findall(r'static let (\w+) = color\(0x([0-9a-f]+), 0x([0-9a-f]+)\)', tokens):
    check('#' + light in prototype or light == 'ffffff', f'{name} light matches prototype')
    check('#' + dark in prototype, f'{name} dark matches prototype')
for contract in ['ChromecastMappingCanvas(', 'ChromecastGlobalVoiceHeader(model: model)',
                 'model.voicePresentation.elapsed(at: date)', 'model.onStopMicrophone?()',
                 'ChromecastSettingsArchive.validate', 'confirmReplacement(title:',
                 'userConfirmedRecognition: confirmedSpeech', 'TextEditor(text: $testText)',
                 'model.voicePresentation.phase == .ended', '.onChange(of: testText)',
                 'accessibilityReduceMotion', '先检查必要权限', 'model.voicePresentation.startedAt != nil']:
    check(contract in view, contract)
check('撤销' not in view, 'no visible undo action')
check('testText = "你好' not in view, 'no synthetic recognition text')
check('private enum ChromecastMappingPhoto' not in (root / 'Sources/vRemote/ChromecastMappingCanvas.swift').read_text(), 'same real photo reused')
main = (root / 'Sources/vRemote/main.swift').read_text()
remote_only = 'AudioPipe.shared.setInputEnabled(mac: false, remote: true)'
check(remote_only in main, 'startup applies remote-only mode to cached audio state')
for start in ['chromecastHID.start()', 'chromecastBLE.start()', 'chromecastSession.start()']:
    check(main.index(remote_only) < main.index(start), 'remote-only state precedes ' + start)
sidebar = view[view.index('private var sidebar'):view.index('private func stepCompleted')]
for contract in ['.frame(width: ConsoleDesignTokens.sidebarWidth, alignment: .leading)',
                 '.accessibilityLabel(item.title)', 'Text(item.title).multilineTextAlignment(.leading)',
                 'Text(steps[index])', '.fixedSize(horizontal: false, vertical: true)']:
    check(contract in sidebar, 'left-aligned accessible sidebar: ' + contract)
check('Label(item.title, systemImage: item.symbol)' not in sidebar, 'sidebar layout remains explicit')
indicator = (root / 'Sources/vRemote/MenuBarVoiceReception.swift').read_text()
for contract in ['phase == .opening || phase == .recording', 'streaming &&',
                 'if !acceptsAudio { lastPacketAt = nil }', 'age < Self.packetFreshness']:
    check(contract in indicator, 'menu dot requires live PCM: ' + contract)
for contract in ['voiceReception.receivedPacket(at:', 'RunLoop.main.add(timer, forMode: .common)',
                 'voiceReceptionTimer?.invalidate()', 'setAccessibilityLabel(label)',
                 'self.updateMenuVoiceIndicator()']:
    check(contract in main, 'menu dot lifecycle: ' + contract)
check('MenuBarVoiceReceptionTests.swift' in (root / 'Tools/test-chromecast-models.sh').read_text(), 'menu dot regressions run in CI')
icon = (root / 'Sources/vRemote/MenuBarStatusIcon.swift').read_text()
for contract in ['LogoAsset.image.draw', 'NSColor.systemGreen.setFill()', 'image.isTemplate = false']:
    check(contract in icon, 'menu dot rendering: ' + contract)
print(f'PASS: {checks} native interface source contracts (not runtime UI tests)')
