#!/usr/bin/env python3
"""Offline current-branding and retained-provenance contracts.

These checks do not approve a final name, asset rights, a namespace migration,
or a release. Native presentation and macOS packaging still require macOS QA.
"""
from pathlib import Path
import hashlib
import json
import plistlib
import re

root = Path(__file__).resolve().parent.parent
checks = 0


def check(condition, message):
    global checks
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    checks += 1


def text(relative):
    return (root / relative).read_text()


def strings(relative):
    return dict((json.loads(key), json.loads(value)) for key, value in
                re.findall(r'^("(?:\\.|[^"\\])*") = ("(?:\\.|[^"\\])*");$', text(relative), re.M))


names = {"en": "Remote Voice Utility", "zh-Hans": "遥控器语音工具", "zh-Hant": "遙控器語音工具"}
info = plistlib.loads((root / "Packaging/Info.plist").read_bytes())
for field in ["CFBundleName", "CFBundleDisplayName"]:
    check(info[field] == names["en"], f"default {field} must use the descriptive placeholder")
check(info["CFBundleIconFile"] == "AppIcon.icns", "neutral packaged icon name changed")
check(info["CFBundleIdentifier"] == "local.simaqingfeng.vRemote", "bundle migration requires separate review")
check(info["CFBundleExecutable"] == "vRemote", "executable migration requires separate review")
for locale, name in names.items():
    table = strings(f"Sources/vRemote/Resources/{locale}.lproj/Localizable.strings")
    metadata = strings(f"Packaging/{locale}.lproj/InfoPlist.strings")
    check(table["shell.window.title"] == name, f"{locale} window name")
    check(table["console.brand.placeholder"], f"{locale} final-name TODO must remain visible")
    check(metadata["CFBundleName"] == metadata["CFBundleDisplayName"] == name, f"{locale} app metadata name")
    for key, value in table.items():
        # Actual .app paths and virtual-device labels remain actionable compatibility text.
        remainder = value.replace("vRemote.app", "").replace("vRemoteDr 2ch", "")
        check(not re.search(r"vRemot(?:e|er)|Sima Qingfeng|VincentKingHsu", remainder), f"{locale}:{key}: old product/author UI label")

for path in ["Sources/vRemote/ChromecastConsoleView.swift", "Sources/vRemote/DebugWindowController.swift", "Sources/vRemote/main.swift"]:
    check('"vRemoter' not in text(path), f"hardcoded old product name in {path}")
debug = text("Sources/vRemote/DebugWindowController.swift")
for obsolete in ["GuideAsset", "GuideScreenshot", "screenshotNames", "vRemoterLogo", 'let text = "vR"']:
    check(obsolete not in debug, f"old branded image reference remains: {obsolete}")
check("PermissionIllustration(kind: kind" in debug and "var pageCount: Int { guidance.count }" in debug,
      "native permission pages must follow localized guidance")
check('Text(L10n.tr("permission.guide.illustration"))' in debug, "schematic disclaimer must be visible in every language")
check(not (root / "Design/vRemoter-Logo-v1").exists(), "inherited logo assets remain")
check(not list((root / "Resources/PermissionGuides").glob("*.png")), "inherited permission screenshots remain")
check((root / "Resources/AppIcon/placeholder-app-icon.png").is_file(), "placeholder icon source missing")
package = text("package-app.sh")
check('Resources/AppIcon/placeholder-app-icon.png' in package, "packager missing neutral icon")
check('vRemoterLogo' not in package and 'PermissionGuides' not in package, "packager references inherited artwork")
check('-volname "Remote Voice Utility $VERSION"' in text("build-dmg.sh"), "DMG volume label must be neutral")

# These persisted namespaces are deliberately not product-display strings.
for path, tokens in {
    "Package.swift": ['name: "vRemote"'],
    "Sources/vRemote/Localization.swift": ['"vRemoter.appLanguage"', '"vRemoter.appLanguageDidChange"'],
    "Sources/vRemote/AppAppearance.swift": ['"vRemoter.appAppearance"'],
    "Sources/vRemote/AppStorage.swift": ['"Library/Logs/vRemote"', '"vRemote.log"', '"Library/Application Support/vRemote"'],
    "Sources/vRemote/LaunchAtLogin.swift": ['"local.simaqingfeng.vRemote.login"'],
    "package-app.sh": ['identifier "local.simaqingfeng.vRemote"', 'dist/build/vRemote.app'],
    "build-pkg.sh": ['local.simaqingfeng.vRemoter.pkg'],
    "Driver/build-driver.sh": ['audio.local.vRemoteDriver2chXX', 'vRemoteDr%ich_UID'],
}.items():
    for token in tokens:
        check(token in text(path), f"compatibility identity changed in {path}: {token}")

# Historical artifact and mandatory root legal text stay exact, rather than
# silently rewriting previously delivered bytes or replacing attribution.
for relative, expected in {
    "docs/prototypes/vremoter-onboarding-settings.html": "1be72597d1fa5cffa7263631b1d5bc8aef4bdd75280be69a5a2cbbcf799a27cf",
    "LICENSE": "9b3509d7d81808b4f5d9efda265fde42c2b39097cc00b7a9b4a618e1547e7f8e",
}.items():
    check(hashlib.sha256((root / relative).read_bytes()).hexdigest() == expected, f"protected historical/legal bytes changed: {relative}")
notices = text("THIRD_PARTY_NOTICES.md")
for owner in ["Sima Qingfeng", "FanXeon@Poemcoder with Codex", "Maddison Cohodas", "Existential Audio"]:
    check(owner in notices, f"required provenance missing: {owner}")
for name in ["ADPCMDecoder.swift", "ATVVProtocol.swift", "BridgeError.swift"]:
    check("FanXeon" in text("Sources/vRemote/ATVV/" + name).splitlines()[0], f"source attribution missing: {name}")
current = text("docs/prototypes/remote-voice-utility-onboarding-settings.html")
visible_current = current
for stable in ["vremoter-ui-prototype-v1", "vremoter-html-prototype", "__vremoter_user_tool_label__"]:
    visible_current = visible_current.replace(stable, "")
check("vremoter" not in visible_current.lower(), "current prototype contains inherited product branding")
for retained in ["vremoter-ui-prototype-v1", "vremoter-html-prototype", "vRemoteDr 2ch"]:
    check(retained in current, f"prototype compatibility identity changed: {retained}")
check("final product name" in current.lower() and "TODO" in text("TODO.md"), "final identity decision not documented")
print(f"PASS: {checks} neutral-branding, provenance and compatibility source contracts")
print("NOT RUN here: macOS rendering, hardware, installation, signing or release acceptance")
