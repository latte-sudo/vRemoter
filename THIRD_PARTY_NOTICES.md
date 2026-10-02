# Third-party notices

The application's inherited vRemoter implementation is covered by the root
[LICENSE](LICENSE): MIT, Copyright (c) 2026 Sima Qingfeng. Keep that complete
license alongside this file in source and application distributions.

## Renamed and extracted inherited implementation

The Chromecast-only cleanup removes the X6 HID bridge, old X6 coordinator,
profile and legacy session self-test. Shared code derived from the inherited
implementation remains under the root MIT notice:

- `Sources/vRemote/KeyboardTriggerObserver.swift` retains keyboard observation
  from the former `X6SearchSuppressor.swift`; the X6 Search gate is removed
- `Sources/vRemote/RemoteVoiceSupport.swift` retains the shared microphone-open
  result and audio-state provider interfaces from the former
  `X6SessionCoordinator.swift`

Removing the obsolete X6 design, changing file names or extracting shared types
neither removes this provenance nor changes the applicable license. Existing
source copyright notices remain. Inherited logo assets and permission screenshots
have been removed from the current tree and packaging; a generic placeholder icon
and native localized help illustrations replace them.

## ATVV and ADPCM implementation

This project contains code adapted from
[fanxeon/mi-ao](https://github.com/fanxeon/mi-ao), under the MIT License,
Copyright (c) 2026 FanXeon@Poemcoder with Codex. The retained files are:

- `Sources/vRemote/ATVV/ADPCMDecoder.swift`
- `Sources/vRemote/ATVV/ATVVProtocol.swift`
- `Sources/vRemote/ATVV/BridgeError.swift`

The upstream notice also records that the ATVV protocol and IMA/DVI ADPCM
implementation were informed by [b0o/ATVVoice](https://github.com/b0o/ATVVoice),
MIT License, Copyright (c) 2026 Maddison Cohodas. This attribution is preserved;
this audit did not establish the extent of any directly copied code.

The existing protocol reference is the
[Google Voice over BLE specification v1.0](https://wangefan.github.io/linux_kernel_driver/resources/Google_Voice_over_BLE_spec_v1.0.pdf).
This is a documentation reference, not a grant to redistribute Google's
specification under the MIT License. No copy of that PDF is bundled here.

### MIT notices for the components above

MIT License

Copyright (c) 2026 FanXeon@Poemcoder with Codex
Copyright (c) 2026 Maddison Cohodas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Optional generated audio driver

`Driver/build-driver.sh` produces `vRemoteDriver.driver` by modifying a locally
installed build of [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole).
The original project documentation identifies BlackHole 0.4.1 as its baseline;
the script does **not** verify the installed input's version or hash. Check the
actual input for each build rather than assuming every generated driver is 0.4.1.

The BlackHole component remains under GNU GPL v3. The
[v0.4.1 source](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/BlackHole/BlackHole.c)
contains Copyright (C) 2019 Existential Audio Inc.; the applicable copyright
notices of the actual input must be preserved. The
[GPL license text](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/LICENSE)
is separate from this repository's MIT license.

The build script records its binary-level modifications. Copying an installed
driver is not evidence that all required notices are present in the generated
bundle, nor does the patch script alone establish complete Corresponding Source.
No driver binary or full BlackHole source tree is tracked in this repository.

Before distributing a generated driver or a PKG containing it, verify and
include the applicable GPL text and copyright notices, dated modification
notices, and the required Corresponding Source under an appropriate distribution
arrangement. BlackHole's
[developer guidance](https://github.com/ExistentialAudio/BlackHole/blob/v0.4.1/README.md#developer-guides)
also directs non-GPL-3.0 projects to obtain a license. This fork has not established
that its combined binary distribution is cleared; retain this as a release
review item. App-only distribution does not authorize shipping the driver under
MIT.

## Distribution inventory

The runtime cleanup removes TelemetryDeck 2.9.10 from new builds. Its historical
license at revision `bc7467592166e8f93fbde0140d2757b0635e1712` was a
[modified MIT license without an attribution-retention requirement](https://github.com/TelemetryDeck/SwiftSDK/blob/bc7467592166e8f93fbde0140d2757b0635e1712/LICENSE),
Copyright (c) 2020 Daniel Jilg. It should not be reported as a retained runtime
dependency once removed.

See `docs/PROJECT_OWNERSHIP_AND_LICENSES.md` for the source and asset inventory,
including the generic placeholder icon, preserved historical prototype, contribution
boundaries and still-unverified rights for the user-provided, AI-enhanced remote image. That audit is bundled as
`PROJECT_OWNERSHIP_AND_LICENSES.md` next to this notice in packaged app builds.
