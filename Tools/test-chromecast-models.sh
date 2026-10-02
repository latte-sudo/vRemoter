#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/chromecast-tests
swiftc Sources/vRemote/AudioRouteConfiguration.swift SelfTests/AudioRouteConfigurationTests.swift -o .build/chromecast-tests/audio
.build/chromecast-tests/audio
bash Tools/run-gesture-tests.sh
bash run-chromecast-voice-tests.sh

swiftc Sources/vRemote/OnboardingSpeechEvidence.swift SelfTests/OnboardingEvidenceTests.swift -o .build/chromecast-tests/onboarding
.build/chromecast-tests/onboarding
