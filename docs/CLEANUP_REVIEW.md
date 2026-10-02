# Chromecast cleanup inventory

Reviewed 2026-10-02. The approved HTML reference was archived at `ac3890f`;
inherited source provenance starts at upstream
`15076345d955fcc81dae659150d1702b50b8010a`. This document records the current cleanup
scope. It is not proof of native/hardware or distribution acceptance. Legal and
identity decisions remain in [ownership and licenses](PROJECT_OWNERSHIP_AND_LICENSES.md).

## Removed runtime and promotional scope

- Commerce, donation, automatic update and telemetry implementations, their
  menu/modal/demo hooks, TelemetryDeck dependency/lockfile and four old service
  configuration keys in the packaged plist
- Old mixer/mapping root views and their private product/meter controls; active
  window/model, permission help, shortcut capture and shared styles remain
- Old commerce/donation resources, two superseded remote product photos and
  three commerce/update test fixtures
- Original promotional HTML/JavaScript/CSS/config/assets, release server files
  and upstream operational instructions; no replacement service is configured
- Unreferenced `Tools/generate-qr.swift`, formerly a manual promotional QR helper;
  the useful Chromecast HID-report probe remains
- `X6HIDBridge.swift`, the old `X6SessionCoordinator.swift` class,
  `VoiceSessionSelfTest.swift` and the `--voice-session-self-test` entry point;
  X6 HID/BLE construction, model/menu branches and old voice bookkeeping
- Retired Mac-microphone usage descriptions in the app plist/localizations;
  Input Monitoring wording now describes Chromecast buttons and keyboard observation
- X6 profile/button declarations and legacy mapping schema/metadata used by the
  removed UI; no selectable X6 profile remains
- `X6SearchSuppressor.swift` and its unused X6 Search gate, replaced with the
  shared keyboard observer described below

## Shared behavior preserved after X6 removal

| Active source | Retained responsibility |
| --- | --- |
| `RemoteVoiceSupport.swift` | Microphone-open result and audio-state provider interfaces extracted from the former X6 coordinator; provenance retained |
| `KeyboardTriggerObserver.swift` | Listen-only physical/synthetic target-shortcut observation used by Chromecast; explicit event-tap/run-loop teardown |
| `KeyboardTriggerState.swift` | Platform-independent press/release edge tracking, with deterministic regression coverage |
| `BLEBridge.swift`, `ATVV/*` | Active Chromecast BLE/ATVV audio, physical voice edges, close generation, keep-alive and session lifecycle |
| `ChromecastRemoteHIDBridge.swift`, `RemoteMappingSupport.swift` | Chromecast VID/PID, ordinary HID suppression/remapping, custom mappings and gesture lifecycle |
| `ChromecastVoiceSessionController.swift` | Real PCM/session state, target shortcut, output lease, balanced release and stop observation |
| `DebugWindowController.swift` | Active window/model, permission guide and shortcut-capture controls with shared styles; neutral placeholder icon and native localized help |

Renaming or extracting code does not make it newly original. The root MIT license,
ATVV author headers and third-party/source notices remain, including provenance
for the two files derived from X6-named shared implementations.

### Archive and preference compatibility

Current exports contain only Chromecast settings. Version-1 archives with
`device=chromecast` may still contain the five historical X6 mapping families:
`remoteMapping.x6.*`, `remoteCustomMapping.x6.*`,
`remoteApplicationMapping.x6.*`, `remoteMappingHoldRepeat.x6.*`, and the exact
`remoteMappingEnabled.x6` key. Import discards these fields before interpreting
payloads, while keeping whole-archive size/count limits and validating all
current settings. Standalone `device=x6` archives and unknown keys still reject.
This is bounded import compatibility, not an active X6 schema or profile.

Chromecast restore/reset only replaces current settings. It does not read,
rewrite or delete retired preferences already on disk. Current custom mappings
and explicit disabled/repeat choices retain their existing migration safeguards.
No cleanup script touches a user's installed apps, preference store, saved BLE
UUIDs, logs, recordings or drivers. The old `x6-uuid.txt` ignore rule remains
to avoid accidentally adding a private pairing identifier to Git.

## Removed design and consolidated documents

