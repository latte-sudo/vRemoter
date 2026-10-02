# Remote Voice Utility for Chromecast Voice Remote

A macOS 12+ utility that sends Chromecast remote audio to a selected virtual
microphone route, controls a speech tool's recording shortcut, and maps ordinary
remote buttons to Mac actions. The app does not recognize speech; the selected
speech tool does. Mac microphone capture is disabled, including on upgrade.

The current descriptive display names are **Remote Voice Utility / 遥控器语音工具 / 遙控器語音工具**. They are placeholders, not a final product name or a new author identity. The inherited `vRemote` executable, app directory and technical identities remain for compatibility; see the [identity and contribution inventory](docs/PROJECT_OWNERSHIP_AND_LICENSES.md).

This is a **development branch**, not a signed/notarized release. It supports the
known Chromecast Voice Remote profile (VID `0x18D1`, PID `0x9450`). X6 transport,
profiles, old session controller and its CLI self-test have been removed. Shared
keyboard observation and voice protocols remain under device-neutral names.

## What you need

- A Mac running macOS 12 or newer and a Chromecast Voice Remote
- Swift 5.9+ and the macOS SDK to build; Python 3 and Node.js 18+ for developer checks
- A working virtual audio route that the selected speech tool can read
- Doubao or a custom speech tool with a configured recording shortcut
- Bluetooth, Accessibility and Input Monitoring access granted by the user

