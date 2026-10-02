#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/chromecast-tests
swiftc Sources/vRemote/AudioRouteConfiguration.swift SelfTests/AudioRouteConfigurationTests.swift -o .build/chromecast-tests/audio
.build/chromecast-tests/audio
swiftc Sources/vRemote/DockVisibility.swift SelfTests/DockVisibilityTests.swift -o .build/chromecast-tests/dock
.build/chromecast-tests/dock
bash Tools/run-gesture-tests.sh
bash run-chromecast-voice-tests.sh
bash Tools/test-voice-launcher.sh

swiftc Sources/vRemote/OnboardingSpeechEvidence.swift SelfTests/OnboardingEvidenceTests.swift -o .build/chromecast-tests/onboarding
.build/chromecast-tests/onboarding
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc Sources/vRemote/RemoteButtonGestures.swift Sources/vRemote/RemoteMappingSupport.swift Sources/vRemote/AudioRouteConfiguration.swift Sources/vRemote/ChromecastVoiceStateMachine.swift Sources/vRemote/VoiceConfiguration.swift Sources/vRemote/DockVisibility.swift Sources/vRemote/ChromecastSettingsArchive.swift SelfTests/ChromecastArchiveTests.swift -o .build/chromecast-tests/archive
  .build/chromecast-tests/archive
fi
