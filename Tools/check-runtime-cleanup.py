#!/usr/bin/env python3
"""Static cleanup contracts; these do not replace a macOS build or hardware tests."""
from pathlib import Path
import json
import plistlib
import re

root = Path(__file__).resolve().parent.parent
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


removed_paths = [
    "Sources/vRemote/X6HIDBridge.swift",
    "Sources/vRemote/X6SessionCoordinator.swift",
    "Sources/vRemote/X6SearchSuppressor.swift",
    "Sources/vRemote/VoiceSessionSelfTest.swift",
    "Tools/generate-qr.swift",
    "Design/UIv1_bak.fig",
    "Design/vRemoter-UI-v1-Frozen",
    "Sources/vRemote/AnalyticsSupport.swift",
    "Sources/vRemote/CommerceSupport.swift",
    "Sources/vRemote/DonationSupport.swift",
    "Sources/vRemote/UpdateSupport.swift",
    "Resources/Commerce",
    "Resources/buymeacoffee",
    "Resources/RemoteImages/chromecast-voice-remote.png",
    "Resources/RemoteImages/x6-remote.png",
    "SelfTests/Fixtures/commerce-two-stores.json",
    "SelfTests/Fixtures/releases-current.json",
    "SelfTests/Fixtures/releases-new.json",
]
for path in removed_paths:
    check(not (root / path).exists(), f"obsolete runtime input remains: {path}")

runtime_files = list((root / "Sources/vRemote").rglob("*.swift"))
runtime_files += list((root / "Packaging").rglob("*.plist"))
runtime_files += [root / "Package.swift", root / "package-app.sh"]
forbidden = re.compile(
    r"AppAnalytics|TelemetryDeck|CommerceConfig|CommerceStore|CommerceAsset|"
    r"Donation(?:Asset|Provider|Prompt|View)|Purchase(?:View|QRCode)|"
    r"UpdateWindow|VRReleasesURL|VRCommerceConfigURL|VRTelemetryDeck|"
    r"updates\.vincentstudio\.org|0B41E7AD-49DA-4A8F-B216-BCF13B3A2D25|"
    r"--(?:purchase|donation-prompt|update-available|update-current|updates-window)-demo"
)
for path in runtime_files:
    check(not forbidden.search(path.read_text()), f"obsolete runtime reference: {path}")

resolved = root / "Package.resolved"
if resolved.exists():
    check(not json.loads(resolved.read_text())["pins"], "unexpected dependency pins")
manifest = (root / "Package.swift").read_text()
check(".package(" not in manifest, "unexpected external Swift package")
check(".macOS(.v12)" in manifest, "macOS 12 minimum must be preserved")

debug = (root / "Sources/vRemote/DebugWindowController.swift").read_text()
for declaration in [
    "StudioMixerView", "ConsolePageSelector", "ConsolePage", "KeyMappingView",
    "DeviceSelectionRow", "MappingRow", "RemoteProductImage", "InputChannelView",
    "OutputChannelView", "MeterView", "RemoteImageAsset", "StatusTone", "StatusPill", "StatusRow",
]:
    check(not re.search(r"\b" + declaration + r"\b", debug), f"legacy UI remains: {declaration}")
for declaration in [
    "ConsoleViewModel", "DebugWindowController", "PermissionKind",
    "PermissionGuideView", "PermissionIllustration", "ConsoleModalContent", "ConsoleTheme",
    "KeyboardShortcutCaptureView", "KeyboardEventCaptureView", "KeyboardCaptureNSView",
    "ConsoleButtonStyle", "ConsoleButtonTone", "LogoAsset",
]:
    check(re.search(r"\b" + declaration + r"\b", debug), f"shared UI missing: {declaration}")

main = (root / "Sources/vRemote/main.swift").read_text()
for startup in ["chromecastHID.start()", "chromecastBLE.start()", "chromecastSession.start()", "keyboardTriggerObserver.start()"]:
    check(startup in main, f"active runtime startup missing: {startup}")
for source in ["KeyboardTriggerObserver.swift", "KeyboardTriggerState.swift", "RemoteVoiceSupport.swift", "BLEBridge.swift", "RemoteMappingSupport.swift"]:
    check((root / "Sources/vRemote" / source).exists(), f"active shared source missing: {source}")

# Legacy migration keys are intentionally permitted only at the archive boundary.
for path in (root / "Sources/vRemote").rglob("*.swift"):
    if path.name == "ChromecastSettingsArchive.swift":
        continue
    check(not re.search(r"\bX6\w*|\bx6\w*|VoiceRemoteID|VoiceSessionSelfTest|--voice-session-self-test", path.read_text()),
          f"retired remote runtime reference: {path}")
observer = (root / "Sources/vRemote/KeyboardTriggerObserver.swift").read_text()
for contract in ["options: .listenOnly", "CFMachPortInvalidate(tapPort)", "CFRunLoopRemoveSource", "triggerState.reset()", "Key.syntheticMarker"]:
    check(contract in observer, f"keyboard observer safety contract missing: {contract}")
check("return nil" not in observer, "keyboard observation must not suppress events")
check("chromecastBLE.clearRecordings()" in main, "recording cleanup must close the active recorder")
voice_runner = (root / "run-chromecast-voice-tests.sh").read_text()
check("RemoteVoiceSupport.swift" in voice_runner, "voice tests must use production shared contracts")
voice_tests = (root / "SelfTests/ChromecastVoice/main.swift").read_text()
for duplicate in ["enum RemoteMicrophoneOpenResult", "protocol DoubaoAudioStateProviding"]:
    check(duplicate not in voice_tests, f"voice suite shadows production contract: {duplicate}")
model_runner = (root / "Tools/test-chromecast-models.sh").read_text()
check("KeyboardTriggerStateTests.swift" in model_runner, "keyboard edge regressions not wired into CI")

plist = plistlib.loads((root / "Packaging/Info.plist").read_bytes())
check("NSMicrophoneUsageDescription" not in plist, "retired Mac-microphone purpose remains")
for locale in ["en.lproj", "zh-Hans.lproj"]:
    check("NSMicrophoneUsageDescription" not in (root / "Packaging" / locale / "InfoPlist.strings").read_text(), "retired localized Mac-microphone purpose remains")
check(plist["CFBundleIdentifier"] == "local.simaqingfeng.vRemote", "bundle identity unexpectedly changed")
check(plist["LSMinimumSystemVersion"] == "12.0", "packaged macOS minimum unexpectedly changed")
package = (root / "package-app.sh").read_text()
check("*.bundle" not in package, "generic bundle copy can include stale telemetry resources")
for name in ["LICENSE", "THIRD_PARTY_NOTICES.md", "PROJECT_OWNERSHIP_AND_LICENSES.md"]:
    check(f'"$CONTENTS/Resources/Licenses/{name}"' in package, f"packaged notice missing: {name}")
check("Copyright (c) 2026 Sima Qingfeng" in (root / "LICENSE").read_text(), "upstream copyright missing")
for name in ["ADPCMDecoder.swift", "ATVVProtocol.swift", "BridgeError.swift"]:
    check("FanXeon" in (root / "Sources/vRemote/ATVV" / name).read_text().splitlines()[0], f"source attribution missing: {name}")

print(f"PASS: {checks} runtime cleanup source contracts (not a macOS build or hardware test)")
