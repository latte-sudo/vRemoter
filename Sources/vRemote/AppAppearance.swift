import Foundation

/// Stable archive values; absent or invalid preferences follow macOS automatically.
enum AppAppearance: String, CaseIterable {
    case system, light, dark

    static let key = "vRemoter.appAppearance"

    /// Resolve only for presentation. Keep `.system` stored so later OS changes apply.
    func resolved(isSystemDark: Bool) -> AppAppearance {
        self == .system ? (isSystemDark ? .dark : .light) : self
    }

    static func selected(in defaults: UserDefaults = .standard) -> AppAppearance {
        guard let raw = defaults.string(forKey: key), let value = AppAppearance(rawValue: raw) else {
            return .system
        }
        return value
    }

    static func set(_ value: AppAppearance, in defaults: UserDefaults = .standard) {
        defaults.set(value.rawValue, forKey: key)
    }
}
