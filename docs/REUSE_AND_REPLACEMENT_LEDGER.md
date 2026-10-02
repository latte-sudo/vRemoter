# Reuse and replacement ledger

| Item | Current source/use | Follow-up |
| --- | --- | --- |
| vRemoter baseline | User fork based on upstream commit `15076345d955fcc81dae659150d1702b50b8010a`; existing license retained | Review upstream attribution when distributing |
| SayAll functional reference | `HD838A/remote-mic-app` at `5a10bba28bd1514892a2a7400ae594629f728da7`; workflow/behavior studied; no source or private package copied for this implementation | Re-review GPL-3.0-only obligations if any source is copied later |
| Chromecast image | User-provided image, enhanced front + reconstructed side volume illustration | Replace with user's final accurate transparent production asset; check proportions and buttons on real hardware |
| Existing vRemoter icon, permission screenshots and design history | Retained active icon/help and design sources; unused remote/promotional copies removed | Replace branding/screenshots as the user finalizes UI; existing trademarks are not a new permission grant |
| Virtual driver | Existing modified BlackHole-based vRemoteDr route, not rewritten or bundled anew | Existing GPL notices and distribution obligations remain; review before distributing a binary |
| Target compatibility | Doubao observation retained; custom target uses explicit shortcut configuration and user test | Test each target/version; do not label custom selection as verified compatibility |
| Legacy names/types | X6 coordinator/types remain in source solely to avoid unrelated refactoring | Can remove in a later cleanup after regression coverage; runtime does not initialize X6 transport |
| Existing release/update/commerce/telemetry code and promotional site | Removed in native-interface cleanup, including original online endpoints and dependency | Any future service needs an explicit owner/configuration and its own review |

This ledger records remaining replacement/review work; it does not imply that licensing restrictions disappear after temporary reuse. No unavailable SayAll Chromecast/private module was obtained or copied.

Detailed legal ownership and unresolved release choices: [inventory](PROJECT_OWNERSHIP_AND_LICENSES.md). Exact cleanup execution and retained shared dependencies: [cleanup review](CLEANUP_REVIEW.md).