The obsolete X6/mixer design was not a build or runtime input. Removed:

- `Design/UIv1_bak.fig`
- `Design/vRemoter-UI-v1-Frozen/README.md`
- `Design/vRemoter-UI-v1-Frozen/UI-FREEZE.md`
- `Design/vRemoter-UI-v1-Frozen/code.js`
- `Design/vRemoter-UI-v1-Frozen/manifest.json`
- `Design/vRemoter-UI-v1-Frozen/打开Figma插件.command`

Historical/duplicate documents were consolidated rather than losing their
current requirements:

| Removed document | Current home for relevant content |
| --- | --- |
| `CHROMECAST_FIRST_ROUND.md` | [Product scope](../PRODUCT.md), [native architecture](NATIVE_INTERFACE_IMPLEMENTATION.md), [release acceptance](CHROMECAST_ACCEPTANCE.md) |
| `CHROMECAST_FEEDBACK_FIXES.md` | Native architecture, audio/mapping contracts and release acceptance |
| `CHROMECAST_MAPPING_LAYOUT.md` | [Mapping layout and actions](CHROMECAST_SCROLL_ACTIONS.md) and reference provenance in ownership inventory |
| `APPEARANCE_SETTINGS.md` | Native settings architecture and release acceptance |
| `REMOTE_DISPLAY_NAME.md` | Native display-name/identity contract and release acceptance |
| `REUSE_AND_REPLACEMENT_LEDGER.md` | [Ownership/source inventory](PROJECT_OWNERSHIP_AND_LICENSES.md#reference-and-replacement-ledger) |

The historical `docs/prototypes/vremoter-onboarding-settings.html` remains
byte-identical. `remote-voice-utility-onboarding-settings.html` is a separate
current reference with neutral visible branding; the existing test-runner filename
is retained and defaults to that current copy. Historical `CHANGELOG.md` is untouched.

The 21 files in `Design/vRemoter-Logo-v1/` and eight inherited permission-guide
screenshots are removed. `Resources/AppIcon/placeholder-app-icon.png` is generated
by `Tools/generate-placeholder-icon.py`: a generic geometric remote without
letters or copied brand artwork. Permission help uses existing native localized
schematics in all three languages. Display names are descriptive placeholders:
Remote Voice Utility / 遥控器语音工具 / 遙控器語音工具.

The package/executable/app-folder, bundle/signing/login-item, preferences/storage/
archive, driver identities and version remain unchanged. They require a coordinated
compatibility migration, not a global text replacement. The root MIT license,
source headers, third-party notices and provenance links remain unchanged in substance.

## Packaging and retained review items

`package-app.sh` copies the active remote artwork, generic placeholder icon and
three-language app resources. Permission illustrations are drawn in native code;
no help screenshots or help README are copied. `LICENSE`, `THIRD_PARTY_NOTICES.md`
and the ownership inventory are copied into `Contents/Resources/Licenses/`.
It does not copy all cached SwiftPM bundles, and it
does not package a driver. The DMG is app-only; the existing PKG path also builds
and packages a BlackHole-derived driver.

Retained review items: final name and contributor attribution, remote-photo
provenance/physical accuracy, historical prototype asset provenance, current
identity/migration policy, driver input and
corresponding source, GPL distribution route, real signing/notarization and
installation acceptance. The manual HID probe remains useful for Chromecast
reports. None of these are resolved by removing the old X6 design or its runtime.

## Verification boundary

Use [README test commands](../README.md#test), the exact candidate commit's macOS
CI result, and the [release acceptance checklist](CHROMECAST_ACCEPTANCE.md).
`Tools/check-branding.py` checks the neutral visible identity and removed artwork
without erasing required attribution or stable identifiers. Runtime-cleanup checks
should assert absent legacy implementations while requiring
the device-neutral replacements. Regression tests cover keyboard edges, current
profiles, old-archive filtering and preservation of unrelated stored data.

Local source checks, Markdown link checks and isolated packaging fixtures prove
only their own contracts. Package fixtures use stand-in build/signing tools;
macOS CI must additionally build and inspect a real app bundle. Neither proves
physical Chromecast behavior, external speech recognition, native rendering,
permission prompts, a compliant driver release or successful installation.
