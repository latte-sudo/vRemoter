# Permission requests in the packaged app

## User flow

Build with `package-app.sh`, optionally install with `install-app.sh` (replaces `~/Applications/vRemote.app`), then launch the
installed `~/Applications/vRemote.app` in Finder. The app's displayed name is
vRemoter. Building or copying an app alone does not request privacy access.
Use the same installed app when testing; a SwiftPM executable launched from
VS Code or a terminal is not proof that the packaged app has permission.

The first-run **权限** step and **权限与诊断 / Permissions & Diagnostics** page offer separate actions:

- **请求权限** invokes the relevant system API for an ungranted permission
- **打开设置** opens that permission's System Settings page without requesting
- **重新检查权限** reads current authorization state without requesting
- **重新连接遥控器** retries input/transport startup after settings changes;
  it does not grant permissions

The user still decides in macOS. A request is never displayed as a successful
grant until the app reads a granted state back from the system. A system prompt
may be asynchronous or absent when an earlier choice already exists.

## Implemented APIs and scope

- Accessibility: `AXIsProcessTrustedWithOptions` with
  `kAXTrustedCheckOptionPrompt = true`; status remains `AXIsProcessTrusted`
- Input Monitoring: `CGRequestListenEventAccess`; status remains
  `CGPreflightListenEventAccess`
- Bluetooth: `CBCentralManager` creation when `CBManager.authorization` is
  `.notDetermined`. CoreBluetooth has no separate request-authorization API.
  The existing transport also creates its manager at startup, so the first
  Bluetooth prompt can appear before the user reaches the permission page.
  The request helper retains its manager but does not scan or connect devices
- Mac microphone: no new request. This Chromecast-only release forces Mac
  input off and receives remote PCM over Bluetooth. The selected voice tool
  requests its own permission to read the virtual microphone

The request gate permits at most one explicit request per permission per app
launch. Subsequent ungranted clicks show guidance for a pending system prompt
or System Settings. Known Bluetooth denials go directly to that guidance;
restricted/unknown states are reported without issuing a request. The Boolean
Accessibility/Input Monitoring preflight APIs do not distinguish a previous
denial from a never-requested state, so the UI does not claim to know which one
occurred. Existing allowed states always take precedence over request history.

If the app is missing from the settings list, use the add button where the
macOS version/page provides one and select the installed app. If macOS asks to
quit and reopen the app, do so. No TCC database edits, resets, permission grants,
or system setting changes are performed by this code.

## Identity and packaging

`Packaging/Info.plist` retains `local.simaqingfeng.vRemote`, the usage strings,
and the vRemoter display name. `package-app.sh` retains the ad-hoc signature and
explicit designated requirement. Keeping the bundle identity, signature policy,
and installation location consistent reduces identity churn; it does not
guarantee authorization survives every rebuild, signing change, or OS update.
This change does not add Developer ID signing or notarization.

## Verification

`SelfTests/PermissionRequestTests.swift` exercises allowed, undetermined,
Boolean-ungranted, denied, restricted and unknown states, repeated clicks,
independent requests and a later grant in Settings. It runs from
`Tools/test-chromecast-models.sh`, including the existing macOS CI workflow.
These tests never call system request APIs or alter permissions.

Required Mac acceptance (not proven by model tests or CI):

1. From a packaged app with fresh authorization state, request Accessibility
   and Input Monitoring and verify the actual system prompt/list entry
2. Grant each permission; return, check status, reconnect if needed, and verify
   real shortcut/HID behavior
3. Deny Bluetooth or another permission; a new request must not be presented as
   a grant, and settings guidance must remain usable
4. Repeatedly click request while a prompt is pending; do not stack requests
5. Toggle permissions externally; checks reflect the live state, with a
   relaunch when required by macOS
6. Verify neither **重新检查权限** nor entering/reopening the permissions page
   initiates a request; no Mac microphone prompt is introduced
7. Review layout and keyboard/VoiceOver access on the minimum supported macOS

Cloud-only static inspection cannot validate macOS prompts, signing identity,
or physical Bluetooth devices.

## Apple references

- [Privacy & Security settings, macOS 26](https://support.apple.com/zh-cn/guide/mac-help/mchl211c911f/26/mac/26)
- [Allow accessibility apps to access your Mac](https://support.apple.com/guide/mac-help/mh43185/mac)
- [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [What's New in Core Bluetooth](https://developer.apple.com/videos/play/wwdc2019/901/)
- [macOS Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/_index.html)