The existing `vRemoteDr 2ch` driver route is experimental. App-only packaging
does not install it or any other driver. The BlackHole-derived driver has separate
source, license and distribution requirements; see [driver background](Driver/README.md)
and [release blockers](#release-blockers). No system-default microphone is changed.

## Build and run on macOS

From the repository root:

```sh
swift build
swift run
```

Use the menu-bar icon to open the console or quit. The Dock icon is optional.
For realistic macOS permission testing, use a consistently located app bundle:

```sh
zsh package-app.sh
python3 Tools/check-app-bundle.py dist/build/vRemote.app
```

This creates `dist/build/vRemote.app`, including active artwork, permission
help and license notices, and applies an **ad-hoc development signature**.
It does not perform Developer ID signing or notarization.

Optional local installation, only when you intend to replace your existing
`~/Applications/vRemote.app`:

```sh
zsh install-app.sh
open "$HOME/Applications/vRemote.app"
```

`install-app.sh` replaces that app directory; it does not install the audio driver
or grant permissions. A terminal-launched SwiftPM build having access is not proof
that the packaged app has access. See [permission testing](docs/PERMISSION_REQUESTS.md).
The DMG and PKG scripts are development machinery: the PKG path additionally
builds/includes a modified driver and is not cleared for distribution.

## First use

1. Choose the speech tool in the seven-step setup. Select its application and
   configure its recording shortcut; a custom tool requires a real compatibility test
2. Pair the remote in macOS Bluetooth settings and check that both HID buttons
   and BLE voice are connected. They are separate channels
3. Request the needed permissions, approve them in macOS, then recheck and
   reconnect. The app does not request Mac microphone capture for this runtime;
   the speech tool controls its own microphone permission
4. Choose the remote's hold/toggle mode and the speech tool's shortcut mode
   independently. Select the virtual route that feeds the tool
5. Run the real speech trial with the physical black voice key. Success requires
   new remote PCM, a completed session and your confirmation of recognized text.
   A test tone or hand-typed text alone cannot complete the trial
6. Configure the real photo-based button map, then finish setup. Single, double
   and long press can send shortcuts, open/switch applications or scroll;
   the voice key stays reserved

Settings has four pages: Voice & Audio, Remote, Permissions & Diagnostics, and
Settings. Active voice state, elapsed time, input meter and Stop remain available
across pages. A green menu-bar dot indicates actual received voice data; it is
not a connection or recognition-success indicator. Configuration changes are
disabled during a voice session.

System/Simplified Chinese/Traditional Chinese/English language selection applies
immediately and is app-local. It is available in Settings, the setup sidebar and
the menu bar. Unsupported system languages fall back to English. See
[localization and copy coverage](docs/LOCALIZATION.md).

Light/Dark/System appearance, Dock visibility, launch at login, an app-local
remote display name, and bounded configuration import/export/reset are supported.
Import/reset asks for confirmation and offers export first. Archives exclude
pairing, credentials, recordings, logs, permissions and login items. Old v1
Chromecast archives may contain historical X6 mapping fields; import ignores
those known fields and rejects unknown keys or standalone X6 archives.
Obsolete on-disk preferences are left untouched.

## Debug a connection or recording problem

- Check HID and BLE separately in Permissions & Diagnostics. A permission grant
  does not establish connection, usable audio or recognition
- Check the selected virtual route and the tool's input/shortcut configuration.
  A missing route fails closed; an optional test tone tests routing, not recognition
- Test real buttons and actual speech. Volume, power or input configured for IR
  may never produce a Mac HID report. A local display-name change does not rename
  Bluetooth or bind a specific physical remote to this Mac
- Enable Logs from the menu bar when needed. The log is
  `~/Library/Logs/vRemote/vRemote.log`; file logging is off by default
- Optional Debug recordings saves local WAV/raw data under
  `~/Library/Application Support/vRemote/Recordings`. It is off by default;
  recordings can contain private speech, so inspect them before sharing
- For low-level button diagnosis on a Mac, `Tools/hid-report-probe.swift` accepts
  vendor/product hex arguments (`18d1 9450`). It is a developer aid, not an audio test

BLE reconnection still expects the name hint `Chromecast Remote`; changing the
system Bluetooth name can affect discovery. Multiple remotes/computers and
explicit device binding are deferred in [TODO.md](TODO.md).

## Test

On macOS with the tools above:

```sh
swift build
zsh run-self-tests.sh
VREMOTE_VOICE_TEST_REPETITIONS=20 bash Tools/test-chromecast-models.sh
python3 Tools/check-mapping-layout.py
python3 Tools/check-native-interface.py
python3 Tools/check-runtime-cleanup.py
python3 Tools/check-branding.py
python3 Tools/generate-placeholder-icon.py --check
python3 Tools/test-package-contents.py
node docs/prototypes/test-vremoter-onboarding-settings.cjs
node docs/prototypes/test-vremoter-onboarding-settings.cjs docs/prototypes/vremoter-onboarding-settings.html
git diff --check
```

The [macOS workflow](.github/workflows/chromecast-validation.yml) builds the app,
runs protocol/model/source-contract regressions, mapping geometry, the offline
prototype regression (Node.js 20) and packaging checks, builds the actual
development app and checks bundled resources/notices. Check the result for
the exact commit; an earlier passing run is not verification of new changes.

Python source checks and the offline HTML test can run on Linux. Foundation-only
Swift suites need `swiftc`; macOS-specific suites need Apple frameworks. The
isolated packaging fixture uses stand-in build/signing tools and does not prove a
real app works. CI cannot establish native rendering, permission transitions,
physical remote behavior or recognition quality. Use the
[release acceptance checklist](docs/CHROMECAST_ACCEPTANCE.md).

## Source and documentation

- [Product scope](PRODUCT.md) and [native architecture/settings](docs/NATIVE_INTERFACE_IMPLEMENTATION.md)
- [Mapping layout and actions](docs/CHROMECAST_SCROLL_ACTIONS.md)
- [Audio lifecycle](docs/chromecast-audio-resource-lifecycle.md) and [permissions](docs/PERMISSION_REQUESTS.md)
- [Current neutral HTML reference, historical v8 archive and test](docs/prototypes/README.md), kept offline;
  it simulates interactions and does not run the native app or real audio
- [Cleanup inventory](docs/CLEANUP_REVIEW.md) and [ownership/source inventory](docs/PROJECT_OWNERSHIP_AND_LICENSES.md)
- `Sources/vRemote/`: SwiftUI, HID/BLE/ATVV, voice/audio, mapping and system integration
- `SelfTests/`, `Tools/`: regression suites and developer checks
- `Resources/`: active remote artwork, generic placeholder icon and permission-help notes;
  all three interface languages use native schematic permission illustrations
- `Tools/generate-placeholder-icon.py`: reproducible letter-free geometric remote icon;
  inherited logo sources and permission screenshots have been removed
- [Historical changelog](CHANGELOG.md): inherited history, not a new release claim

## Release blockers

The repository retains the upstream [MIT license](LICENSE), source author headers
and [third-party notices](THIRD_PARTY_NOTICES.md). Renaming or extracting shared
code does not remove its provenance. Original commerce, donation, telemetry,
update-service and promotional-site code have been removed; no replacement
online service is configured.

The modified BlackHole driver has separate GPLv3 obligations. Its binary-patching
script does not establish a complete reproducible source release. Driver
source/build provenance, the distribution license route, asset rights, signing,
notarization and installation/hardware acceptance remain open. Visible branding
now uses descriptive placeholders and a generic icon. Bundle/signing/login-item,
package/executable/app-folder, preferences/storage/archive and driver identities
remain unchanged until a coordinated migration is designed.
See the [ownership and release decisions](docs/PROJECT_OWNERSHIP_AND_LICENSES.md).
