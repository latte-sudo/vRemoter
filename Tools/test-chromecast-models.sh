#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v swiftc >/dev/null 2>&1; then
  printf '%s\n' 'BLOCKED: swiftc is not installed. Run this suite on a Swift-enabled machine; AppKit cases require macOS.' >&2
  exit 127
fi
mkdir -p .build/chromecast-tests
cp -R Sources/vRemote/Resources/*.lproj .build/chromecast-tests/
swiftc Sources/vRemote/Localization.swift Sources/vRemote/VoiceSessionPresentation.swift Sources/vRemote/MenuBarVoiceReception.swift SelfTests/MenuBarVoiceReceptionTests.swift -o .build/chromecast-tests/menu-bar-voice
.build/chromecast-tests/menu-bar-voice
swiftc Sources/vRemote/Localization.swift Sources/vRemote/KeyboardTriggerState.swift SelfTests/KeyboardTriggerStateTests.swift -o .build/chromecast-tests/keyboard-trigger
.build/chromecast-tests/keyboard-trigger
swiftc Sources/vRemote/Localization.swift Sources/vRemote/PermissionRequestSupport.swift SelfTests/PermissionRequestTests.swift -o .build/chromecast-tests/permissions
.build/chromecast-tests/permissions
swiftc Sources/vRemote/Localization.swift Sources/vRemote/ChromecastMappingLayout.swift SelfTests/ChromecastMappingLayoutTests.swift -o .build/chromecast-tests/mapping-layout
.build/chromecast-tests/mapping-layout
swiftc Sources/vRemote/Localization.swift Sources/vRemote/AudioRouteConfiguration.swift SelfTests/AudioRouteConfigurationTests.swift -o .build/chromecast-tests/audio
.build/chromecast-tests/audio
swiftc Sources/vRemote/Localization.swift Sources/vRemote/DockVisibility.swift SelfTests/DockVisibilityTests.swift -o .build/chromecast-tests/dock
.build/chromecast-tests/dock
swiftc Sources/vRemote/Localization.swift Sources/vRemote/AppAppearance.swift SelfTests/AppAppearanceTests.swift -o .build/chromecast-tests/appearance
.build/chromecast-tests/appearance
swiftc Sources/vRemote/Localization.swift Sources/vRemote/RemoteDisplayName.swift SelfTests/RemoteDisplayNameTests.swift -o .build/chromecast-tests/remote-name
.build/chromecast-tests/remote-name
bash Tools/run-gesture-tests.sh
swiftc Sources/vRemote/Localization.swift Sources/vRemote/VoiceSessionPresentation.swift SelfTests/VoiceSessionPresentationTests.swift -o .build/chromecast-tests/voice-presentation
.build/chromecast-tests/voice-presentation
swiftc Sources/vRemote/Localization.swift Sources/vRemote/OnboardingProgress.swift SelfTests/OnboardingProgressTests.swift -o .build/chromecast-tests/onboarding-progress
.build/chromecast-tests/onboarding-progress
bash run-chromecast-voice-tests.sh
bash Tools/test-voice-launcher.sh

swiftc Sources/vRemote/Localization.swift Sources/vRemote/OnboardingSpeechEvidence.swift SelfTests/OnboardingEvidenceTests.swift -o .build/chromecast-tests/onboarding
.build/chromecast-tests/onboarding
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc Sources/vRemote/Localization.swift Sources/vRemote/AppAppearance.swift Sources/vRemote/AppAppearanceController.swift SelfTests/AppAppearanceControllerTests.swift -o .build/chromecast-tests/appearance-controller
  .build/chromecast-tests/appearance-controller
  swiftc Sources/vRemote/Localization.swift Sources/vRemote/RemoteButtonGestures.swift Sources/vRemote/RemoteMappingSupport.swift Sources/vRemote/AudioRouteConfiguration.swift Sources/vRemote/ChromecastVoiceStateMachine.swift Sources/vRemote/VoiceConfiguration.swift Sources/vRemote/DockVisibility.swift Sources/vRemote/AppAppearance.swift Sources/vRemote/RemoteDisplayName.swift Sources/vRemote/ChromecastSettingsArchive.swift SelfTests/ChromecastArchiveTests.swift -o .build/chromecast-tests/archive
  .build/chromecast-tests/archive
fi
