# Chromecast first-round development

See [current scope](docs/CHROMECAST_FIRST_ROUND.md) and [reuse ledger](docs/REUSE_AND_REPLACEMENT_LEDGER.md). This branch supersedes the original dual-input/X6 product direction below for active runtime and UI.

# Current product direction

vRemoter is a focused macOS 12+ utility for Chromecast Voice Remote audio and
Mac shortcuts. The active UI follows approved HTML v6, implemented in SwiftUI:
seven-step onboarding and Voice & Audio / Remote / Permissions & Diagnostics /
Settings navigation. The existing real mapping canvas is preserved.

The remote and the chosen speech tool have independent hold/toggle semantics.
vRemoter transports audio and sends matching trigger keys; recognition belongs
to the target tool. Actual PCM, safe end-of-session handling and human recognition
confirmation are separate facts. Never infer transcription from connectivity or
a test tone.

- Keep transport/shortcut/resource safety and existing customized mappings
- Expose real global voice state, input level, elapsed time and an accessible stop
- Require explicit import/reset confirmation and offer export first
- Respect light/dark/system appearance, Reduce Motion, keyboard and VoiceOver
- Keep Mac microphone capture disabled in this Chromecast-focused runtime
- Keep identity binding, multiple remotes/hosts and new driver distribution out
  of this change; see TODO.md and the license/ownership inventory

The previous dual-input/X6 mixer direction and promotional services are historical,
not active UI requirements. Shared legacy-named types and tests can remain where
removing them would risk the current transport or existing preference isolation.
