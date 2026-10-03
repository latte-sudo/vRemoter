import AppKit
import SwiftUI

@main
struct AppAppearanceControllerTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        let original = app.appearance
        defer { app.appearance = original }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: Text("Appearance regression"))
        window.contentView = hosting
        for preference in [AppAppearance.dark, .light, .dark, .system, .light, .system] {
            AppAppearanceController.apply(preference)
            precondition(window.appearance == nil, "window must inherit application appearance")
            if preference == .system {
                precondition(app.appearance == nil, "system mode must remove the override, not capture today's appearance")
            } else {
                let expected: NSAppearance.Name = preference == .dark ? .darkAqua : .aqua
                precondition(app.appearance?.name == expected)
                precondition(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected)
                precondition(hosting.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected)
                let panel = NSPanel(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                precondition(panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected, "new panels inherit selection")
            }
        }
        print("PASS: repeated appearance changes, existing window/SwiftUI host, new panels and system override removal")
    }
}
