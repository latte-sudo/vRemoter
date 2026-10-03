# Native interface and prototype v8

## Design source and scope

`docs/prototypes/remote-voice-utility-onboarding-settings.html` is the current
neutral visual and interaction reference. It derives from the v8 reference,
extending the user-approved v7 layout with Simplified Chinese, Traditional Chinese,
English and clearer copy, and replaces visible product branding with descriptive
placeholders. `vremoter-onboarding-settings.html` remains a byte-identical historical
archive of the delivered v8 file. Both remain developer references,
including its Design Tokens tab; the customer app has no token browser and runs
no HTML simulation.
The SwiftUI implementation targets macOS 12. Native compilation and AppKit
tests require macOS; platform-independent source/HTML checks do not prove native
rendering, physical remote behavior or recognition.

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
- `RemoteVoiceSupport.swift`: the microphone-open result and audio-state
  provider interfaces shared by the Chromecast controller and Doubao monitor
- `KeyboardTriggerObserver.swift`: physical/synthetic target shortcut observation
  for Chromecast. The obsolete X6 Search suppression gate is removed

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
action remains available, including a release failure. The menu-bar green dot
indicates actual received voice data rather than connection or successful speech
recognition; it returns to the normal icon when reception ends.

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
user explicitly imports or resets. Version 1 Chromecast archives remain
supported. Import discards only the five known historical X6 mapping/enable/repeat/custom/application key families, while
validating current values and retaining archive bounds. New exports omit these
fields. Unknown keys and standalone X6 archives reject. Removed X6 profiles are
not restored or exposed, and preexisting X6 on-disk preferences are not erased
by Chromecast import/reset. See [compatibility detail](CLEANUP_REVIEW.md#archive-and-preference-compatibility).

## Native accessibility and layout

System fonts, text labels for status colors, named photo/key controls, keyboard
operable controls and actual NSOpenPanel/NSSavePanel/NSAlert flows are used.
Reduced Motion disables appearance slider and editor-scroll animation. The
resizable window starts at 1160×820, with a 1080×720 minimum; vertical scrolling
keeps mapping and detailed settings reachable. The real mapping canvas retains
its own horizontal fallback at narrow widths.

The v8 reference retains the v7 sidebar leading alignment, Settings top-spacing
reduction from 65 px to 52 px, and simulated menu-icon voice receipt
demonstration. The native sidebar follows leading alignment, and
the native menu-bar indicator follows real PCM. CSS pixel spacing is a reference,
not evidence of an exact native screenshot match. Native layout and menu-bar
rendering still require macOS visual acceptance.

## Application settings

### Appearance and Dock

System/Light/Dark takes effect immediately and persists across launches. Missing
or invalid values use System. `NSApplication.appearance` is the only override;
System sets it to `nil`, allowing later OS appearance changes to propagate.
Existing AppKit/SwiftUI windows and new sheets, popovers and native panels inherit
it. The app does not change macOS appearance. Semantic tokens adapt to both modes;
photos/logo artwork retain their colors. Reduce Motion disables selector and
editor-scroll animation.

Appearance and Dock visibility are optional v1 archive values. Old archives
without them restore System and the menu-bar-only Dock default. The Dock option
switches regular/accessory activation policy while retaining menu-bar access and
restoring the focused window. Dock reopening opens the console; closing the
console does not quit. A drawn fallback icon avoids a blank Dock icon if the PNG
is unavailable. Confirmed reset returns these settings to their defaults; an
exported backup can restore earlier values.

### Remote display name and identity

The Remote overview provides a draft display-name field with Save/Return and
restore-default actions. Saving trims outer whitespace. Empty input removes the
override and shows `Chromecast Voice Remote`. A name is limited to 64 Swift
Characters and 4096 UTF-8 bytes; internal newlines, control characters and explicit
Unicode direction controls are rejected. Chinese, natural RTL text, combining
marks and emoji are supported. Invalid input leaves the saved value unchanged.

The name updates the header, connection/audio/mapping descriptions, menu status
and tooltip. Long header text truncates with the full name available on hover;
the hardware model remains visible separately. Rename does not stop audio,
reconnect, alter mappings or invalidate speech evidence. The UI's configuration
controls remain unavailable during an active voice session.

`chromecast.remoteDisplayName` is an app-local label, not a device binding. It is
never used as a BLE name hint, saved UUID, HID matcher or recording prefix. The
app does not change the system Bluetooth name. Discovery still expects
`Chromecast Remote`, including name validation on saved-UUID retrieval; changing
the system name can affect reconnection. Multiple-device binding is deferred in
[TODO](../TODO.md).

The optional name participates in v1 export/import/reset and onboarding snapshot
restoration. Import validates type and naming rules before mutation. Missing or
invalid local values use the model name; old archives without a name restore the
default. Backward import compatibility does not imply that older app versions
accept new optional fields exported by this build.

### Opening the speech tool

Doubao launch uses its settings-app identity, separately from the input-method
identity used for capture observation. Custom tools use a native application
picker. The launcher resolves selected paths/running apps/LaunchServices,
validates the bundle, reports missing/moved/invalid apps and activation errors,
and never treats a launch as recognition proof. Old configuration without a
selected application path decodes with an empty path.

## Verification

The [README test commands](../README.md#test) are the current entry points.
Presentation, onboarding migration/evidence, target launch, appearance, display
name, archive and controller/transport/gesture suites exercise logic with
platform adapters. Static UI checks validate integration contracts only.

[Release acceptance](CHROMECAST_ACCEPTANCE.md) consolidates the original
first-round, feedback, appearance and display-name checklists. Use the current
commit's macOS CI result; historical passing runs do not verify subsequent edits.
Source/prototype tests and isolated package fixtures do not replace real native
rendering, permission, external-app or hardware checks.

## Cleanup and app-only packaging

The unused mixer/commerce/donation views, original update/telemetry services,
dependency, promotional assets/site and frozen X6 UI design have been removed.
X6 transport, old coordinator, its CLI self-test, profile/button/schema remnants
and unused suppression logic are removed. Shared permission help and keyboard
capture remain. Voice interfaces were extracted into `RemoteVoiceSupport.swift`;
keyboard observation continues in `KeyboardTriggerObserver.swift`. The retained
and derived code keeps its upstream provenance. See the
[cleanup inventory](CLEANUP_REVIEW.md) and
[ownership/source inventory](PROJECT_OWNERSHIP_AND_LICENSES.md).

Required license texts are copied into `Contents/Resources/Licenses/`;
`package-app.sh` does not package a driver. CI builds the ad-hoc-signed development
app and checks actual notice bytes, active assets and absence of old promotional
or telemetry resources. This does not establish Developer ID signing,
notarization or GPL-driver distribution clearance.

### Upgrade privacy invariant

Launch applies remote-only input to both persisted preferences and the live
`AudioPipe` before starting any HID/BLE/session controller. This matters because
SwiftUI may initialize the shared pipe before `applicationDidFinishLaunching`;
changing UserDefaults alone cannot reset an already cached Mac-input flag. Source
regression checks require the explicit live update before every startup call.
The physical upgrade acceptance above still needs a Mac with an old enabled
Mac-input preference.
