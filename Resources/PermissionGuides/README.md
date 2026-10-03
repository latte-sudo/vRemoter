# Native permission-help illustrations

Permission and speech-tool input guidance now uses the app's native, localized
schematics in all three interface languages. The inherited eight macOS/Doubao
screenshots have been removed; this directory contains only this explanation.
No replacement screenshot, logo or third-party artwork is bundled here.

The schematics are implemented in `Sources/vRemote/DebugWindowController.swift`
and use the localized copy in `Sources/vRemote/Resources/*.lproj`. They explain
where to look; they are labelled illustrations rather than literal screenshots
of a particular macOS or speech-tool version. Actual controls may differ.

- Accessibility, Input Monitoring and Bluetooth guides explain the corresponding
  System Settings pages and the descriptive app display name
- Related microphone/App Management help and speech-tool input-selection guides
  remain explanatory; the current app never requests Mac microphone capture
- The experimental `vRemoteDr 2ch` device label remains an actual technical route
  name. Showing it does not install a driver or prove routing/recognition works

When changing guidance, update the native schematic and all three language tables,
then check readable labels, Light/Dark appearance and VoiceOver on macOS. Do not
restore inherited screenshot assets just to satisfy a missing-image fallback.
See [permission behavior](../../docs/PERMISSION_REQUESTS.md) and
[asset provenance](../../docs/PROJECT_OWNERSHIP_AND_LICENSES.md).
