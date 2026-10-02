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
  "$ROOT/Sources/vRemote/AudioResourceLease.swift" \
  "$ROOT/SelfTests/AudioResourceLeaseTests.swift" \
  "$ROOT/Sources/vRemote/ATVVStreamLifecycle.swift" \
  "$ROOT/Sources/vRemote/ATVV/BridgeError.swift" \
  "$ROOT/Sources/vRemote/ATVV/ADPCMDecoder.swift" \
  "$ROOT/Sources/vRemote/ATVV/ATVVProtocol.swift" \
  "$ROOT/Sources/vRemote/ChromecastVoiceStateMachine.swift" \
  "$ROOT/SelfTests/ChromecastVoice/TransportTests.swift" \
  "$ROOT/Sources/vRemote/VoiceConfiguration.swift" \
  "$ROOT/Sources/vRemote/ChromecastVoiceSessionController.swift" \
  "$ROOT/SelfTests/ChromecastVoice/main.swift" \
  -o "$OUTPUT/voice-tests"
RUNS="${VREMOTE_VOICE_TEST_REPETITIONS:-1}"
if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || (( RUNS > 100 )); then
  printf '%s\n' 'VREMOTE_VOICE_TEST_REPETITIONS must be 1...100' >&2
  exit 2
fi
for (( run = 1; run <= RUNS; run++ )); do
  printf 'Voice regression iteration %s/%s\n' "$run" "$RUNS"
  "$OUTPUT/voice-tests"
done
