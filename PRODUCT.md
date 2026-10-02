# Chromecast product scope

vRemoter is a focused macOS 12+ utility for Chromecast Voice Remote audio and
Mac shortcuts. The SwiftUI interface uses approved HTML v7 as its current design reference:
seven-step onboarding and Voice & Audio / Remote / Permissions & Diagnostics /
Settings navigation. The real photo-based mapping canvas is shared by setup and
settings.

The remote and the chosen speech tool have independent hold/toggle semantics.
vRemoter transports audio and sends matching trigger keys; recognition belongs
to the target tool. Actual PCM, safe end-of-session handling and human recognition
confirmation are separate facts. Connectivity and test tones do not prove speech
recognition.

- Preserve transport/shortcut/resource safety and customized Chromecast mappings
- Expose real global voice state, input level, elapsed time and an accessible stop
- Require explicit import/reset confirmation and offer export first
- Respect Light/Dark/System appearance, Reduce Motion, keyboard and VoiceOver
- Keep Mac microphone capture disabled, including upgrades
- Keep multi-device/host binding, Windows/phone support, macros, per-application
  profiles, transcript history and new driver distribution outside current scope

The X6 transport/controller/profile and frozen dual-input/mixer design are removed.
Shared keyboard observation and voice interfaces continue to support Chromecast;
old on-disk preferences are not erased. Existing icons and brand identity remain
pending an explicit release decision.

See [architecture](docs/NATIVE_INTERFACE_IMPLEMENTATION.md),
[release acceptance](docs/CHROMECAST_ACCEPTANCE.md), [deferred work](TODO.md),
and [provenance and licensing](docs/PROJECT_OWNERSHIP_AND_LICENSES.md).
