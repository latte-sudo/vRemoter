#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v swiftc >/dev/null 2>&1; then
  echo 'BLOCKED: Swift 5.9+ is required for the localization runtime tests.' >&2
  exit 127
fi
mkdir -p .build/localization-tests
cp -R Sources/vRemote/Resources/*.lproj .build/localization-tests/
swiftc Sources/vRemote/Localization.swift Sources/vRemote/VoiceSessionPresentation.swift Sources/vRemote/AudioRouteConfiguration.swift SelfTests/LocalizationTests.swift -o .build/localization-tests/localization
.build/localization-tests/localization
