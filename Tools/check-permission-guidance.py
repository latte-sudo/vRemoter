#!/usr/bin/env python3
"""Offline source boundaries; native focus/rendering/TCC require Mac acceptance."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
controller = (root / 'Sources/vRemote/PermissionFollowAlongController.swift').read_text()
model = (root / 'Sources/vRemote/DebugWindowController.swift').read_text()
view = (root / 'Sources/vRemote/ChromecastConsoleView.swift').read_text()
main = (root / 'Sources/vRemote/main.swift').read_text()
support = (root / 'Sources/vRemote/PermissionFollowAlongSupport.swift').read_text()
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


for forbidden in ['CGWindowListCreateImage', 'CGDisplayStream', 'CGRequestScreenCaptureAccess',
                  'SCShareableContent', 'AXUIElement', 'AXIsProcessTrustedWithOptions',
                  'CGRequestListenEventAccess', 'addGlobalMonitorForEvents',
                  'addLocalMonitorForEvents', 'kCGWindowName', 'CGEvent(',
                  'makeKeyAndOrderFront', 'activate(ignoringOtherApps', 'NSWorkspace.shared.open']:
    check(forbidden not in controller, 'guide must not capture/request/automate/activate: ' + forbidden)
for required in ['.nonactivatingPanel', 'panel.hidesOnDeactivate = false',
                 'panel.becomesKeyOnlyIfNeeded = true', 'panel.orderFrontRegardless()',
                 'CGWindowListCopyWindowInfo', 'owner == pid', 'layer == 0',
                 'frontmost ? settingsWindow', 'NSScreen.screens.first?.frame.maxY',
                 'timer?.invalidate()', 'workspaceObservers.removeAll()',
                 'removeObserver(closeObserver)', 'removeObserver(terminationObserver)',
                 'expected == generation', 'self?.generation == currentGeneration',
                 'authorization(permission) == .authorized', 'CFBundleDisplayName']:
    check(required in controller, 'guide lifecycle/privacy contract missing: ' + required)
refresh = model.split('func refreshPermissions() {', 1)[1].split('@discardableResult', 1)[0]
check('beginPermissionGuidance' not in refresh and '.request(' not in refresh, 'refresh must stay read-only')
check('result == .requested || result == .openSettings' in model, 'only eligible explicit requests start the guide')
check('permissionGuidanceActive = permissionFollowAlong.begin(permission)' in model, 'initial end must win over active flag')
check('NSWorkspace.shared.open(url), let permission = kind.requestablePermission' in model, 'failed settings open must not start a guide')
check('func windowWillClose' in model and 'stopPermissionGuidance()\n        permissionTimer?' in model, 'console close must stop guidance')
check('onCancel: { model.stopPermissionGuidance();' in model, 'modal cancel must stop guidance')
check('.onDisappear { model.stopPermissionGuidance() }' in view, 'view removal must stop guidance')
for state in ['step', 'page', 'setup']:
    body = view.split(f'.onChange(of: {state})', 1)[1].split('.onChange', 1)[0]
    check('model.stopPermissionGuidance()' in body, state + ' transitions must stop guidance')
check('debugWindow.stopPermissionGuidance()' in main.split('func applicationWillTerminate', 1)[1], 'quit must clean synchronously')
check('openingGracePeriod: TimeInterval = 60' in support and '!hasFollowed &&' in support, 'timeout must apply only to startup')
check('PermissionFollowAlongTests.swift' in (root / 'Tools/test-chromecast-models.sh').read_text(), 'lifecycle regressions not in CI')
check('check-permission-guidance.py' in (root / '.github/workflows/chromecast-validation.yml').read_text(), 'source contracts not in CI')
notices = (root / 'THIRD_PARTY_NOTICES.md').read_text()
for required in ['1b6c95cef032c15ada8c60dc1bdeb21a316ff353', 'Copyright (c) 2026 Leo', 'Copyright (c) 2026 The Maka Authors']:
    check(required in notices, 'upstream source/license notice missing: ' + required)
check('.macOS(.v12)' in (root / 'Package.swift').read_text(), 'minimum OS unexpectedly changed')
tasks = re.findall(r'Task\s*\{\s*@MainActor([^\n]*)', controller)
check(tasks and all('[weak self]' in capture for capture in tasks),
      'nested actor tasks must recapture self instead of sharing a mutable weak capture')
termination = controller.split('terminationObserver = NotificationCenter.default.addObserver(', 1)[1].split('let timer =', 1)[0]
check('self?.generation == currentGeneration' in termination,
      'a queued termination callback must not stop a replacement session')
print(f'PASS: {checks} permission follow-along source contracts (not native focus, permission or rendering acceptance)')
