#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if ! command -v swiftc >/dev/null 2>&1; then
  printf '%s\n' 'BLOCKED: swiftc is not installed. Run this Foundation-only suite on a Swift-enabled machine.' >&2
  exit 127
fi
OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/vremote-voice-tests.XXXXXX")"
trap 'rm -rf "$OUTPUT"' EXIT
swiftc \
  "$ROOT/Sources/vRemote/ChromecastVoiceStateMachine.swift" \
  "$ROOT/Sources/vRemote/VoiceConfiguration.swift" \
  "$ROOT/Sources/vRemote/ChromecastVoiceSessionController.swift" \
  "$ROOT/SelfTests/ChromecastVoice/main.swift" \
  -o "$OUTPUT/voice-tests"
"$OUTPUT/voice-tests"
