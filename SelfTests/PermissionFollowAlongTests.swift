import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@main
struct PermissionFollowAlongTests {
    static func main() {
        for permission in RequestablePermission.allCases {
            var guide = PermissionFollowAlongSession()
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 0) == .ended,
                         "ordinary observations must never start a guide")
            guide.begin(permission, now: 100)
            precondition(guide.permission == permission)
            precondition(guide.observe(granted: false, settingsFrontmost: false, settingsWindowAvailable: false, now: 101) == .hidden,
                         "Settings launches asynchronously; no missing-window false close")
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 102) == .following)
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1000) == .following,
                         "opening grace period must not time out an active user")
            precondition(guide.observe(granted: true, settingsFrontmost: true, settingsWindowAvailable: true, now: 1001) == .ended)
            precondition(guide.permission == nil)
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1002) == .ended,
                         "revocation must not restart an old guide")
            for reason in ["close", "cancel", "skip", "navigation", "app quit"] {
                guide.begin(permission, now: 0)
                guide.end()
                precondition(guide.permission == nil, "\(reason) must release the session")
                precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1) == .ended)
            }
            guide.begin(permission, now: 0)
            _ = guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1)
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: false, now: 2) == .ended,
                         "closing or minimizing the observed Settings window ends the guide")
            guide.begin(permission, now: 0)
            _ = guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1)
            precondition(guide.observe(granted: false, settingsFrontmost: false, settingsWindowAvailable: false, now: 2) == .ended,
                         "switching away ends the guide; no background reappearance")
            guide.begin(permission, now: 0)
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: false, now: 59) == .hidden)
            precondition(guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: false, now: 60) == .ended,
                         "failed launches/unavailable metadata must not leave a polling loop")
        }
        var guide = PermissionFollowAlongSession()
        guide.begin(.accessibility, now: 0)
        _ = guide.observe(granted: false, settingsFrontmost: true, settingsWindowAvailable: true, now: 1)
        guide.begin(.bluetooth, now: 2)
        precondition(guide.permission == .bluetooth && !guide.hasFollowed,
                     "replacing/repeating a request resets its lifecycle")
        precondition(guide.observe(granted: false, settingsFrontmost: false, settingsWindowAvailable: false, now: 3) == .hidden)

        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900),
                       CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                       CGRect(x: 0, y: 900, width: 1280, height: 800),
                       CGRect(x: 0, y: -1080, width: 1920, height: 1080)]
        let size = CGSize(width: 360, height: 300)
        for screen in screens {
            let settings = CGRect(x: screen.minX + 300, y: screen.minY + 100, width: 670, height: 600)
            let quartz = CGRect(x: settings.minX, y: 900 - settings.maxY, width: settings.width, height: settings.height)
            precondition(PermissionFollowAlongLayout.appKitBounds(quartz, desktopTop: 900) == settings)
            let frame = PermissionFollowAlongLayout.panelFrame(size: size, settings: settings, visibleScreens: screens)!
            precondition(screen.insetBy(dx: 12, dy: 12).contains(frame), "guide must stay on the target display")
        }
        let tight = CGRect(x: 0, y: 0, width: 800, height: 600)
        let tightFrame = PermissionFollowAlongLayout.panelFrame(size: size, settings: tight, visibleScreens: [tight])!
        precondition(tight.insetBy(dx: 12, dy: 12).contains(tightFrame), "constrained placement must keep dismissal reachable")
        precondition(PermissionFollowAlongLayout.panelFrame(size: size, settings: .zero, visibleScreens: screens) == nil)
        precondition(PermissionFollowAlongLayout.panelFrame(size: size, settings: tight, visibleScreens: []) == nil)
        precondition(PermissionFollowAlongLayout.panelFrame(size: CGSize(width: 9999, height: 100), settings: tight, visibleScreens: [tight]) == nil)
        let roomy = CGRect(x: 0, y: 0, width: 2400, height: 1200)
        let settings = CGRect(x: 700, y: 200, width: 700, height: 750)
        precondition(!PermissionFollowAlongLayout.panelFrame(size: size, settings: settings, visibleScreens: [roomy])!.intersects(settings),
                     "use available adjacent room before covering any Settings content")
        print("PASS: permission guide lifecycle, replacement, dismissal, grant, timeout and multi-display geometry")
    }
}
