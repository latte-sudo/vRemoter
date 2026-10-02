# Chromecast feedback correction batch

This batch addresses six reported issues. It remains development work on the existing Chromecast branch; it does not merge, publish an installer, change signing, or alter development authorization/packaging.

## Changes and evidence

1. **Understandable voice settings.** The UI distinguishes the physical remote's voice-key operation from the voice software's recording shortcut mode, with visible examples and setup steps. Adjacent vector information buttons support pointer help, keyboard focus, and click-open explanations. Essential instructions remain visible without hovering.
2. **Mapping overview.** All 14 ordinary Chromecast buttons retain single/double/long action summaries around the existing front/side remote image. A selected action opens one inline editor, with automatic scrolling. Photo locations, selected cards, and observed HID events remain connected; the voice key has its own panel. This is an independent implementation of the requested interaction pattern, not copied reference source.
3. **Repeated toggle sessions.** Code inspection found that BLE previously suppressed a physical release after local/MIC_CLOSE teardown because audio was already idle. That could leave the physical latch set and prevent the next press. Transport lifecycle routing now keeps release edges distinct from stream ownership, suppresses duplicate physical controls, guards local close timeouts by generation, and blocks PCM/keep-alive during close. Raw ATVV control events are exercised through transport lifecycle and the real voice controller in regression fixtures. Bounded diagnostics report ignored controls and lifecycle state. This is not a claim of physical-device reproduction: ATVV STOP packets do not include stream IDs, so arbitrary reordered remote STOP frames cannot be reliably correlated.
4. **Permission results.** Bluetooth uses CoreBluetooth authorization states, including pending and restricted; Accessibility uses AXIsProcessTrusted and Input Monitoring uses CGPreflightListenEventAccess. Explicit status text accompanies icons. Permission checking and reconnection are separate actions, with check results/time and connection state visible. Permission presence does not imply transport connection or working recognition. Development/rebuild permission identity issues remain deferred.
5. **Open voice application.** Doubao's existing verified settings-app identity is used for launch, separately from its input-method identity used for audio observation. An injected launcher resolves selected paths, running apps and LaunchServices, validates the bundle, handles activation/asynchronous errors, and reports the outcome. Custom tools can be chosen using a native application picker. Older configuration decodes with an empty selected path. Unit fixtures cover resolution and failure paths without executing external apps.
6. **Dock icon preference.** “在程序坞中显示图标” persists a boolean, applies regular/accessory activation policy, preserves menu-bar access, and restores the focused window. Missing preferences preserve the prior menu-bar-only default. Dock reopening opens the console; closing the console does not terminate the menu-bar app. A drawn fallback icon prevents a blank icon if the PNG is unavailable. Archive import/export/reset/restore includes the preference and validates its type.

## Validation boundary

The editing environment is Linux without swiftc or Apple frameworks. Shell syntax and `git diff --check` can run here; Swift build and executable tests must run in the macOS workflow for the published commit. Do not substitute a prior commit's green check for this batch's checks.

The macOS workflow builds the app, runs existing ATVV/ADPCM tests, first-round model suites, new launch/Dock/archive tests, and 20 repeated voice regression iterations. Passing those checks still does not establish rendered UI, actual permission transitions, external-app behavior, or physical recording/recognition success.

## Physical/macOS acceptance still required

- At least 20 complete toggle start/stop cycles with the actual Chromecast, including fast release after stop; both target hold/toggle modes; repeat after close, timeout, disconnect/reconnect and sleep
- Hold mode, duplicate control events, missing route, final syllables, no idle IOProc, no VAD, and no synthetic key left held
- Permission granted/denied/pending/restricted views, explicit recheck result, then independent connection/reconnect
- Doubao installed system-wide and per-user, already running, missing installation; custom application selected, moved, deleted, invalid, or refusing activation; visible launch feedback
- All 14 key cards at supported window size, single/double/long editor changes, photo locator, observed highlight, keyboard and VoiceOver information-button access
- Dock hide/show repeatedly with console open/closed, menu-bar reopening, Dock reopening, quit, restart, old configuration, import/export/reset/restore, and missing image fallback

Do not release until the hardware/visual acceptance gaps and distribution/signing checks are addressed.

Native UI v6 uses explicit import/reset confirmation with optional export first; there is no user-visible undo action. See [native interface](NATIVE_INTERFACE_IMPLEMENTATION.md).
