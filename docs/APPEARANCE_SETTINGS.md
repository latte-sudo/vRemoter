# Application appearance

Settings → Appearance offers 跟随系统 / 浅色 / 深色 (System / Light / Dark). The selection takes effect immediately and persists across launches. New installs, existing installs without a preference, and invalid local preference values default to System.

The app-level `NSApplication.appearance` is the only appearance override. System clears it (`nil`) rather than snapshotting the current macOS appearance, so later OS appearance changes continue to propagate. Both existing AppKit windows and their SwiftUI hosts inherit it; the console and update window no longer force dark mode. Native dialogs, sheets and popovers inherit their owning app/window appearance. The setting never changes macOS appearance preferences.

Shared window/sheet palettes use semantic system backgrounds, labels and separators. Logo artwork, purchase QR-code white backgrounds, brand colors and the remote photograph keep their intrinsic colors.

The preference is included in v1 configuration archives. Import validates the three stable string values, reset returns to System, and undo restores the previous selection. Older v1 archives without the key remain valid and restore System. No schema-version bump is needed for this optional value.

## Regression coverage

`bash Tools/test-chromecast-models.sh` includes:

- Pure preference tests: default/upgrade, all three values, persistence, invalid values, reset
- macOS AppKit tests: repeated switches, existing window and SwiftUI hosting view inheritance, new panels, removal of the override for System
- Archive tests: valid/invalid appearance payloads, export/reset/restore and old-v1 import

The existing macOS workflow compiles the app and runs these tests with the other model regressions. This change was edited in Linux without `swiftc`; only shell syntax and whitespace checks ran locally. A green macOS workflow for the published commit is required before claiming build/test success.

## Remaining interactive acceptance

On macOS, switch each mode with the console and update window open; open and dismiss a sheet, popup and native import/export panel; close/reopen the console and restart the app. In System mode, change macOS appearance and confirm the app follows without restart. With a fixed mode, confirm it remains fixed. Test configuration import/reset/undo and an older archive. Inspect label, focus, selection and disabled-control contrast in both modes with Increase Contrast enabled. These rendered checks and physical hardware behavior are not verified by Linux editing or the model tests.
