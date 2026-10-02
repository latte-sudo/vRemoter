#!/usr/bin/env python3
"""Exercise resource packaging in an isolated fixture with fake macOS build tools.

This checks shell/copy behavior, including a dirty build folder. It does not build
Swift, produce a usable app, validate signatures, or inspect a real driver bundle.
"""
from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
zsh = shutil.which("zsh")
if not zsh:
    raise SystemExit("zsh is required for the isolated packaging fixture")

fake_tool = '''#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
if tool == "swift":
    assert args == ["build", "-c", "release"]
    release = Path(".build/release")
    release.mkdir(parents=True, exist_ok=True)
    (release / "vRemote").write_text("Fixture executable, not a macOS binary")
    stale = release / "TelemetryDeck_SwiftSDK.bundle"
    stale.mkdir(exist_ok=True)
    (stale / "PrivacyInfo.xcprivacy").write_text("Stale removed dependency")
elif tool == "ditto":
    shutil.copytree(args[0], args[1], dirs_exist_ok=True)
elif tool == "sips":
    shutil.copyfile(args[3], args[args.index("--out") + 1])
elif tool == "iconutil":
    Path(args[args.index("-o") + 1]).write_text("Fixture icon, not an ICNS file")
elif tool not in {"xattr", "codesign"}:
    raise SystemExit("Unexpected fixture command: " + tool)
'''

with tempfile.TemporaryDirectory(prefix="vremote-package-fixture-") as temporary:
    fixture = Path(temporary)
    sources = [
        "package-app.sh", "Packaging/Info.plist", "LICENSE", "THIRD_PARTY_NOTICES.md",
        "docs/PROJECT_OWNERSHIP_AND_LICENSES.md",
        "Resources/AppIcon/placeholder-app-icon.png",
        "Resources/RemoteImages/chromecast-front-and-volume-enhanced.png",
    ]
    for relative in sources:
        target = fixture / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / relative, target)
    for directory in [root / "Sources/vRemote/Resources", *(root / "Packaging").glob("*.lproj")]:
        shutil.copytree(directory, fixture / directory.relative_to(root))

    bin_dir = fixture / "fake-bin"
    bin_dir.mkdir()
    for name in ["swift", "ditto", "sips", "iconutil", "xattr", "codesign"]:
        command = bin_dir / name
        command.write_text(fake_tool)
        command.chmod(0o755)
    environment = dict(os.environ, PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
    contents = fixture / "dist/build/vRemote.app/Contents"

    # Both a clean package and a rebuild must exclude abandoned runtime files.
    for attempt in range(2):
        result = subprocess.run([zsh, str(fixture / "package-app.sh")], cwd=fixture,
                                env=environment, text=True, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
        resources = contents / "Resources"
        for name, source in [
            ("LICENSE", "LICENSE"), ("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md"),
            ("PROJECT_OWNERSHIP_AND_LICENSES.md", "docs/PROJECT_OWNERSHIP_AND_LICENSES.md"),
        ]:
            assert (resources / "Licenses" / name).read_bytes() == (root / source).read_bytes(), name
        assert sorted(path.name for path in (resources / "RemoteImages").iterdir()) == ["chromecast-front-and-volume-enhanced.png"]
        assert (resources / "RemoteImages/chromecast-front-and-volume-enhanced.png").read_bytes() == (root / "Resources/RemoteImages/chromecast-front-and-volume-enhanced.png").read_bytes()
        for language in ["en", "zh-Hans", "zh-Hant"]:
            assert (resources / (language + ".lproj") / "Localizable.strings").read_bytes() == (root / "Sources/vRemote/Resources" / (language + ".lproj") / "Localizable.strings").read_bytes()
        assert not list(resources.rglob("*.bundle")), "stale dependency bundle was packaged"
        assert not (resources / "Commerce").exists()
        assert not (resources / "BuyMeACoffee").exists()
        assert (resources / "AppIcon.png").is_file()
        assert (resources / "AppIcon.icns").is_file()
        assert not (resources / "PermissionGuides").exists()
        assert not (resources / "vRemoterLogo.png").exists()
        assert not (resources / "vRemoter.icns").exists()
        assert plistlib.loads((contents / "Info.plist").read_bytes())["CFBundleIdentifier"] == "local.simaqingfeng.vRemote"

        checker = [sys.executable, str(root / "Tools/check-app-bundle.py"), str(contents.parent)]
        invalid = subprocess.run(checker, text=True, capture_output=True)
        assert invalid.returncode != 0 and "not a Mach-O binary" in invalid.stderr, invalid.stdout + invalid.stderr
        # Synthetic headers exercise the content checker only; neither fixture
        # becomes a usable app or a correctly signed executable.
        (contents / "MacOS/vRemote").write_bytes(b"\xcf\xfa\xed\xfe" + b"fixture")
        (resources / "AppIcon.icns").write_bytes(b"icns" + b"\x00\x00\x00\x10" + b"fixture")
        valid_contents = subprocess.run(checker, text=True, capture_output=True)
        assert valid_contents.returncode == 0, valid_contents.stdout + valid_contents.stderr
        notice = resources / "Licenses/LICENSE"
        original_notice = notice.read_bytes()
        notice.write_text("Missing original attribution")
        invalid_notice = subprocess.run(checker, text=True, capture_output=True)
        assert invalid_notice.returncode != 0 and "notice content differs" in invalid_notice.stderr
        notice.write_bytes(original_notice)
        translation = resources / "zh-Hant.lproj/Localizable.strings"
        original_translation = translation.read_bytes()
        translation.unlink()
        invalid_translation = subprocess.run(checker, text=True, capture_output=True)
        assert invalid_translation.returncode != 0 and "translation resource missing" in invalid_translation.stderr
        translation.write_bytes(original_translation)
        inherited_icon = resources / "vRemoterLogo.png"
        inherited_icon.write_text("Obsolete branding")
        invalid_icon = subprocess.run(checker, text=True, capture_output=True)
        assert invalid_icon.returncode != 0 and "inherited branded icon" in invalid_icon.stderr
        inherited_icon.unlink()
        old_guides = resources / "PermissionGuides"
        old_guides.mkdir()
        invalid_guides = subprocess.run(checker, text=True, capture_output=True)
        assert invalid_guides.returncode != 0 and "inherited permission screenshots" in invalid_guides.stderr
        old_guides.rmdir()
        stale_bundle = resources / "TelemetryDeck_SwiftSDK.bundle"
        stale_bundle.mkdir()
        invalid_bundle = subprocess.run(checker, text=True, capture_output=True)
        assert invalid_bundle.returncode != 0 and "obsolete promotion/telemetry resource" in invalid_bundle.stderr
        stale_bundle.rmdir()
        if attempt == 0:
            stale = resources / "Commerce"
            stale.mkdir()
            (stale / "stale-resource.txt").write_text("Must disappear on rebuild")
            (resources / "RemoteImages/x6-remote.png").write_text("Must disappear on rebuild")
            (resources / "vRemoterLogo.png").write_text("Must disappear on rebuild")
            (resources / "vRemoter.icns").write_text("Must disappear on rebuild")
            (resources / "PermissionGuides").mkdir()
            (resources / "PermissionGuides/permission-bluetooth.png").write_text("Must disappear on rebuild")

print("PASS: isolated clean/rebuild packaging copies notices and only current resources")
print("PASS: synthetic content-checker fixtures reject non-Mach-O binaries, changed notices and stale telemetry")
print("NOT RUN: Swift compilation, macOS image tools, signing, or real app/driver validation")
