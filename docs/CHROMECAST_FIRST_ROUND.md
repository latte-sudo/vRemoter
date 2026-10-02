# Chromecast first round

## Scope

macOS, Chromecast Voice Remote only. The existing ATVV codec and transport remain; X6 types are retained for source compatibility but are not started or exposed by the new console. Mac microphone capture is off, including on upgrade. No Windows, phone, macros, per-application profiles, transcript history or private SayAll modules.

## Functional surfaces

1. **First-run setup**: welcome → connect HID/BLE → permission status → virtual audio device → “你准备在哪个工具里说话？” → actual speech test → ordinary keys → finish. Progress resumes; original configuration is backed up across restarts; Cancel restores it. Back and retest are available. Changing the tool/route invalidates the attempt. Audio receipt and ended session are machine-observed, while recognition content is explicitly user-confirmed, not automatically authenticated.
2. **Connection and voice**: selected virtual output by persistent UID, safe gain, input meter, route diagnostics and one-second test tone; Doubao or custom input tool; independent remote hold/toggle and target shortcut hold/toggle settings. A test tone is not a transcription test. No system-default microphone changes. Missing selected device fails closed.
3. **Button configuration**: clickable front/side Chromecast image, observed HID highlight, single/double/long gestures, shortcut recording, application launch, disabled actions, auto-save and reset. Voice key is reserved for the session controller. Additional gestures suspend repeat; without extra gestures, ordinary key down/up is immediate. IR-configured volume/power/input buttons may not reach the Mac.
4. **Settings/diagnostics**: login item, permissions, version, repeat setup, bounded version-1 configuration import/export, reset with undo and connection/audio counters. Archives omit pairing, credentials, logs, recordings and permissions.

## Verification

Cloud Linux has no Swift compiler or Apple frameworks. `git diff --check` and script/source checks can run here; Swift application build, deterministic tests and existing codec fixtures run in the macOS GitHub workflow. No build/test pass is claimed until that exact commit's workflow succeeds.

Run on macOS:

```sh
swift build
zsh run-self-tests.sh
bash Tools/test-chromecast-models.sh
```

## Required physical acceptance before release

- Fresh install and upgrade with existing Mac-input-on preference: Mac capture stays off
- Bluetooth grant/deny; HID-only/BLE-only/disconnect/reconnect; sleep and quit release all keys
- Both remote modes × both target shortcut modes; fast taps, long holds, repeat press, interrupted stream; no stale reopen
- Route missing/reconnect, unsupported format, gain clipping, silence and actual voice; no speaker test-tone leakage
- Real Doubao recognition and at least one selected custom tool; latency and final syllable retention
- Onboarding Close/reopen, Back, Cancel/restore, retry after tool/route changes; typed text never silently counted as verified speech
- Clickable positions against physical Chromecast; side volume buttons under Bluetooth vs IR configuration
- Shortcut/app launch/single/double/long/repeat, disabled mapping and permission rejection
- Import wrong version/device/types, reset/undo, lost application; no partial import
- Visual/VoiceOver/keyboard navigation on supported macOS and Intel/Apple Silicon

Hardware, actual microphone/recognition, render QA, signing/notarization and installer distribution are not validated by CI. This is a draft development change, not a release-ready binary.
