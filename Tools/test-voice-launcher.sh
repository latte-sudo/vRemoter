#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/chromecast-tests
cp -R Sources/vRemote/Resources/*.lproj .build/chromecast-tests/
swiftc Sources/vRemote/Localization.swift Sources/vRemote/ChromecastVoiceStateMachine.swift Sources/vRemote/VoiceConfiguration.swift Sources/vRemote/VoiceApplicationLauncher.swift SelfTests/VoiceApplicationLauncherTests.swift -o .build/chromecast-tests/voice-launcher
.build/chromecast-tests/voice-launcher
