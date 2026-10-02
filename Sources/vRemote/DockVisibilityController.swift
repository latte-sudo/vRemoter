import AppKit

@MainActor
enum DockVisibilityController {
    @discardableResult
    static func apply(_ visible: Bool) -> Bool {
        // Changing policy must not close the console or remove the status item.
        let focusedWindow = NSApp.keyWindow
        let wasActive = NSApp.isActive
        NSApp.applicationIconImage = LogoAsset.image
        guard NSApp.setActivationPolicy(visible ? .regular : .accessory) else { return false }
        if wasActive, let window = focusedWindow, window.isVisible {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
