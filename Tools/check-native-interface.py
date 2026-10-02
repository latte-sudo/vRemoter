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
                 'accessibilityReduceMotion']:
    check(contract in view, contract)
check('撤销' not in view, 'no visible undo action')
check('testText = "你好' not in view, 'no synthetic recognition text')
check('private enum ChromecastMappingPhoto' not in (root / 'Sources/vRemote/ChromecastMappingCanvas.swift').read_text(), 'same real photo reused')
print(f'PASS: {checks} native interface source contracts (not runtime UI tests)')
