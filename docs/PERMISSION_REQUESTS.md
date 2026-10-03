# Permission requests in the packaged app

## User flow

Build with `package-app.sh`, optionally install with `install-app.sh` (replaces `~/Applications/vRemote.app`), then launch the
installed `~/Applications/vRemote.app` in Finder. The app uses descriptive localized display names:
Remote Voice Utility / 遥控器语音工具 / 遙控器語音工具. Building or copying an app alone does not request privacy access.
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

`Packaging/Info.plist` retains the technical identifier `local.simaqingfeng.vRemote`
and uses the descriptive display name; `Packaging/*.lproj/InfoPlist.strings`
provides localized display names and permission usage strings. `package-app.sh` retains the ad-hoc signature and
explicit designated requirement. Keeping the bundle identity, signature policy,
and installation location consistent reduces identity churn; it does not
guarantee authorization survives every rebuild, signing change, or OS update.
This change does not add Developer ID signing or notarization. The inherited
identifier is retained for compatibility, not claimed as a user-owned namespace.
A final identity migration must coordinate bundle/signing/login-item identities,
installation paths, preferences and macOS permission reauthorization.

Permission help uses localized native schematics in every language; the old
screenshots are removed. Illustrations are guidance, not proof that a particular
system setting exists, that authorization is granted or that audio is working.

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

## Follow-along Settings guide

The native app now starts a temporary companion panel after an explicit
**Request Permission** (requested/manual-settings outcome) or **Open Settings**
action for Bluetooth, Accessibility or Input Monitoring. Request still invokes
only the existing request gate; it does not automatically open Settings after a
denial. Open Settings still does not request permission. Merely viewing the
page, refreshing status, reconnecting, or switching languages never starts a guide.

The panel follows the visible System Settings/System Preferences window. It
explains the intended privacy pane and installed app name, and lets the user
perform the change. It is not an arrow to a detected checkbox/switch. The app
does not know which pane or control Settings currently displays. macOS 12 uses
System Preferences wording; macOS 13+ uses System Settings wording. App language
may differ from the OS language, so the guide includes the OS-localized bundle
display name and installed app filename. OS layouts/labels can change. The
existing ⓘ instructions remain available if following is unavailable.

### Implementation and privacy boundary

- `PermissionFollowAlongController.swift` uses a nonactivating `NSPanel`, a
  250 ms timer (50 ms tolerance), and workspace activation/termination events
- Only while Settings is frontmost, `CGWindowListCopyWindowInfo` returns metadata;
  the code immediately filters to the Settings process and ordinary window layer
  and retains only bounds. It never reads window titles, captures images, inspects
  an Accessibility tree, watches global input, sends events, or writes Settings
- No Screen Recording or additional Accessibility permission is requested by the
  guide, so the Accessibility onboarding path has no permission bootstrap dependency
- Window geometry is temporary in-memory state, never logged, saved or uploaded
- Placement prefers free space beside the window and keeps the guide inside the
  relevant display's visible frame. If room is limited it may overlap part of
  Settings; the title-bar close button and Hide Guide remain available. It does
  not move or resize the Settings window. No animated movement is used
- The panel is ordered without activating the app or calling make-key APIs;
  it does not steal focus as it follows. Clicking its controls is intentional
  interaction. Escape is local to a focused guide, not a global shortcut

Each new explicit action replaces the prior guide. Native close/Hide Guide,
modal Cancel, onboarding skip/cancel/finish, page/step changes, console close and
app quit stop the timer and remove observers. A genuine preflight grant ends the
guide; a request or dismissal cannot synthesize a grant. After it has followed a
window, closing/minimizing Settings or switching away also ends the guide, so it
cannot reappear later without another explicit action. Before Settings first
appears there is a 60-second grace period for the system prompt/launch; no visible
window or unavailable metadata then ends the attempt. This timeout never ends an
active following session. If a system authentication dialog or an OS transition
ends following, the user can reopen the guide with Open Settings.

### Source and licensing

Research source, pinned on 2026-10-03:
[maka-agent/maka-cu, PermissionOnboardingApp.swift at 1b6c95c](https://github.com/maka-agent/maka-cu/blob/1b6c95cef032c15ada8c60dc1bdeb21a316ff353/apps/OpenComputerUse/Sources/OpenComputerUse/PermissionOnboardingApp.swift).
Its accessory-panel implementation uses `NSPanel`, window geometry, a 150 ms
poll, activation/drag observers, and a launch animation. Its package targets
macOS 14/Swift 6.2. This project implements a smaller macOS 12-compatible variant,
without the drag monitors, screen-capture permission flow, animation, private
APIs or executor. The lifecycle/geometry model and localized UI are implemented
for this project; upstream MIT attribution and full terms are retained in
`THIRD_PARTY_NOTICES.md`, which is already bundled by `package-app.sh`.

Apple describes geometry metadata and the distinction from protected window
contents/titles in [Advances in macOS Security, WWDC19](https://developer.apple.com/videos/play/wwdc2019/701/).
See also [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)),
[NSPanel focus behavior](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded),
and [NSScreen.screens](https://developer.apple.com/documentation/appkit/nsscreen/screens).
Missing metadata is handled by retaining manual help, never by requesting a
broader permission. These public APIs predate macOS 12; this is a compatibility
design, not a claim of visual acceptance on every supported OS.

### Additional verification

`SelfTests/PermissionFollowAlongTests.swift` runs through the existing model
suite/CI. It covers explicit start, read-only idle observations, delayed launch,
external grant, replacement, close/cancel/skip/navigation/quit model end,
Settings closure, leaving Settings, startup timeout, multi-display coordinate
conversion (left/above/below), constrained placement and unavailable screens.
`Tools/check-permission-guidance.py` checks production integration and prohibited
API boundaries. Static/model tests do not prove AppKit focus or TCC behavior.

Required Mac acceptance remains:

1. Packaged app on macOS 12 and a current macOS: follow Accessibility, Input
   Monitoring and Bluetooth before any Accessibility/Screen Recording grant
2. Drag/resize Settings on primary and secondary displays, including left,
   above/below, different scales, Dock/menu-bar edges and small visible areas
3. Switch apps, close/minimize Settings, close the console, skip/cancel setup,
   dismiss the guide, repeat requests, change language and quit the app; confirm
   no stale overlay, focus steal, leaked observer/timer or automatic reappearance
4. Grant/deny externally and obey any system-required restart; only actual
   authorization is reflected as granted, and reconnect/hardware checks remain
   separate. No request should be made by the guide's timer or Recheck
5. Check keyboard/VoiceOver, light/dark, and narrow-screen readability; test deep
   link failure, missing Settings metadata, an unavailable app-list entry, and
   authentication/restart prompts. Existing manual help must stay usable

The cloud Linux environment has no Swift compiler or AppKit. Neither native
compilation nor the Mac acceptance list is established by cloud source checks.
