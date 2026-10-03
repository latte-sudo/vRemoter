import Foundation

@main
struct DockVisibilityTests {
    static func main() {
        let name = "vRemote.tests.dock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        precondition(!DockVisibilityPreference.isVisible(in: defaults), "upgrade preserves accessory mode")
        DockVisibilityPreference.setVisible(true, in: defaults)
        precondition(DockVisibilityPreference.isVisible(in: defaults))
        precondition(UserDefaults(suiteName: name)!.bool(forKey: DockVisibilityPreference.key), "persists across readers")
        DockVisibilityPreference.setVisible(false, in: defaults)
        precondition(!DockVisibilityPreference.isVisible(in: defaults))
        defaults.removeObject(forKey: DockVisibilityPreference.key)
        precondition(!DockVisibilityPreference.isVisible(in: defaults), "reset restores default")
        print("PASS: Dock preference migration, persistence, toggling, reset")
    }
}
