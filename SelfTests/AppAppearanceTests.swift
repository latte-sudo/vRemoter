import Foundation

@main
struct AppAppearanceTests {
    static func main() {
        let name = "vRemote.tests.appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        precondition(AppAppearance.selected(in: defaults) == .system, "new installs and upgrades follow system")
        for value in AppAppearance.allCases {
            AppAppearance.set(value, in: defaults)
            precondition(AppAppearance.selected(in: defaults) == value)
            precondition(AppAppearance.selected(in: UserDefaults(suiteName: name)!) == value, "persists across readers")
            precondition(defaults.string(forKey: AppAppearance.key) == value.rawValue)
        }
        let invalidValues: [Any] = ["unknown", "", 42, Data()]
        for invalid in invalidValues {
            defaults.set(invalid, forKey: AppAppearance.key)
            precondition(AppAppearance.selected(in: defaults) == .system, "invalid preferences recover safely")
        }
        AppAppearance.set(.dark, in: defaults)
        defaults.removeObject(forKey: AppAppearance.key)
        precondition(AppAppearance.selected(in: defaults) == .system, "reset removes override")
        print("PASS: appearance default, upgrade, persistence, all modes, invalid values and reset")
    }
}
