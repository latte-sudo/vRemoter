# Chromecast audio resource lifecycle

## Ownership contract

The selected virtual-output UID and the microphone-enable preferences are configuration, not permission to leave audio devices running. Device discovery and property listeners may remain installed while idle. A normal voice session owns its output IOProc and, if enabled, the Mac microphone capture path. A test tone temporarily owns output only; it must not acquire the Mac microphone.

`AudioResourceLease` assigns a generation-scoped token to each session or tone. A completion from an older tone cannot release a later session or a newer tone. Late capture-permission callbacks and queued capture startup work recheck current ownership before starting capture. Capture startup also rechecks ownership after the potentially blocking AVFoundation start call.

The output render callback only consumes samples and schedules completion. CoreAudio stop/destroy operations must run outside that callback and outside its shared render-state lock. Route disappearance, explicit stop, and replacement invalidate ownership and discard pending samples so old PCM cannot enter the next session.

## Session lifecycle

1. Validate and start the selected output route before injecting the input-tool shortcut. A failed route start closes the remote source and injects neither a start nor a compensating stop shortcut.
2. Require the first real decoded remote PCM packet within two seconds. An ATVV start notification alone does not satisfy this check. Missing PCM closes the local session. After the first packet, ordinary pauses do not trigger a silence timeout; the existing 120-second safety limit still applies.
3. On a normal end, request remote microphone closure immediately. Keep output leased for the 120 ms audio tail. For a toggle target, complete the final 60 ms key pulse before releasing the route. Delayed main-queue execution extends the pulse from its actual start rather than making its key-up happen prematurely.
4. Disconnect, configuration change, sleep, quit, or explicit forced closure synchronously releases any synthetic held key. No callback from a previous session may release the next session's key or audio ownership.
5. Close the local route and separately assess the target application's capture status. If the route adapter reports failed cleanup, retain the closing state, report the failure, and retry cleanup before a later press may begin a replacement session. Local key/route cleanup is not evidence that another application stopped recording.

## Target stop confirmation

For Doubao, perform a read-only snapshot 1.5 seconds after local closure:

- `inactive`: report that Doubao stopped recording
- `active`: warn that Doubao is still recording and ask the user to stop it in Doubao
- `unavailable`: report that stop is unconfirmed

A custom input tool has no authoritative capture monitor here, so its stop remains explicitly unconfirmed. Beginning a new session cancels the old stop check. Confirmation never injects an extra toggle, kills another process, or changes system microphone permissions.

## Regression coverage and execution

Run `./run-chromecast-voice-tests.sh` on a Swift-enabled machine. Set `VREMOTE_VOICE_TEST_REPETITIONS=20` for repeated execution. The runner compiles the production state machine, controller, configuration, and resource ownership model with platform adapters; no AppKit, CoreAudio, or Bluetooth hardware is required for this suite.

The deterministic scheduler covers route-start and route-stop failure, first-PCM timeout and cancellation, natural speech pauses, old-session isolation, output-tail/final-pulse ordering, delayed key release, stop-confirmation outcomes, and existing gesture/reopen behavior. Resource-model tests exercise generation-scoped ownership and microphone eligibility.

These are logic regressions, not a substitute for a macOS build or device acceptance. The development cloud used for this change did not contain `swiftc`; test execution there exits 127 with a clear blocked message. Passing results must be recorded from a Swift-enabled host.

## Required macOS and hardware acceptance

- Launch while idle: inspect that the app has no running capture session or output IOProc; selecting/refreshing routes must remain idle-safe
- Play a test tone: verify output works, the Mac microphone does not start, and output stops on completion and on its fallback deadline
- Start voice with each remote mode and target shortcut mode: verify real PCM reaches the intended virtual input and the Mac microphone starts only when enabled
- End normally and during a delayed final pulse: verify balanced key events, source stop, tail delivery, output stop/destruction, cleared buffers, and capture stop
- Repeat rapid start/stop, tone-to-session replacement, route removal, disconnect, sleep/wake, quit, and permission response after a session has already closed
- Leave Doubao recording deliberately after local stop: verify the warning and absence of blind corrective toggles; repeat with inactive and unavailable monitoring
- Verify CoreAudio and AVFoundation error paths on the target macOS version, including failures to stop/destroy resources

The macOS orange microphone indicator is system-wide and can remain visible because Doubao or another process is recording, or because the OS UI has not updated yet. This application can manage its own resources and report the monitor's observation; it cannot guarantee that the global indicator disappears or that every other process has released its microphone. Actual device-operation completion and OS indicator behavior require the above macOS checks.
