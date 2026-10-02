# Native interface: approved prototype v6

## Design source and scope

`docs/prototypes/vremoter-onboarding-settings.html` is the approved visual and
interaction reference. It remains a developer reference, including its Design
Tokens tab; the customer app has no token browser and runs no HTML simulation.
The SwiftUI implementation targets macOS 12. The current cloud executor is Linux
without `swiftc`, so native compilation and tests must run in macOS CI. A build
pass is not physical remote/IME or visual acceptance.

## Architecture

- `ChromecastConsoleView.swift`: seven onboarding steps, four settings pages,
  native permission/application/archive actions, and real speech trial
- `ConsoleDesignTokens.swift`: paired light/dark semantic colors, shared cards,
  notices, primary actions, 219 pt sidebar and animated appearance selector
- `OnboardingProgress.swift`: versioned seven-step migration and conservative
  resume. Trial evidence is intentionally not persisted; later stages resume at
  the speech trial after relaunch
- `VoiceSessionPresentation.swift`: typed, controller-owned lifecycle snapshot;
  no localized status string parsing. Recording requires actual PCM and any
  target-state confirmation the controller requires. Header elapsed time comes
  from the controller's timestamp, not the page lifetime
- `ChromecastMappingCanvas.swift`: the existing photo, physical hotspots,
  connector geometry and gesture editor are used unchanged in both onboarding
  step 6 and the Remote page. They are not the prototype placeholder
- `ChromecastVoiceSessionController.swift`, BLE/HID, mapping and audio paths
  continue to own transport/shortcut/resource safety. The UI doesn't synthesize
  recording or recognized text

## Information architecture

Onboarding: choose tool → connect remote → permissions → speaking modes → real
speech trial → key mapping → ready. Connect and permission gates use observed
states. The connection page can request Bluetooth or visit permission checks early if
initial permission blocks HID connection; the permission step requires both
channels to reconnect before advancing. Back navigation is available for visited steps. Later means resume,
not successful completion. Cancelling and restoring the pre-flow snapshot is a
separate confirmed action in Settings.

Settings: Voice & Audio; Remote (name/connection overview directly above the real
mapping canvas); Permissions & Diagnostics; Settings (appearance, login, Dock,
validated backups, reset and restart). Page navigation leaves active voice state
visible. Configuration mutations are disabled during a session; the header stop
action remains available, including a release failure.

## Speech evidence and safety

The user prepares a fresh trial, focuses the native TextEditor and operates the
physical black voice key. The app inserts no example recognition text. A fresh
attempt has packet/end baselines; success requires both new PCM and a completed
session, valid connection/route/tool/permissions, ended lifecycle, nonempty text,
and the user's explicit confirmation of its source. Hand typing alone cannot
pass. Another session, text edits, route/gain/tool changes, disconnects, failures
or a new trial invalidate confirmation as appropriate. Diagnostics are collapsed
under “没有输入成功？”, with route selection available there; no test tone is
required. Target recognition remains a human confirmation, not a claim of
programmatic IME validation.

Import validates the bounded native v1 property list before asking to replace
settings. Import/reset/cancel/mapping-reset confirmations default to Cancel and
offer export first; exporting does not authorize replacement. There is no
user-visible undo. Permissions, pairing, recordings, logs and login items are
excluded from archives. Existing custom mappings/settings are retained unless a
user explicitly imports or resets.

## Native accessibility and layout

System fonts, text labels for status colors, named photo/key controls, keyboard
operable controls and actual NSOpenPanel/NSSavePanel/NSAlert flows are used.
Reduced Motion disables appearance slider and editor-scroll animation. The
resizable window starts at 1160×820, with a 1080×720 minimum; vertical scrolling
keeps mapping and detailed settings reachable. The real mapping canvas retains
its own horizontal fallback at narrow widths.

## Verification and next developer checklist

Run `swift build`, `bash Tools/test-chromecast-models.sh`,
`zsh run-self-tests.sh`, `python3 Tools/check-native-interface.py` and
`node docs/prototypes/test-vremoter-onboarding-settings.cjs`.
The Swift runner includes pure presentation, onboarding migration/evidence and
controller/transport/gesture regressions. Static UI checks validate integration
contracts only, not SwiftUI rendering or native interaction.

On a Mac, verify minimum-size layout, Light/Dark/System, Reduce Motion, keyboard
focus and VoiceOver; then every interrupted/repeated flow: reopen midway through
onboarding, defer/resume, back from completion, external permission/route change,
start/stop while navigating, failed session, import Cancel/export Cancel, malformed
archive and repeated reset. Use a physical Chromecast and the chosen speech tool
to verify PCM, end behavior, the observed button highlight, continuous scrolling
and recognition confirmation. No driver installation or system grants are
performed by these UI changes.

Release identity, provenance and cleanup decisions are tracked in
`PROJECT_OWNERSHIP_AND_LICENSES.md` and `CLEANUP_REVIEW.md`; those are separate from
native UI acceptance. Do not rename bundle/signing identities or publish a driver
without reviewing them.

## Cleanup and app-only packaging

The follow-on cleanup removes the unused mixer/commerce/donation views and
original update/telemetry services, dependency, assets and promotional site.
Shared permission help and keyboard capture remain; X6-named shared protocols,
keyboard observation and preference-isolation tests are deliberately retained.
Required copyright and license texts are copied into the app's
`Contents/Resources/Licenses/`; no driver is packaged by `package-app.sh`.
CI builds the ad-hoc-signed development app and checks its actual notice bytes,
active assets and absence of old promotion/telemetry resources. This is not
signing/notarization or GPL-driver distribution clearance.
