#!/usr/bin/env python3
"""Source-contract checks, not a replacement for macOS build/UI/hardware tests."""
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
view = (root / 'Sources/vRemote/ChromecastConsoleView.swift').read_text()
tokens = (root / 'Sources/vRemote/ConsoleDesignTokens.swift').read_text()
prototype = (root / 'docs/prototypes/remote-voice-utility-onboarding-settings.html').read_text()
progress = (root / 'Sources/vRemote/OnboardingProgress.swift').read_text()
checks = 0
def check(condition, message):
    global checks
    assert condition, message
    checks += 1
steps = re.search(r'private var steps: \[String\] \{ \[(.*?)\]', view).group(1)
check(len(re.findall(r'"[^"]+"', steps)) == 7, 'exactly seven onboarding steps')
check('static let stepCount = 7' in progress, 'migration matches UI')
check('return min(normalized, trialStep)' in progress, 'resume cannot reuse persisted trial proof')
for title in ['voice', 'remote', 'permissions', 'settings']:
    check(f'return L10n.tr("console.page.{title}")' in view, 'four native settings destinations')
for name, light, dark in re.findall(r'static let (\w+) = color\(0x([0-9a-f]+), 0x([0-9a-f]+)\)', tokens):
    check('#' + light in prototype or light == 'ffffff', f'{name} light matches prototype')
    check('#' + dark in prototype, f'{name} dark matches prototype')
for contract in ['ChromecastMappingCanvas(', 'ChromecastGlobalVoiceHeader(model: model)',
                 'model.voicePresentation.elapsed(at: date)', 'model.onStopMicrophone?()',
                 'ChromecastSettingsArchive.validate', 'confirmReplacement(title:',
                 'userConfirmedRecognition: confirmedSpeech', 'TextEditor(text: $testText)',
                 'model.voicePresentation.phase == .ended', '.onChange(of: testText)',
                 'accessibilityReduceMotion', 'console.connection.checkPermissionsFirst', 'model.voicePresentation.startedAt != nil']:
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
# Window chrome reserves title-bar space exactly once: AppKit supplies the safe
# area; content adds only a compact 52-point header and 12-point sidebar inset.
header = view[view.index('private var header:'):view.index('@ViewBuilder private var onboardingContent:')]
check('static let headerHeight: CGFloat = 52' in tokens, 'compact native header token')
check('.frame(height: ConsoleDesignTokens.headerHeight)' in header, 'native header uses shared compact height')
check('.padding(.top,' not in header, 'no duplicate manual title-bar top reservation')
check('.padding(.top, 12)' in sidebar and '.padding(.top, 45)' not in sidebar, 'sidebar removes duplicate title-bar gap')
check('languagePicker' not in sidebar, 'language setting removed from sidebar')
settings = view[view.index('private var settings:'):view.index('private var diagnostics:')]
basic = settings[settings.index('console.settings.basic'):settings.index('console.settings.startup')]
check(basic.count('ConsoleCard {') == 1, 'language and appearance share one Basic Settings card')
for contract in ['languagePicker.labelsHidden()', 'ConsoleAppearancePicker(selection: $appearance)', 'ConsoleAppearanceSummary(selection: appearance)', 'language.help']:
    check(contract in basic, 'basic settings retains ' + contract)
for section in ['console.settings.startup', 'console.backup.title', 'console.settings.restore']:
    check(section in settings, 'preserves separate settings section ' + section)
summary = tokens[tokens.index('struct ConsoleAppearanceSummary:'):]
for contract in ['@Environment(\\.colorScheme)', 'selection.resolved(isSystemDark: colorScheme == .dark)', 'ConsoleDesignTokens.window', 'ConsoleDesignTokens.sidebar', 'ConsoleDesignTokens.surface', 'ConsoleDesignTokens.accent', '.accessibilityHidden(true)']:
    check(contract in summary, 'live appearance colors and accessibility: ' + contract)
controller = (root / 'Sources/vRemote/AppAppearanceController.swift').read_text()
check('case .system: NSApp.appearance = nil' in controller, 'System keeps automatic macOS appearance propagation')
check('ignoresSafeArea' not in view, 'native controls retain AppKit title-bar clearance')
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
