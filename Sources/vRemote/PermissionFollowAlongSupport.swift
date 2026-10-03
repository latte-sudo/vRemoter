import Foundation

/// A short-lived, user-started guide. Observation never requests authorization.
struct PermissionFollowAlongSession {
    enum Presentation: Equatable { case hidden, following, ended }
    private(set) var permission: RequestablePermission?
    private(set) var hasFollowed = false
    private var startedAt: TimeInterval = 0
    // This is only a launch/prompt grace period, not a recurring background task.
    static let openingGracePeriod: TimeInterval = 60

    mutating func begin(_ permission: RequestablePermission, now: TimeInterval) {
        self.permission = permission
        hasFollowed = false
        startedAt = now
    }

    mutating func end() {
        permission = nil
        hasFollowed = false
    }

    mutating func observe(
        granted: Bool, settingsFrontmost: Bool, settingsWindowAvailable: Bool,
        now: TimeInterval
    ) -> Presentation {
        guard permission != nil else { return .ended }
        if granted || (hasFollowed && (!settingsFrontmost || !settingsWindowAvailable))
            || (!hasFollowed && now - startedAt >= Self.openingGracePeriod) {
            end()
            return .ended
        }
        guard settingsFrontmost, settingsWindowAvailable else { return .hidden }
        hasFollowed = true
        return .following
    }
}

enum PermissionFollowAlongLayout {
    /// Quartz uses the main display's top-left as origin; AppKit uses its bottom-left.
    /// Do not flip against the current monitor: that fails on vertically stacked displays.
    static func appKitBounds(_ bounds: CGRect, desktopTop: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: desktopTop - bounds.maxY,
               width: bounds.width, height: bounds.height)
    }

    static func panelFrame(size: CGSize, settings: CGRect, visibleScreens: [CGRect]) -> CGRect? {
        guard let screen = visibleScreens.max(by: {
            intersectionArea($0, settings) < intersectionArea($1, settings)
        }), intersectionArea(screen, settings) > 0 else { return nil }
        let safe = screen.insetBy(dx: 12, dy: 12)
        guard size.width > 0, size.height > 0,
              size.width <= safe.width, size.height <= safe.height else { return nil }
        let gap: CGFloat = 12
        let candidates = [
            CGRect(x: settings.maxX + gap, y: settings.midY - size.height / 2, width: size.width, height: size.height),
            CGRect(x: settings.minX - gap - size.width, y: settings.midY - size.height / 2, width: size.width, height: size.height),
            CGRect(x: settings.midX - size.width / 2, y: settings.minY - gap - size.height, width: size.width, height: size.height),
            CGRect(x: settings.midX - size.width / 2, y: settings.maxY + gap, width: size.width, height: size.height)
        ].map { frame in
            CGRect(x: min(max(frame.minX, safe.minX), safe.maxX - size.width),
                   y: min(max(frame.minY, safe.minY), safe.maxY - size.height),
                   width: size.width, height: size.height)
        }
        // Prefer an adjacent edge, minimizing overlap when the screen is cramped.
        return candidates.enumerated().min {
            let lhs = intersectionArea($0.element, settings)
            let rhs = intersectionArea($1.element, settings)
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }?.element
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
