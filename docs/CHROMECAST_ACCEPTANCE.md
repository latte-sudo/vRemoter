# Chromecast release acceptance

This is the current release checklist for the Chromecast-only runtime and
native interface with the approved v7 design reference. It consolidates the first-round, feedback,
appearance and display-name checklists. Unchecked items remain acceptance work;
passing CI or an HTML simulation is not evidence that they were exercised.

Use the exact candidate commit and record macOS version, CPU architecture, remote,
virtual route, speech tool/version and results. Scope is defined in
[PRODUCT](../PRODUCT.md); test commands are in the [README](../README.md#test).

## Build and package evidence

- [ ] macOS app build and protocol/model/gesture/voice/archive suites pass on the
  candidate commit, with 20 deterministic voice-suite repetitions
- [ ] Mapping, native-interface and runtime-cleanup source checks pass; approved
  prototype regression passes and its HTML/reference files remain intact
- [ ] Real app-only development bundle passes notice/resource validation;
  isolated packaging fixture also passes without reintroducing stale SDK assets
- [ ] Bundled `LICENSE`, `THIRD_PARTY_NOTICES.md` and ownership inventory match
  source; real code signature and actual bundle identity are inspected
- [ ] Fresh install and upgrade are tested on supported macOS, including
  Intel/Apple Silicon as applicable. Existing app replacement is deliberate

## Connection, permissions and identity

- [ ] Packaged app requests Bluetooth, Accessibility and Input Monitoring through
  macOS; granted/denied/pending/restricted/unknown states and repeated requests
  display accurately, including externally changed permissions and required relaunch
- [ ] Recheck only reads permission state; reconnect separately retries transport.
  Neither action claims recognition or grants a permission on the user's behalf
- [ ] HID-only, BLE-only, disconnect/reconnect, missing selected route, sleep/wake,
  quit and restart behave safely; all held synthetic keys are released
- [ ] Fresh/upgrade launch, including an old enabled Mac-input preference, leaves
  Mac capture off. No Mac microphone request is introduced by setup
- [ ] Alias updates every presentation surface, saves on Save/Return only,
  validates long/Chinese/emoji/RTL names and rejects control characters safely
- [ ] Rename changes neither Bluetooth identity nor mapping/voice behavior.
  The unchanged physical remote reconnects; multi-device/host binding is not claimed

Detailed API/identity checks: [permissions](PERMISSION_REQUESTS.md).

## Real voice and audio

- [ ] Both remote modes × both target shortcut modes work with fast taps, long
  holds, rapid repeated presses, duplicate controls and interrupted streams
- [ ] At least 20 real toggle start/stop cycles, including fast release after
  stop, then repeat after close timeout, disconnect/reconnect and sleep
- [ ] Menu-bar green dot follows actual received voice data and clears afterward;
  connection/start requests/test tones alone do not count as voice receipt
- [ ] Real remote PCM reaches the selected virtual input; no idle output IOProc,
  Mac capture, VAD cutoff or accidentally held synthetic shortcut remains
- [ ] Missing route, unsupported format, route-start/stop failure, no first PCM,
  silence, clipping and reconnect fail safely; no stale PCM enters a new session
- [ ] Final syllables, latency, 120 ms tail and final target-key pulse are verified
  with the real remote/tool. Test tones do not leak to speakers or acquire Mac capture
- [ ] Doubao inactive/active/unavailable stop observations display correctly;
  deliberately leaving the tool recording produces a warning, not a blind toggle
- [ ] At least one selected custom tool is tested; unconfirmed external stop is
  labelled accurately. Launch handles running/missing/moved/invalid apps and failures
- [ ] Fresh speech trial needs new PCM, a completed session and explicit human
  recognition confirmation; hand-typed text alone never passes. Configuration/
  route/tool changes, edited text and new attempts invalidate evidence correctly

Resource contract and detailed failure paths:
[audio lifecycle](chromecast-audio-resource-lifecycle.md).

## Buttons and native UI

- [ ] All 14 ordinary buttons plus reserved voice card match physical photo
  locations; real HID highlighting, selection and inline editor agree
- [ ] Single/double/long/custom shortcut/application launch/disabled mapping work.
  IR-configured volume/power/input are identified when no Mac report arrives
- [ ] Command+Tab switches once and releases Command/Tab, including when Command
  is the voice shortcut. Directional scrolling works in real apps and stops on release
- [ ] Held-button edits/import/reset/disable, disconnect, sleep/wake and quit cancel
  pending repeats; release and a fresh press are needed after an interruption
- [ ] Untouched directional defaults migrate; any explicit customized/disabled
  action, payload or repeat preference prevents overwriting that button
- [ ] Minimum window size, scrolling, long labels, Light/Dark/System, Reduce Motion,
  Increase Contrast, keyboard focus, information buttons and VoiceOver are checked
- [ ] System appearance follows OS changes; fixed appearance stays fixed. Existing
  and new windows, sheets/popovers and native panels inherit the chosen mode
- [ ] Dock hide/show, close/reopen, menu-bar/Dock reopening, restart and missing-icon
  fallback work without quitting unexpectedly or losing a focused window
- [ ] Onboarding reopen/defer/resume/back/cancel-and-restore, permission/route
  changes, voice navigation, failed sessions and Stop remain usable

Mapping timing and geometry: [mapping behavior](CHROMECAST_SCROLL_ACTIONS.md).
Architecture and persistent settings: [native interface](NATIVE_INTERFACE_IMPLEMENTATION.md).

## Settings migration and data safety

- [ ] Native v1 archive round-trip, invalid version/device/types/actions, oversize
  values, malformed input, Cancel and export-before-replacement are tested atomically
- [ ] Old optional appearance/name/Dock/application-path values restore expected
  defaults; the five known historical X6 key families in v1 Chromecast archives
  are ignored and omitted from new exports; unknown keys and standalone X6
  archives reject
- [ ] X6 is not selectable or restored; Chromecast import/reset leaves unrelated
  old on-disk preferences untouched. Existing Chromecast custom mappings survive
- [ ] Reset, repeated reset and onboarding cancellation restore intended values;
  UI exposes confirmation/backup rather than a misleading undo
- [ ] No pairing UUIDs, permissions, recordings, logs, credentials or login items
  are included in a configuration archive

## Distribution gates

- [ ] Resolve owner-controlled branding/asset rights and app/driver identity choices
- [ ] Verify driver input provenance, corresponding source, notices and distribution
  license route before any driver/PKG release
- [ ] Establish Developer ID signing/notarization and test actual installation,
  upgrade/uninstallation and permission identity on the intended distribution path

These are separate from app logic acceptance. See
[ownership and licenses](PROJECT_OWNERSHIP_AND_LICENSES.md) and
[cleanup inventory](CLEANUP_REVIEW.md). No completed hardware, signing, notarization
or driver distribution approval is implied by this checklist.
