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
repeat conflicts, and reset isolation from the legacy X6 settings.

## Runtime contract

- Unconfigured double/long gestures are disabled. Existing single-key mappings
  retain their original UserDefaults keys and values.
- With no advanced gesture, the single action starts immediately on key-down.
- With only a long action, a short click executes on release without an extra
  double-click wait. Long press executes once at 550 ms and suppresses click.
- A configured double action waits up to 300 ms after the first release for a
  second press. A second press at or after the deadline starts a new sequence.
- When both advanced gestures are assigned, holding the second tap past the
  long threshold produces long press only; no pending single/double leaks.
- Hold repeat starts after 450 ms, then repeats at 70 ms. Double/long mappings
  suspend repeat while retaining the user's repeat preference. Application
  launches never repeat.
- Stop, disable, disconnect, or mapping edits discard pending gestures and
  release the action snapshot captured when a synthetic key was pressed.
- Voice stays on the separate ATVV path and has no ordinary-key gesture action.

The tests do not validate macOS event delivery, Launch Services, actual HID
report cadence, permissions, or Bluetooth interruptions on hardware. Those
require a macOS build and a physical Chromecast Voice Remote before release.
