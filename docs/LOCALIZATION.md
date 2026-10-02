# Language and interface copy

The app supports `system`, `zh-Hans`, `zh-Hant` and `en` as stable values under
`vRemoter.appLanguage`. A new installation follows the first macOS preferred
language: explicit Chinese scripts win over region, Taiwan/Hong Kong/Macao use
Traditional Chinese, other Chinese locales use Simplified Chinese, and an
unsupported language uses English. The app never writes `AppleLanguages`.

Language is available in Settings, the first-run sidebar and the menu bar. It is
saved immediately. `LanguageStore` refreshes existing SwiftUI views and an app
notification updates AppKit menu items, tooltips and window titles in place.
Changing language does not recreate the window, reconnect the device, save voice
configuration, reset a trial, clear feedback, or stop/restart a voice session.

## Resources and packaging

`Sources/vRemote/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings` contain
478 reviewed semantic keys in each language. `L10n.tr` resolves the selected
language; `{0}`, `{1}` and subsequent numbered placeholders allow reordering.
Substitution happens once against the original template, so user text containing
braces is not interpreted. Labels with numeric counts avoid English singular/
plural grammar. Product names, physical key symbols and app/file/device names
are preserved. A missing translated key falls back to English; static checks
reject missing keys before release.

SwiftPM processes these resources and provides `Bundle.module`. `package-app.sh`
copies only the three app-owned `.lproj` directories into `Contents/Resources`,
then adds OS permission metadata from `Packaging/*.lproj`. The executable first
looks for its own packaged resources and otherwise uses the SwiftPM bundle.
No network translation service or generated runtime translation is used.

## Coverage and intentional boundaries

Onboarding, settings, menus, permission guidance, shortcut capture, mapping
controls, accessibility labels, feedback, app-owned errors and voice/audio
statuses use localized resources. Cached failures retain typed identities or
semantic keys, so a language change does not change device equality or lose
failure history. Technical audio detail is behind a disclosure; log records and
protocol/status-code diagnostics remain technical.

The backup summary is plain user guidance: save app settings, and reconnect the
remote and grant permissions again on another Mac. Native archives remain
version 1 property lists. The developer-only HTML prototype still uses JSON;
those formats cannot be imported into each other, but that implementation detail
is no longer customer-facing copy. A new backup can restore an explicit language.
Reset and older archives without a language field preserve the current language
so users can still read the interface. Invalid language codes reject the archive
without changing settings.

macOS-owned permission prompts, standard file-panel controls and external speech
apps follow their own language settings. The app supplies three localized usage
strings, but does not override the OS prompt language. Original permission-guide
screenshots contain Simplified Chinese; English/Traditional views instead use a
translated, explicitly labelled illustration. Legal/source notices are preserved
without altering obligations. User-entered names and shortcuts stay unchanged.

## Verification

- `python3 Tools/check-localization.py`: resource syntax, duplicate/key parity,
  placeholder parity, referenced keys, app-owned source text and non-interrupting
  language actions
- `bash Tools/test-localization.sh`: real Foundation resource parsing, locale
  mapping, persistence, notifications, immediate text lookup, safe placeholders,
  and voice-session/audio-route invariance
- `swift run vRemote --localization-self-test`: actual SwiftPM runtime resource
  loading before AppKit, Bluetooth, audio or preferences are initialized
- `dist/build/vRemote.app/Contents/MacOS/vRemote --localization-self-test`: actual
  packaged executable resource loading, also without normal app startup
- Existing archive tests cover all four stable values, invalid types/codes, new
  backup round-trip, old-backup preservation, reset preservation and rejected
  import isolation. Existing protocol/voice/mapping harnesses use the real
  localization implementation rather than test-only translation shims
- Packaging fixtures test clean/rebuild copying and reject missing Traditional
  Chinese resources; actual bundle checks compare every resource to source

The implementation environment is Linux without Swift. Static/source/fixture
checks pass there; native compile and runtime checks are delegated to macOS CI.
Native visual QA still needs all three languages at minimum window size, open
menus and permission/shortcut sheets, long names, VoiceOver, theme switching,
language changes during a live physical voice session, and interrupted/repeated
onboarding. A source contract is not evidence of native rendering or hardware
acceptance.
