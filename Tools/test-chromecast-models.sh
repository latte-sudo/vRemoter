#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/chromecast-tests
swiftc Sources/vRemote/PermissionRequestSupport.swift SelfTests/PermissionRequestTests.swift -o .build/chromecast-tests/permissions
.build/chromecast-tests/permissions
swiftc Sources/vRemote/ChromecastMappingLayout.swift SelfTests/ChromecastMappingLayoutTests.swift -o .build/chromecast-tests/mapping-layout
.build/chromecast-tests/mapping-layout
swiftc Sources/vRemote/AudioRouteConfiguration.swift SelfTests/AudioRouteConfigurationTests.swift -o .build/chromecast-tests/audio
.build/chromecast-tests/audio
swiftc Sources/vRemote/DockVisibility.swift SelfTests/DockVisibilityTests.swift -o .build/chromecast-tests/dock
.build/chromecast-tests/dock
swiftc Sources/vRemote/AppAppearance.swift SelfTests/AppAppearanceTests.swift -o .build/chromecast-tests/appearance
.build/chromecast-tests/appearance
swiftc Sources/vRemote/RemoteDisplayName.swift SelfTests/RemoteDisplayNameTests.swift -o .build/chromecast-tests/remote-name
.build/chromecast-tests/remote-name
bash Tools/run-gesture-tests.sh
bash run-chromecast-voice-tests.sh
bash Tools/test-voice-launcher.sh

swiftc Sources/vRemote/OnboardingSpeechEvidence.swift SelfTests/OnboardingEvidenceTests.swift -o .build/chromecast-tests/onboarding
.build/chromecast-tests/onboarding
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc Sources/vRemote/AppAppearance.swift Sources/vRemote/AppAppearanceController.swift SelfTests/AppAppearanceControllerTests.swift -o .build/chromecast-tests/appearance-controller
  .build/chromecast-tests/appearance-controller
  swiftc Sources/vRemote/RemoteButtonGestures.swift Sources/vRemote/RemoteMappingSupport.swift Sources/vRemote/AudioRouteConfiguration.swift Sources/vRemote/ChromecastVoiceStateMachine.swift Sources/vRemote/VoiceConfiguration.swift Sources/vRemote/DockVisibility.swift Sources/vRemote/AppAppearance.swift Sources/vRemote/RemoteDisplayName.swift Sources/vRemote/ChromecastSettingsArchive.swift SelfTests/ChromecastArchiveTests.swift -o .build/chromecast-tests/archive
  .build/chromecast-tests/archive
fi
