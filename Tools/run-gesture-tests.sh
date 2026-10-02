#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v swiftc >/dev/null 2>&1; then
  printf '%s\n' 'Swift compiler is required. Run this script with Swift 5.9+ on Linux or macOS.' >&2
  exit 127
fi
mkdir -p "$ROOT/.build"
swiftc \
  "$ROOT/Sources/vRemote/RemoteButtonGestures.swift" \
  "$ROOT/SelfTests/Gestures/RemoteButtonGestureTests.swift" \
  -o "$ROOT/.build/remote-gesture-tests"
"$ROOT/.build/remote-gesture-tests"

if [[ "$(uname -s)" == Darwin ]]; then
  swiftc \
    "$ROOT/Sources/vRemote/RemoteButtonGestures.swift" \
    "$ROOT/Sources/vRemote/RemoteMappingSupport.swift" \
    "$ROOT/SelfTests/Gestures/RemoteMappingStoreTests.swift" \
    -o "$ROOT/.build/remote-mapping-store-tests"
  "$ROOT/.build/remote-mapping-store-tests"
  swiftc \
    "$ROOT/Sources/vRemote/RemoteButtonGestures.swift" \
    "$ROOT/Sources/vRemote/RemoteMappingSupport.swift" \
    "$ROOT/Sources/vRemote/RemoteButtonMappingController.swift" \
    "$ROOT/SelfTests/Gestures/RemoteButtonMappingControllerTests.swift" \
    -o "$ROOT/.build/remote-mapping-controller-tests"
  "$ROOT/.build/remote-mapping-controller-tests"
else
  printf '%s\n' 'SKIP: AppKit mapping-store/controller tests require macOS; pure gesture tests ran above.'
fi
