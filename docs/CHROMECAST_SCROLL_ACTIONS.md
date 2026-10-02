# Application switching and directional scrolling

## Mapping behavior

The ordinary-button action dropdown includes **切换应用 (⌘Tab) / Switch applications**
and **Scroll up/down/left/right**. These can be assigned to any remappable button;
the voice button remains reserved for the existing ATVV voice session.

- Switch applications runs one complete Command+Tab per recognized gesture. It
  never auto-repeats, including when the ordinary-click repeat preference is on.
  The complete four-event sequence is allocated before posting and synchronously
  releases both Tab and Command. Every event carries the synthetic-input marker.
- A long-press scroll starts after 550 ms and emits a 20-pixel step every 70 ms
  while held. Release immediately cancels the next step; it does not perform an
  overdue final repeat. If the threshold timer was never delivered before
  release, scrolling does not start afterward. There is no latched/toggle mode.
- All four directions work on any ordinary button, not only the matching D-pad
  key. Horizontal events use wheel/axis 2; vertical events use wheel/axis 1.
- A scroll assigned to click starts on down and repeats after 450 ms when no
  additional gesture is configured. Configured double/long gestures defer click;
  a recognized single/double scroll then emits one step. Use the long-press slot
  for continuous scroll alongside other gestures.
- The single-action repeat checkbox controls ordinary keyboard/media repetition.
  Continuous scroll owns its repetition independently. Existing long keyboard
  shortcuts and application launches remain one-shot.

## Existing settings and defaults

Each untouched D-pad button receives a matching long-press scroll default.
Its short press still sends the original arrow, now on release so long press can
be distinguished. Any stored click/double/long action, shortcut/application
payload, or repeat preference on that button prevents this migration, including
an explicitly disabled action. No existing custom mapping is replaced. Users
with customized buttons can select a scroll action manually in the desired slot.

The new default is saved explicitly, so later edits do not silently remove it.
“Restore Chromecast defaults” restores these new directional defaults. Settings
export/import/undo preserve the five new target identifiers using the existing
version-1 archive schema; invalid/unknown actions still fail validation.

## Lifecycle safety

The main-thread mapping controller owns all gesture deadlines. It snapshots
mappings on press, releases that same action on cancellation, and invalidates
scheduled callbacks by generation. Release, mapping changes, reset/import/undo,
disabling remapping, disconnect, stop/termination and system sleep all discard
pending repeats. Editing or sleeping while held requires release and a fresh
press before a new action can start. Disconnect/restart begins a fresh session.
No per-action background timer or held modifier is used for scrolling.

## Verification and remaining acceptance

`bash Tools/run-gesture-tests.sh` includes pure recognizer, macOS storage,
controller/scheduler and non-posting CGEvent regression tests. The existing
macOS CI aggregate runs this script, archive tests and `swift build`.

This editing environment is Linux without `swiftc` or Apple frameworks. Shell
syntax and whitespace checks can run here; compilation and executable test
results must be taken from CI for the exact published commit, not a prior run.

Before release, verify on macOS 12+ with a physical Chromecast remote:

- Short/long/repeated holds, all directions, all ordinary button slots, and fast
  release in a vertically/horizontally scrollable application
- Scroll direction and speed in real apps; apps decide how to consume CGEvents
- Switch between applications once per gesture; the switcher closes and no
  Command state persists, including when Command is the voice shortcut
- Disconnect/reconnect, mapping edits/import/reset, disable, sleep/wake and quit
  during scrolling; no repeats after interruption or premature action on resume
- Accessibility/Input Monitoring denial, actual HID release reports and any
  IR-configured buttons that do not send Mac reports

CI does not validate hardware cadence, Bluetooth loss, rendered UI, real event
routing or system permission behavior. No installer/release/signing changes are
part of this work.
