// Follow-along concept adapted from maka-agent/maka-cu (MIT).
// Copyright (c) 2026 Leo; Copyright (c) 2026 The Maka Authors.
// See THIRD_PARTY_NOTICES.md and docs/PERMISSION_REQUESTS.md for provenance.
import AppKit
import CoreGraphics
import SwiftUI

/// Geometry-only assistance. No screenshots, window titles, AX traversal,
/// input monitoring, event injection, or system-setting mutation is used here.
@MainActor
final class PermissionFollowAlongController {
    private let authorization: (RequestablePermission) -> PermissionAuthorization
    private let onEnd: () -> Void
    private var session = PermissionFollowAlongSession()
    private var panel: NSPanel?
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var terminationObserver: NSObjectProtocol?
    private var generation = 0

    init(authorization: @escaping (RequestablePermission) -> PermissionAuthorization,
         onEnd: @escaping () -> Void) {
        self.authorization = authorization
        self.onEnd = onEnd
    }

    /// Only call from Request Permission or Open Settings, never from a refresh.
    @discardableResult
    func begin(_ permission: RequestablePermission) -> Bool {
        stop()
        guard authorization(permission) != .authorized else { return false }
        session.begin(permission, now: ProcessInfo.processInfo.systemUptime)
        let currentGeneration = generation
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.titled, .closable, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = L10n.tr("permission.follow.title")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.level = .floating
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: PermissionFollowAlongView(permission: permission) { [weak self] in
            self?.stop()
        })
        // Close always works; Escape works when the user gives this panel focus.
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.generation == currentGeneration else { return }
                self?.stop()
            }
        }
        self.closeObserver = closeObserver
        self.panel = panel
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let terminatedSettings = notification.name == NSWorkspace.didTerminateApplicationNotification
                    && (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                        .bundleIdentifier == "com.apple.systempreferences"
                Task { @MainActor [weak self] in
                    guard self?.generation == currentGeneration else { return }
                    if terminatedSettings { self?.stop() }
                    else { self?.tick(ifGeneration: currentGeneration) }
                }
            })
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.generation == currentGeneration else { return }
                self?.stop()
            }
        }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick(ifGeneration: currentGeneration) }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick(ifGeneration: currentGeneration)
        return session.permission != nil
    }

    private var closeObserver: NSObjectProtocol?

    func stop() {
        generation += 1 // Ignore already-enqueued callbacks from a replaced guide.
        session.end()
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        terminationObserver = nil
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        panel?.orderOut(nil)
        panel = nil
        onEnd()
    }

    private func tick(ifGeneration expected: Int) {
        guard expected == generation, let permission = session.permission, let panel else { return }
        let settings = NSWorkspace.shared.frontmostApplication
        let frontmost = settings?.bundleIdentifier == "com.apple.systempreferences"
        // Avoid querying any window metadata at all while Settings is not frontmost.
        let context = frontmost ? settingsWindow(pid: settings!.processIdentifier) : nil
        let state = session.observe(granted: authorization(permission) == .authorized,
                                    settingsFrontmost: frontmost,
                                    settingsWindowAvailable: context != nil,
                                    now: ProcessInfo.processInfo.systemUptime)
        switch state {
        case .ended: stop()
        case .hidden: panel.orderOut(nil)
        case .following:
            guard let context, let content = panel.contentView else { return }
            panel.title = L10n.tr("permission.follow.title")
            content.layoutSubtreeIfNeeded()
            let contentSize = content.fittingSize
            let windowSize = panel.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
            guard let frame = PermissionFollowAlongLayout.panelFrame(
                size: windowSize, settings: context.bounds,
                visibleScreens: NSScreen.screens.map(\.visibleFrame)
            ) else { panel.orderOut(nil); return }
            panel.setFrame(frame, display: true)
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
    }

    private struct SettingsWindow { let bounds: CGRect }

    private func settingsWindow(pid: pid_t) -> SettingsWindow? {
        guard let desktopTop = NSScreen.screens.first?.frame.maxY,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        // Only retain the target process's ordinary window geometry. Never read names.
        return windows.compactMap { info -> SettingsWindow? in
            guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let raw = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  bounds.width >= 400, bounds.height >= 300 else { return nil }
            return SettingsWindow(bounds: PermissionFollowAlongLayout.appKitBounds(bounds, desktopTop: desktopTop))
        }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }
}

private struct PermissionFollowAlongView: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let permission: RequestablePermission
    let onDismiss: () -> Void

    private var title: String {
        switch permission {
        case .accessibility: return L10n.tr("console.permission.accessibility")
        case .inputMonitoring: return L10n.tr("console.permission.inputMonitoring")
        case .bluetooth: return L10n.tr("console.permission.bluetooth")
        }
    }

    private var appIdentity: String {
        // TCC can use the OS-localized bundle name even when our in-app language differs.
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? L10n.tr("shell.window.title")
        let filename = Bundle.main.bundleURL.pathExtension == "app"
            ? Bundle.main.bundleURL.lastPathComponent : "vRemote.app"
        return "\(name) (\(filename))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "hand.point.up.left").font(.headline)
            Text(L10n.tr(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13
                         ? "permission.follow.path.modern" : "permission.follow.path.monterey", title))
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text(L10n.tr("permission.follow.enable", appIdentity))
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text(L10n.tr("permission.follow.manual"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L10n.tr("permission.follow.dismiss"), action: onDismiss)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16).frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, AppLanguage.selected.locale)
    }
}
