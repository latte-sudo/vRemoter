import Foundation

/// Missing preferences preserve the original menu-bar-only behavior.
enum DockVisibilityPreference {
    static let key = "chromecast.showDockIcon"
    static func isVisible(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }
    static func setVisible(_ visible: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(visible, forKey: key)
    }
}

