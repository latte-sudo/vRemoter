# Ordinary-button mapping tests

Run with a Swift 5.9+ compiler:

```sh
bash Tools/run-gesture-tests.sh
```

The pure Foundation recognizer tests run on Linux and macOS without Bluetooth,
Accessibility permission, a remote, or the app's third-party dependencies. They
cover default immediate key-down/up; configured double-click delay and its
boundary; short and long presses; combined gestures; duplicate reports; repeat
suppression; delayed-timer burst protection; cancellation; and Codable metadata.

On macOS the same runner also builds the production mapping store with minimal
localization/event-marker stubs. It tests legacy custom-shortcut migration,
per-gesture save/reload, application metadata, voice-key write protection,
repeat conflicts, and reset isolation from the legacy X6 settings. It also
builds the production mapping controller with an injected clock, cancellable
scheduler and action sink. Those tests cover repeated scroll cycles, late and
canceled callbacks, edits during holds, disconnect/stop/restart, disable, sleep
cancellation, default migration, and balanced Command+Tab event construction.
No test posts real keyboard or scroll events.

## Runtime contract

- Untouched D-pad buttons receive a long-press scroll action in the matching
  direction. Any existing action, payload, or repeat preference on that button
  prevents migration. Other unconfigured double/long gestures stay disabled.
  Existing single-key mappings retain their original keys and values.
- With no advanced gesture, the single action starts immediately on key-down.
- With only a long action, a short click executes on release without an extra
  double-click wait. Ordinary long actions execute once at 550 ms and suppress
  click. Scroll long actions start at 550 ms, then repeat every 70 ms until release.
- A configured double action waits up to 300 ms after the first release for a
  second press. A second press at or after the deadline starts a new sequence.
- When both advanced gestures are assigned, holding the second tap past the
  long threshold produces long press only; no pending single/double leaks.
- Hold repeat starts after 450 ms, then repeats at 70 ms. Double/long mappings
  suspend repeat while retaining the user's repeat preference. Application
  launches and Switch applications never repeat. Continuous scroll actions
  own their repeat behavior independently of the ordinary-click repeat toggle.
  A deferred click/double-scroll action emits only one scroll step on release.
- Release never emits an overdue repeat. A continuous long action whose timer
  has not fired by release does not start retroactively.
- Stop, disable, disconnect, sleep, mapping edits and archive import/undo discard
  pending gestures and release the press-time action snapshot. A canceled
  callback cannot restart a repeat or affect a new session.
- Switch applications emits a complete marked Command-down, Tab-down, Tab-up,
  Command-up sequence once per gesture, ending with cleared Command flags.
- Scroll events use pixel deltas: +20 up / -20 down on axis 1, +20 left / -20
  right on axis 2. No synthetic keyboard modifier is held while scrolling.
- Voice stays on the separate ATVV path and has no ordinary-key gesture action.

The tests do not validate macOS event delivery, Launch Services, actual HID
report cadence, permissions, or Bluetooth interruptions on hardware. Those
require a macOS build and a physical Chromecast Voice Remote before release.
