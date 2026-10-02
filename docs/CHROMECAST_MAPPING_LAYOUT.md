# Chromecast mapping layout alignment

Reference: [HD838A/remote-mic-app at 5a10bba28bd1514892a2a7400ae594629f728da7](https://github.com/HD838A/remote-mic-app/tree/5a10bba28bd1514892a2a7400ae594629f728da7).
Inspected actual pixels in:

- `Screenshots/settings-page/sidebar-profile-login-20260922/light/mapping-1020x772.png`
- `Testing/artifacts/chromecast-layout/mapping-zh-Hans-light-1400x2000.png`

Public `RemoteMappingCanvas.swift` establishes the common card treatment;
`SettingsView.swift` establishes the inline editor placement and scrolling.
The Chromecast-specific canvas is supplied by a private package, so its layout
was compared against the public Chromecast screenshot, not guessed from the
Xiaomi button set. No private package, reference code, image or branding was copied.

## Visible corrections

| Element | Previous implementation | Revised implementation |
| --- | --- | --- |
| Gestures | Three vertical rows, label and value beside each other | Three equal horizontal cells: single, double, long; label above value |
| Left column | Up, left, select, back, Home, YouTube, power | Up, left, down, back, Home, YouTube, power |
| Right column | Right, down, volume+, volume−, mute, Netflix, input | Select, right, volume+, volume−, voice, mute, Netflix, input |
| Voice | Full-width panel below photo | Reserved voice card in right column, fifth row; settings link only |
| Connections | Disconnected cards and large overlay circles | Curved photo-to-card arrows; selected callout blue, latest received report green |
| Photo | 240 × 360 | Up to 300 × 450, original front-and-side user asset retained |
| Selection | Border only; edited gesture laid out as row | Tinted card and arrow, independently outlined selected gesture cell |
| Editor | Below separate voice panel, scrolled to bottom | Below canvas, scrolled to editor top; same action/shortcut/app editor |
| Narrow widths | Columns compressed implicitly | 760-point canvas minimum with horizontal scroll; vertical page scroll retained |

The reference photo differs from the user's image: its front view and side
volume control cannot share the same anchor coordinates. All 15 normalized
anchors here refer to the existing 1024 × 1536 front-and-side image. Photo,
hotspots and connectors use the same aspect-preserving rectangle. Card width
is 218 points at canvas width 760, and 300 at the current approximately
924-point content width. Rows are 72 points high with 6-point gaps.

This is functional layout alignment, not a claim of pixel-identical rendering.
The existing three-page console, user photo, app theme, action defaults and
mapping behavior remain vRemoter's. In particular, the reference's system-managed
key policies are not imported as layout changes. Voice timing and gesture
recognition code are untouched. The voice card has no ordinary gesture cells.

## Validation

- `python3 Tools/check-mapping-layout.py`: passed on Linux; checks ordered
  hardware IDs, source layout contracts and geometry at 760/800/924/1020/1400.
- `git diff --check`: passed.
- `SelfTests/ChromecastMappingLayoutTests.swift` added to the existing model-test
  runner: checks actual Swift geometry and ordered placement invariants in CI.
- Swift build, Swift regression suites and native screenshots were not run in
  this Linux workspace because no Swift toolchain/AppKit renderer is available.
  macOS CI must validate compilation and existing transport/gesture/theme tests.
  Native light/dark rendering, text truncation and real pointer/keyboard scroll
  behavior still require macOS UI verification; static geometry is not that proof.
