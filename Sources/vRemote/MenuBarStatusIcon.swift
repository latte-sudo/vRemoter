import AppKit

/// Keep the existing brand icon and add a real-color receipt indicator.
enum MenuBarStatusIcon {
    static func image(receivingVoice: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            LogoAsset.image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            if receivingVoice {
                NSColor.windowBackgroundColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: 14, y: 0, width: 8, height: 8)).fill()
                NSColor.systemGreen.setFill()
                NSBezierPath(ovalIn: NSRect(x: 15, y: 1, width: 6, height: 6)).fill()
            }
            return true
        }
        // A template image would tint the green dot to the menu's text color.
        image.isTemplate = false
        return image
    }
}
