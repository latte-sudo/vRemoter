# vRemoter · Chromecast development branch

macOS 12+ utility for a Chromecast Voice Remote: send real remote audio to a
selected virtual input route, control the chosen speech tool's recording
shortcut, and map ordinary remote buttons to Mac actions. The active runtime is
Chromecast-only; Mac microphone capture is disabled, including on upgrade.

This branch is development work, not a signed/notarized release. The approved
HTML v6 design is implemented in native SwiftUI; the HTML is a developer
reference, not an embedded app or a real-audio demonstration.

## Current experience

- Seven-step setup: choose speech tool, connect both remote channels, permissions,
  independent speaking modes, real speech trial, actual key mapping, completion
- Four settings pages: Voice & Audio, Remote, Permissions & Diagnostics, Settings
- Persistent real voice state across pages, actual input meter, timer and stop
- Existing photo-based mapping with click/double-click/long-press, custom shortcut,
  application switching and release-bound directional scrolling
- Light/Dark/System, launch at login, Dock visibility, bounded native configuration
  import/export and confirmed reset
- App-local remote display name; no system Bluetooth rename or multi-device binding

The app does not recognize speech. The selected tool does. Trial completion
requires new remote PCM, a completed local session and the user's confirmation
of real recognition text. Test tones and hand-typed text do not prove recognition.

## Build and verify

Use a Mac with Swift 5.9+ and the macOS SDK:

```sh
swift build
zsh run-self-tests.sh
bash Tools/test-chromecast-models.sh
python3 Tools/check-native-interface.py
node docs/prototypes/test-vremoter-onboarding-settings.cjs
```

`macos-14` CI runs the app build and regression tests (including 20 deterministic
voice-suite repetitions). Source-contract and HTML tests can run on Linux; they
are not native rendering, physical remote or external speech-tool acceptance.

For an app-only development bundle, `zsh package-app.sh` performs a release build,
adds resources and license notices and applies ad-hoc signing. It is not Developer
ID signing or notarization. Do not distribute a driver/PKG as a finished product:
see the licensing blockers below. This task has not installed drivers or granted
system permissions.

## Repository guide

- `Sources/vRemote/`: native UI, HID/BLE/ATVV, voice/session/audio and mapping
- `SelfTests/` and `Tools/`: deterministic regression tests and developer checks
- `Resources/`: active remote artwork and permission guides
- `docs/prototypes/`: approved HTML and its offline regression runner
- `docs/NATIVE_INTERFACE_IMPLEMENTATION.md`: native architecture and acceptance
- `docs/PROJECT_OWNERSHIP_AND_LICENSES.md`: ownership, notices, identity fields and
  release choices that require the project owner's decision
- `docs/CLEANUP_REVIEW.md`: removal inventory, retained shared code and resources
- `Driver/`, `Packaging/`: existing experimental build/install machinery; not a
  newly authorized installer or production distribution pipeline
- `Design/`: retained design history and currently used app icon pending branding

## Scope and release blockers

Only the known Chromecast profile (VID `0x18D1`, PID `0x9450`) is in the active
runtime. Volume/power/input buttons may use IR and then never reach the Mac. The
custom speech target, Fn behavior, latency and final-syllable retention need real
hardware/tool testing. Multi-remote and remote-to-computer identity binding are
explicitly deferred in [TODO.md](TODO.md).

Original commerce, donation, telemetry, update-service and static promotional
site code have been removed in this cleanup; no replacement online service is
implied. App name, icon, bundle identity, signing identity, login-item identity and
driver identity are intentionally not silently changed.

The main repository carries the retained MIT license. The modified BlackHole
virtual driver has separate GPLv3 obligations; the existing binary-patching build
is not evidence of a compliant public source release. Driver source/build
provenance, licensing route, asset rights, signing, notarization and installation
acceptance remain release blockers. See [license inventory](docs/PROJECT_OWNERSHIP_AND_LICENSES.md)
and [driver background](Driver/README.md). Attribution is retained even when
promotional interfaces are removed.

Further references: [scope](docs/CHROMECAST_FIRST_ROUND.md),
[mapping actions](docs/CHROMECAST_SCROLL_ACTIONS.md),
[audio lifecycle](docs/chromecast-audio-resource-lifecycle.md),
[permissions](docs/PERMISSION_REQUESTS.md),
[reuse ledger](docs/REUSE_AND_REPLACEMENT_LEDGER.md),
[historical changelog](CHANGELOG.md).
