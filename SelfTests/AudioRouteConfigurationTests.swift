// Standalone pure-Foundation tests, no audio device or microphone permissions.
// swiftc Sources/vRemote/AudioRouteConfiguration.swift \
//   SelfTests/AudioRouteConfigurationTests.swift -o /tmp/vremoter-audio-tests
// /tmp/vremoter-audio-tests
import Foundation

@main
struct AudioRouteConfigurationTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            exit(1)
        }
    }

    static func main() {
        require(AudioRouteConfiguration.clampedGain(-1) == 0, "negative gain clamps to mute")
        require(AudioRouteConfiguration.clampedGain(25) == 20, "gain clamps to safe maximum")
        require(AudioRouteConfiguration.clampedGain(3.5) == 3.5, "valid gain is preserved")
        require(AudioRouteConfiguration.clampedGain(.nan) == 10, "NaN resets to finite default")
        require(AudioRouteConfiguration.clampedGain(.infinity) == 10, "infinite gain is rejected")

        let suiteName = "vRemoter.AudioRouteConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        require(AudioRouteConfiguration.storedRemoteGain(in: defaults) == 10, "fresh gain defaults to 10")
        require(AudioRouteConfiguration.storedOutputUID(in: defaults) == nil, "fresh route is unset")
        AudioRouteConfiguration.storeOutputUID("device-stable-uid", in: defaults)
        require(AudioRouteConfiguration.storedOutputUID(in: defaults) == "device-stable-uid", "UID persists")
        AudioRouteConfiguration.storeRemoteGain(50, in: defaults)
        require(AudioRouteConfiguration.storedRemoteGain(in: defaults) == 20, "clamped gain persists")
        defaults.set("bad imported gain", forKey: AudioRouteConfiguration.remoteGainKey)
        require(AudioRouteConfiguration.storedRemoteGain(in: defaults) == 10, "non-numeric imported gain uses default")
        defaults.set(Double.nan, forKey: AudioRouteConfiguration.remoteGainKey)
        require(AudioRouteConfiguration.storedRemoteGain(in: defaults) == 10, "non-finite imported gain uses default")
        AudioRouteConfiguration.storeOutputUID(nil, in: defaults)
        require(AudioRouteConfiguration.storedOutputUID(in: defaults) == nil, "output can be disabled")
        require(defaults.object(forKey: AudioRouteConfiguration.selectedOutputUIDKey) != nil, "disabled output remains an explicit preference")

        let route = AudioOutputRoute(
            uid: "loopback", name: "vRemoteDr 2ch", sampleRate: 48_000,
            channelCount: 2, unavailableReason: nil
        )
        let alternate = AudioOutputRoute(
            uid: "blackhole", name: "BlackHole 2ch", sampleRate: 44_100,
            channelCount: 2, unavailableReason: nil
        )
        let unsupported = AudioOutputRoute(
            uid: "unsupported", name: "vRemoteDr 2ch", sampleRate: 0,
            channelCount: 0, unavailableReason: "Unsupported format"
        )
        require(AudioRouteConfiguration.preferredOutputUID(in: [alternate, route], savedUID: nil, hasSavedSelection: false) == "loopback", "first launch prefers bundled loopback")
        require(AudioRouteConfiguration.preferredOutputUID(in: [alternate], savedUID: "missing-device", hasSavedSelection: true) == "missing-device", "missing saved route does not fall back")
        require(AudioRouteConfiguration.preferredOutputUID(in: [route], savedUID: nil, hasSavedSelection: true) == nil, "explicit output off does not rebind")
        require(AudioRouteConfiguration.preferredOutputUID(in: [unsupported, alternate], savedUID: nil, hasSavedSelection: false) == nil, "unsupported route is not auto-selected")
        require(AudioRouteConfiguration.preferredOutputUID(in: [alternate], savedUID: nil, hasSavedSelection: false) == nil, "other virtual output requires explicit selection")

        for rate in [8_000.0, 16_000, 44_100, 48_000, 96_000, 192_000] {
            let tone = AudioRouteConfiguration.testTone(sampleRate: rate)
            require(tone.count == Int(rate), "tone has exactly one second of samples at \(rate)")
            require(tone.first == 0 && tone.last == 0, "tone fades at both ends")
            require(tone.allSatisfy { $0.isFinite && abs($0) <= 0.100_001 }, "tone stays below -20 dBFS")
            require(tone.contains { abs($0) > 0.09 }, "tone is not silent")
        }
        for rate in [0.0, -1, 1, 384_000, Double.nan, Double.infinity] {
            require(AudioRouteConfiguration.testTone(sampleRate: rate).isEmpty, "unsupported tone rate is rejected")
        }
        print("PASS: audio gain, persistence, selection safety, and one-second tone")
    }
}
