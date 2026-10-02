#!/usr/bin/env python3
"""Inspect the actual app-only package after package-app.sh succeeds on macOS.

This verifies packaged resources and notices. Compilation and codesign validation
belong to package-app.sh; this does not inspect or approve a driver/PKG release.
"""
from pathlib import Path
import argparse
import os
import plistlib

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("app", nargs="?", default=str(root / "dist/build/vRemote.app"))
args = parser.parse_args()
app = Path(args.app).resolve()
contents = app / "Contents"
resources = contents / "Resources"
checks = 0


def check(condition, message):
    global checks
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    checks += 1


check(app.is_dir(), f"app bundle does not exist: {app}")
check((contents / "Info.plist").is_file(), "packaged Info.plist is missing")
info = plistlib.loads((contents / "Info.plist").read_bytes())
source_info = plistlib.loads((root / "Packaging/Info.plist").read_bytes())
check(info == source_info, "packaged Info.plist differs from reviewed source")
for key in ["VRReleasesURL", "VRCommerceConfigURL", "VRTelemetryDeckAppID", "VRTelemetryDeckNamespace"]:
    check(key not in info, f"obsolete configuration key is packaged: {key}")
check(info["LSMinimumSystemVersion"] == "12.0", "macOS 12 minimum changed")

binary = contents / "MacOS" / info["CFBundleExecutable"]
check(binary.is_file(), "app executable is missing")
check(os.access(binary, os.X_OK), "app executable is not executable")
with binary.open("rb") as executable:
    magic = executable.read(4)
check(magic in [b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
                b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"],
      "app executable is not a Mach-O binary")

for name, source in [
    ("LICENSE", "LICENSE"),
    ("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md"),
    ("PROJECT_OWNERSHIP_AND_LICENSES.md", "docs/PROJECT_OWNERSHIP_AND_LICENSES.md"),
]:
    packaged = resources / "Licenses" / name
    check(packaged.is_file(), f"required notice is missing: {name}")
    check(packaged.read_bytes() == (root / source).read_bytes(), f"notice content differs: {name}")

photo_name = "chromecast-front-and-volume-enhanced.png"
photos = resources / "RemoteImages"
check(photos.is_dir(), "active remote image directory is missing")
check(sorted(path.name for path in photos.iterdir()) == [photo_name], "unexpected or missing remote images")
check((photos / photo_name).read_bytes() == (root / "Resources/RemoteImages" / photo_name).read_bytes(),
      "active remote image differs from source")

logo = resources / "vRemoterLogo.png"
check(logo.is_file(), "app/menu logo is missing")
check(logo.read_bytes() == (root / "Design/vRemoter-Logo-v1/vRemoter-app-icon-v9.png").read_bytes(),
      "app/menu logo differs from source")
icon = resources / info["CFBundleIconFile"]
check(icon.is_file(), "compiled app icon is missing")
check(icon.read_bytes()[:4] == b"icns" and icon.stat().st_size > 8, "compiled app icon is not a valid ICNS container")

guides = resources / "PermissionGuides"
source_guides = root / "Resources/PermissionGuides"
expected_guides = sorted(path.name for path in source_guides.glob("*.png"))
check(len(expected_guides) == 8, "source permission-guide inventory changed; review packaging requirements")
check(sorted(path.name for path in guides.glob("*.png")) == expected_guides, "packaged permission guides are incomplete")
for name in expected_guides:
    check((guides / name).read_bytes() == (source_guides / name).read_bytes(), f"permission guide differs: {name}")

for localization in (root / "Packaging").glob("*.lproj"):
    for source in localization.rglob("*"):
        if source.is_file():
            relative = source.relative_to(root / "Packaging")
            destination = resources / relative
            check(destination.is_file() and destination.read_bytes() == source.read_bytes(),
                  f"localization is missing or differs: {relative}")

for path in contents.rglob("*"):
    relative = path.relative_to(contents)
    lower = str(relative).lower()
    check(not any(word in lower for word in ["telemetrydeck", "commerce", "buymeacoffee"]),
          f"obsolete promotion/telemetry resource is packaged: {relative}")
    check(path.name not in ["chromecast-voice-remote.png", "x6-remote.png"], f"legacy remote image is packaged: {relative}")
check(not list(resources.rglob("*.bundle")), "dependency resource bundle unexpectedly included in dependency-free app")

print(f"PASS: {checks} actual app-bundle content checks: {app}")
print("Driver/PKG content and distribution-license compliance are not covered by this app-only check.")
