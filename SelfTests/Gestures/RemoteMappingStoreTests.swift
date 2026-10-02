// macOS-only storage regression harness, compiled with the production mapping file.
import AppKit
import Foundation

enum L10n {
    static func text(_ chinese: String, _ english: String) -> String { english }
}
enum Key { static let syntheticMarker: Int64 = 0x56524D54 }

@main
struct RemoteMappingStoreTests {
    static func main() throws {
        try directionDefaultsAndNewTargets()
        let suite = "vRemote.mapping-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let button = RemoteProfiles.chromecastButtons.first { $0.id == "03" }!
        let voice = RemoteProfiles.chromecastButtons.first { $0.voiceControlled }!
        let shortcut = RemoteCustomShortcut(keyCode: 8, flags: 0, label: "C")
        let app = RemoteApplicationShortcut(bundleIdentifier: "com.example.Editor", path: "/Applications/Editor.app", name: "Editor")

        // Verify original 1.1.1 key names, not merely a round trip with new setters.
        defaults.set(RemoteMappingTarget.custom.rawValue, forKey: "remoteMapping.chromecast.03")
        defaults.set(try JSONEncoder().encode(shortcut), forKey: "remoteCustomMapping.chromecast.03")
        let store = RemoteMappingStore(defaults: defaults)
        precondition(store.target(for: button, remote: .chromecast) == .custom)
        precondition(store.customShortcut(for: button, remote: .chromecast) == shortcut)
        precondition(store.target(for: button, remote: .chromecast, gesture: .doubleClick) == .disabled)
        precondition(store.target(for: button, remote: .chromecast, gesture: .longPress) == .disabled)

        store.setCustomShortcut(shortcut, for: button, remote: .chromecast, gesture: .doubleClick)
        store.setApplication(app, for: button, remote: .chromecast, gesture: .longPress)
        let restored = RemoteMappingStore(defaults: defaults)
        precondition(restored.customShortcut(for: button, remote: .chromecast, gesture: .doubleClick) == shortcut)
        precondition(restored.application(for: button, remote: .chromecast, gesture: .longPress) == app)
        precondition(restored.target(for: button, remote: .chromecast, gesture: .longPress) == .launchApplication)
        precondition(restored.gestureConfiguration(for: button, remote: .chromecast).effectiveHoldRepeat == false)
        precondition(restored.repeatConflictDescription(for: button, remote: .chromecast) != nil)
        precondition(restored.target(for: button, remote: .chromecast) == .custom)

        // All write routes reject voice remapping.
        for gesture in RemoteButtonGesture.allCases {
            store.setTarget(.commandC, for: voice, remote: .chromecast, gesture: gesture)
            store.setCustomShortcut(shortcut, for: voice, remote: .chromecast, gesture: gesture)
            store.setApplication(app, for: voice, remote: .chromecast, gesture: gesture)
            precondition(store.application(for: voice, remote: .chromecast, gesture: gesture) == nil)
            precondition(store.customShortcut(for: voice, remote: .chromecast, gesture: gesture) == nil)
        }
        precondition(store.target(for: voice, remote: .chromecast) == .doubaoVoice)
        precondition(store.target(for: voice, remote: .chromecast, gesture: .longPress) == .disabled)
        store.setTarget(.doubaoVoice, for: button, remote: .chromecast)
        precondition(store.target(for: button, remote: .chromecast) == .custom)

        // Reset clears all gestures and payloads, restores defaults, and leaves
        // the enable toggle and legacy X6 data untouched.
        defaults.set(RemoteMappingTarget.commandV.rawValue, forKey: "remoteMapping.x6.k52")
        store.setEnabled(true, for: .chromecast)
        store.setHoldRepeats(false, for: button, remote: .chromecast)
        store.reset(.chromecast)
        precondition(store.target(for: button, remote: .chromecast) == .arrowUp)
        precondition(store.holdRepeats(for: button, remote: .chromecast))
        precondition(store.isEnabled(.chromecast))
        precondition(defaults.string(forKey: "remoteMapping.x6.k52") == RemoteMappingTarget.commandV.rawValue)
        for gesture in RemoteButtonGesture.allCases {
            precondition(store.customShortcut(for: button, remote: .chromecast, gesture: gesture) == nil)
            precondition(store.application(for: button, remote: .chromecast, gesture: gesture) == nil)
            if gesture != .click {
                precondition(store.target(for: button, remote: .chromecast, gesture: gesture) == (gesture == .longPress ? .scrollUp : .disabled))
            }
        }
        precondition(RemoteProfiles.activeRemotes == [.chromecast])
        print("PASS: mapping migration, save/reload, voice exclusion, repeat conflict and reset")
    }

    static func directionDefaultsAndNewTargets() throws {
        let directions: [(String, RemoteMappingTarget)] = [
            ("03", .scrollUp), ("04", .scrollDown), ("05", .scrollLeft), ("06", .scrollRight)
        ]
        for (id, target) in directions {
            let suite = "vRemote.direction-defaults.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let button = RemoteProfiles.chromecastButtons.first { $0.id == id }!
            let store = RemoteMappingStore(defaults: defaults)
            precondition(store.target(for: button, remote: .chromecast) == button.defaultTarget)
            precondition(store.target(for: button, remote: .chromecast, gesture: .longPress) == target)
            precondition(store.gestureConfiguration(for: button, remote: .chromecast).repeatsLongPress)
            store.setHoldRepeats(false, for: button, remote: .chromecast)
            precondition(store.gestureConfiguration(for: button, remote: .chromecast).repeatsLongPress)
            // Editing click later must not silently remove the seeded long action.
            store.setTarget(.switchApplications, for: button, remote: .chromecast)
            precondition(RemoteMappingStore(defaults: defaults).target(for: button, remote: .chromecast, gesture: .longPress) == target)

            let protectedKeys: [(String, Any)] = [
                ("remoteMapping.chromecast." + id, "arrowUp"),
                ("remoteMapping.chromecast." + id + ".doubleClick", "disabled"),
                ("remoteMapping.chromecast." + id + ".longPress", "disabled"),
                ("remoteCustomMapping.chromecast." + id, Data()),
                ("remoteApplicationMapping.chromecast." + id + ".longPress", Data()),
                ("remoteMappingHoldRepeat.chromecast." + id, false)
            ]
            for (key, value) in protectedKeys {
                defaults.removePersistentDomain(forName: suite)
                defaults.set(value, forKey: key)
                let migrated = RemoteMappingStore(defaults: defaults)
                precondition(migrated.target(for: button, remote: .chromecast, gesture: .longPress) == .disabled)
                precondition(defaults.object(forKey: key) != nil)
            }
        }
        let suite = "vRemote.new-targets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RemoteMappingStore(defaults: defaults)
        let button = RemoteProfiles.chromecastButtons.first { $0.id == "0E" }!
        for target in [RemoteMappingTarget.switchApplications] + directions.map({ $0.1 }) {
            let decoded = try JSONDecoder().decode(RemoteMappingTarget.self, from: JSONEncoder().encode(target))
            precondition(decoded == target)
            for gesture in RemoteButtonGesture.allCases {
                store.setTarget(target, for: button, remote: .chromecast, gesture: gesture)
                precondition(RemoteMappingStore(defaults: defaults).target(for: button, remote: .chromecast, gesture: gesture) == target)
            }
        }
        let applicationSwitch = RemoteMappingAction(target: .switchApplications, shortcut: nil, application: nil)
        precondition(applicationSwitch.isConfigured && !applicationSwitch.canRepeat && !applicationSwitch.isContinuous)
        print("PASS: four-direction defaults, legacy customization protection and new target persistence")
    }

}
