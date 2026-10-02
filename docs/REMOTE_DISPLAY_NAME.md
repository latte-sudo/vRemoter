# Current remote display name

Settings → 当前遥控器名称 provides a draft field, 保存名称, and 恢复默认名称.
Only Save (or Return in the field) commits the draft. Leading/trailing whitespace
is trimmed; saving an empty/whitespace-only name or restoring the default removes
the override and shows `Chromecast Voice Remote`. Names are limited to 64 Swift
Characters (user-perceived characters), with a 4096-byte UTF-8 safety bound.
Internal newlines, control characters and explicit Unicode direction controls
are rejected. Chinese, natural RTL text, combining marks and emoji are supported.
Invalid input leaves the prior saved value unchanged.

The name updates the console header, connection card, audio-source description,
mapping context, settings, menu status and menu-bar tooltip immediately. The
saved preference survives app restarts. Saving a name does not stop audio,
reconnect Bluetooth, change any mapping, or invalidate the speech test.
Long names truncate in the fixed-width header with the full name available via
hover and in the Settings field. The connection card retains the hardware model
as a separate caption so an alias cannot obscure which model is supported.

## Identity and Bluetooth scope

`chromecast.remoteDisplayName` is one app-local preference for the current
Chromecast profile. It is not a physical-device binding and cannot distinguish
or select multiple remotes. It is never used as a BLE name hint, saved UUID,
HID matching value, recording prefix or analytics identifier. Multiple-device
binding remains deferred. Renaming a label does not implement it.

The app does not rename the system Bluetooth device or synchronize that name.
The existing BLE discovery still expects `Chromecast Remote`, including name
validation after retrieving a saved UUID. A separate manual system rename may
affect reconnection if it changes the name exposed to CoreBluetooth. No automatic
system-rename action is offered, and this work deliberately leaves the Bluetooth
identity and matching logic unchanged.

## Configuration archives and migration

The optional name key is included in existing version-1 archives. Import checks
the string type and the same name rules before changing settings; restore trims
the value, and an empty value removes the override. Old v1 archives without a
name remain valid and restore the default, just like a new install or an upgrade
without this preference. Reset, import undo and onboarding cancellation restore
the corresponding saved name and update the presentation. Invalid local values
also fall back to the model name. The schema version and archive filename remain
unchanged. Old app builds do not understand this new optional key and may reject
an archive exported by this build; import compatibility is backward-facing.

## Verification

`bash Tools/test-chromecast-models.sh` runs the Foundation-only name tests and,
on macOS, archive regression tests for the new key. They cover trim, Chinese,
emoji, RTL text, exact/over-limit names, invalid controls and types, preserving
the old value on an invalid save/import, preference rereading, reset, export,
restore/undo and older v1 archives. The existing macOS CI compiles the application
and runs the aggregate suite. Linux edits and source checks are not a macOS build.

Remaining native acceptance before release:

- Save, press Return, repeat Save, edit without saving, restore default, and
  save empty input; verify all presentation surfaces and accessibility labels
- Enter a long Chinese/emoji name and inspect the fixed-size window for clipping;
  check validation while pasting multiline/over-limit text
- Rename while disconnected, while connected and during a voice session; ensure
  no voice interruption, remapping change or reconnect occurs
- Close/reopen the console and restart the app; verify the saved name
- Export, rename, import, reset and undo; import an older v1 archive and cancel
  onboarding; verify the intended name returns and invalid imports change nothing
- Reconnect the same physical remote with its unchanged Bluetooth name; verify
  normal voice/buttons, including existing continuous scrolling
