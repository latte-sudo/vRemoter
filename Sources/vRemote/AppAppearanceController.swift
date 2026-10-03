import AppKit

@MainActor
enum AppAppearanceController {
    static func apply(_ preference: AppAppearance) {
        // Windows, hosting views, sheets and popovers inherit the application appearance.
        // nil removes our override so macOS changes keep flowing through automatically.
        // Never write AppleInterfaceStyle or change the user's system appearance.
        switch preference {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
