import AppKit
import CoreGraphics
import Combine
import Foundation

enum SupportedRemoteID: String, CaseIterable, Identifiable, Codable {
    case chromecast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chromecast: L10n.tr("support.remote.chromecast")
        }
    }

    var signature: String {
        switch self {
        case .chromecast: "18D1 · 9450"
        }
    }
}

struct RemoteButtonDefinition: Identifiable, Hashable {
    let id: String
    private let literalTitle: String
    private let titleKey: String?
    var title: String {
        guard let titleKey else { return literalTitle }
        return L10n.tr(titleKey)
    }
    let symbol: String
    let defaultTarget: RemoteMappingTarget
    let voiceControlled: Bool
    let remappable: Bool

    init(
        id: String,
        title: String = "",
        titleKey: String? = nil,
        symbol: String,
        defaultTarget: RemoteMappingTarget,
        voiceControlled: Bool = false,
        remappable: Bool = true
    ) {
        self.id = id
        self.literalTitle = title
        self.titleKey = titleKey
        self.symbol = symbol
        self.defaultTarget = defaultTarget
        self.voiceControlled = voiceControlled
        self.remappable = remappable
    }
}

enum RemoteProfiles {
    /// Only Chromecast has an actionable profile. Retired preference values
    /// remain on disk without a corresponding remote model or execution path.
    static let activeRemotes: [SupportedRemoteID] = [.chromecast]

    static var chromecastButtons: [RemoteButtonDefinition] { [
        .init(id: "03", titleKey: "support.button.up", symbol: "arrow.up", defaultTarget: .arrowUp),
        .init(id: "04", titleKey: "support.button.down", symbol: "arrow.down", defaultTarget: .arrowDown),
        .init(id: "05", titleKey: "support.button.left", symbol: "arrow.left", defaultTarget: .arrowLeft),
        .init(id: "06", titleKey: "support.button.right", symbol: "arrow.right", defaultTarget: .arrowRight),
        .init(id: "07", titleKey: "support.button.select", symbol: "circle.inset.filled", defaultTarget: .returnKey),
        .init(id: "0B", titleKey: "support.button.back", symbol: "chevron.backward", defaultTarget: .escape),
        .init(id: "0A", titleKey: "support.button.home", symbol: "house", defaultTarget: .showDesktop),
        .init(id: "0E", title: "YouTube", symbol: "play.rectangle", defaultTarget: .disabled),
        .init(id: "voice", titleKey: "support.button.voice", symbol: "mic", defaultTarget: .doubaoVoice, voiceControlled: true),
        .init(id: "08", titleKey: "support.button.mute", symbol: "speaker.slash", defaultTarget: .mute),
        .init(id: "0F", title: "Netflix", symbol: "n.square", defaultTarget: .disabled),
        .init(id: "01", titleKey: "support.button.power", symbol: "power", defaultTarget: .disabled),
        .init(id: "11", titleKey: "support.button.input", symbol: "rectangle.on.rectangle", defaultTarget: .disabled),
        .init(id: "0C", titleKey: "support.button.volumeUp", symbol: "speaker.plus", defaultTarget: .volumeUp),
        .init(id: "0D", titleKey: "support.button.volumeDown", symbol: "speaker.minus", defaultTarget: .volumeDown),
    ] }

    static func buttons(for remote: SupportedRemoteID) -> [RemoteButtonDefinition] {
        switch remote {
        case .chromecast: chromecastButtons
        }
    }
}

enum RemoteMappingTarget: String, CaseIterable, Identifiable, Codable, Hashable {
    case disabled
    case doubaoVoice
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case returnKey
    case escape
    case deleteBackward
    case tab
    case space
    case home
    case end
    case pageUp
    case pageDown
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case showDesktop
    case spotlight
    case switchApplications
    case scrollUp
    case scrollDown
    case scrollLeft
    case scrollRight
    case commandC
    case commandV
    case commandZ
    case custom
    case launchApplication

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: L10n.tr("support.action.disabled")
        case .doubaoVoice: L10n.tr("support.action.voice")
        case .arrowUp: L10n.tr("support.action.up")
        case .arrowDown: L10n.tr("support.action.down")
        case .arrowLeft: L10n.tr("support.action.left")
        case .arrowRight: L10n.tr("support.action.right")
        case .returnKey: L10n.tr("support.action.return")
        case .escape: L10n.tr("support.action.escape")
        case .deleteBackward: L10n.tr("support.action.delete")
        case .tab: L10n.tr("support.action.tab")
        case .space: L10n.tr("support.action.space")
        case .home: L10n.tr("support.action.home")
        case .end: L10n.tr("support.action.end")
        case .pageUp: L10n.tr("support.action.pageUp")
        case .pageDown: L10n.tr("support.action.pageDown")
        case .volumeUp: L10n.tr("support.action.volumeUp")
        case .volumeDown: L10n.tr("support.action.volumeDown")
        case .mute: L10n.tr("support.action.mute")
        case .playPause: L10n.tr("support.action.playPause")
        case .showDesktop: L10n.tr("support.action.showDesktop")
        case .spotlight: L10n.tr("support.action.spotlight")
        case .switchApplications: L10n.tr("support.action.switchApps")
        case .scrollUp: L10n.tr("support.action.scrollUp")
        case .scrollDown: L10n.tr("support.action.scrollDown")
        case .scrollLeft: L10n.tr("support.action.scrollLeft")
        case .scrollRight: L10n.tr("support.action.scrollRight")
        case .commandC: L10n.tr("support.action.copy")
        case .commandV: L10n.tr("support.action.paste")
        case .commandZ: L10n.tr("support.action.undo")
        case .custom: L10n.tr("support.action.custom")
        case .launchApplication: L10n.tr("support.action.openApp")
        }
    }

    var keyboard: (keyCode: CGKeyCode, flags: CGEventFlags)? {
        switch self {
        case .arrowUp: (0x7E, [])
        case .arrowDown: (0x7D, [])
        case .arrowLeft: (0x7B, [])
        case .arrowRight: (0x7C, [])
        case .returnKey: (0x24, [])
        case .escape: (0x35, [])
        case .deleteBackward: (0x33, [])
        case .tab: (0x30, [])
        case .space: (0x31, [])
        case .home: (0x73, [])
        case .end: (0x77, [])
        case .pageUp: (0x74, [])
        case .pageDown: (0x79, [])
        case .showDesktop: (0x67, [.maskSecondaryFn])
        case .spotlight: (0x31, [.maskCommand])
        case .commandC: (0x08, [.maskCommand])
        case .commandV: (0x09, [.maskCommand])
        case .commandZ: (0x06, [.maskCommand])
        default: nil
        }
    }

    var mediaKey: Int32? {
        switch self {
        case .volumeUp: 0
        case .volumeDown: 1
        case .mute: 7
        case .playPause: 16
        default: nil
        }
    }

    func post(isDown: Bool, isRepeat: Bool = false) {
        guard self != .disabled, self != .doubaoVoice else { return }
        if self == .switchApplications {
            // A complete shortcut per gesture: never leave Command held for
            // the remote's physical hold, and never repeat app switches.
            guard isDown, !isRepeat else { return }
            for event in Self.applicationSwitchEvents() { event.post(tap: .cghidEventTap) }
        } else if scrollDelta != nil {
            guard isDown else { return }
            scrollEvent()?.post(tap: .cghidEventTap)
        } else if let keyboard {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyboard.keyCode,
                keyDown: isDown
            ) else { return }
            event.flags = keyboard.flags
            event.setIntegerValueField(.keyboardEventAutorepeat, value: isRepeat ? 1 : 0)
            event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
            event.post(tap: .cghidEventTap)
        } else if let mediaKey, isDown {
            postMediaKey(mediaKey)
        }
    }

    /// Build the entire balanced sequence before posting any part. If event
    /// allocation fails, no modifier is pressed. Exposed for non-posting tests.
    static func applicationSwitchEvents() -> [CGEvent] {
        let source = CGEventSource(stateID: .hidSystemState)
        let strokes: [(CGKeyCode, Bool, CGEventFlags)] = [
            (0x37, true, .maskCommand),
            (0x30, true, .maskCommand),
            (0x30, false, .maskCommand),
            (0x37, false, [])
        ]
        var events = [CGEvent]()
        for (keyCode, isDown, flags) in strokes {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { return [] }
            event.flags = flags
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
            event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
            events.append(event)
        }
        return events
    }

    /// Positive deltas move the viewport up/left; use wheel 2 for horizontal.
    var scrollDelta: (vertical: Int32, horizontal: Int32)? {
        switch self {
        case .scrollUp: (20, 0)
        case .scrollDown: (-20, 0)
        case .scrollLeft: (0, 20)
        case .scrollRight: (0, -20)
        default: nil
        }
    }

    func scrollEvent() -> CGEvent? {
        guard let delta = scrollDelta else { return nil }
        let event = CGEvent(scrollWheelEvent2Source: CGEventSource(stateID: .hidSystemState),
                            units: .pixel, wheelCount: 2, wheel1: delta.vertical, wheel2: delta.horizontal, wheel3: 0)
        event?.flags = []
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event?.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
        return event
    }

    private func postMediaKey(_ key: Int32) {
        func post(state: Int32) {
            let data1 = Int((key << 16) | (state << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent else { return }
            event.post(tap: .cghidEventTap)
        }
        post(state: 0xA)
        post(state: 0xB)
    }
}

struct RemoteCustomShortcut: Codable, Hashable {
    let keyCode: UInt16
    let flags: UInt64
    let label: String

    /// Localize display-only names without changing saved shortcuts or their
    /// physical key codes. Letter labels preserve the captured keyboard layout.
    var displayLabel: String {
        let modifiers = CGEventFlags(rawValue: flags)
        var prefix = ""
        if modifiers.contains(.maskControl) { prefix += "⌃" }
        if modifiers.contains(.maskAlternate) { prefix += "⌥" }
        if modifiers.contains(.maskShift) { prefix += "⇧" }
        if modifiers.contains(.maskCommand) { prefix += "⌘" }
        let special: [UInt16: RemoteMappingTarget] = [
            0x24: .returnKey, 0x30: .tab, 0x31: .space, 0x33: .deleteBackward,
            0x35: .escape, 0x73: .home, 0x77: .end, 0x74: .pageUp, 0x79: .pageDown
        ]
        if let target = special[keyCode] { return prefix + target.title }
        let symbols: [UInt16: String] = [
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12"
        ]
        if let symbol = symbols[keyCode] { return prefix + symbol }
        let capturedKey = String(label.drop(while: { "⌃⌥⇧⌘".contains($0) }))
        if capturedKey.isEmpty || capturedKey.hasPrefix("Key 0x") {
            return prefix + L10n.tr("support.shortcut.unknownKey", String(format: "0x%02X", keyCode))
        }
        return prefix + capturedKey
    }

    func post(isDown: Bool, isRepeat: Bool = false) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(keyCode),
            keyDown: isDown
        ) else { return }
        event.flags = CGEventFlags(rawValue: flags)
        event.setIntegerValueField(.keyboardEventAutorepeat, value: isRepeat ? 1 : 0)
        event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}

extension RemoteButtonGesture {
    var title: String {
        switch self {
        case .click: L10n.tr("support.gesture.click")
        case .doubleClick: L10n.tr("support.gesture.doubleClick")
        case .longPress: L10n.tr("support.gesture.longPress")
        }
    }
}

extension RemoteApplicationShortcut {
    init?(url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url) else { return nil }
        self.init(
            bundleIdentifier: bundle.bundleIdentifier,
            path: url.standardizedFileURL.path,
            name: (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
        )
    }

    var resolvedURL: URL? {
        let savedURL = URL(fileURLWithPath: path, isDirectory: true)
        if savedURL.pathExtension.lowercased() == "app",
           let bundle = Bundle(url: savedURL),
           bundleIdentifier == nil || bundle.bundleIdentifier == bundleIdentifier {
            return savedURL
        }
        // Launch Services also finds apps moved after the mapping was saved.
        if let bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }
        return nil
    }
}

enum RemoteMappingActionError {
    case applicationMissing, applicationLaunchFailed

    var message: String {
        switch self {
        case .applicationMissing: L10n.tr("support.mapping.appMissing")
        case .applicationLaunchFailed: L10n.tr("support.mapping.appLaunchFailed")
        }
    }
}

/// An immutable press-time snapshot prevents editing a mapping mid-hold from
/// releasing a different key than the one that was originally pressed.
struct RemoteMappingAction {
    let target: RemoteMappingTarget
    let shortcut: RemoteCustomShortcut?
    let application: RemoteApplicationShortcut?

    var isConfigured: Bool {
        switch target {
        case .disabled, .doubaoVoice: false
        case .custom: shortcut != nil
        case .launchApplication: application != nil
        default: true
        }
    }

    var isContinuous: Bool { target.scrollDelta != nil }

    var canRepeat: Bool {
        isContinuous || target.keyboard != nil || target.mediaKey != nil || (target == .custom && shortcut != nil)
    }

    var title: String {
        if target == .custom, let shortcut { return shortcut.displayLabel }
        if target == .launchApplication, let application { return application.name }
        return target.title
    }

    func post(isDown: Bool, isRepeat: Bool = false, onError: @escaping (RemoteMappingActionError) -> Void = { _ in }) {
        if target == .custom {
            shortcut?.post(isDown: isDown, isRepeat: isRepeat)
        } else if target == .launchApplication {
            guard isDown, !isRepeat else { return }
            guard let application, let url = application.resolvedURL else {
                onError(.applicationMissing)
                return
            }
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    DispatchQueue.main.async {
                        print("[CAST-MAP] Could not open application: \(error.localizedDescription)")
                        onError(.applicationLaunchFailed)
                    }
                }
            }
        } else {
            target.post(isDown: isDown, isRepeat: isRepeat)
        }
    }
}

final class RemoteMappingStore: ObservableObject {
    static let shared = RemoteMappingStore()
    static let didChangeNotification = Notification.Name("vRemote.remoteMappingDidChange")

    @Published private(set) var revision = 0
    @Published private var lastActionFailure: RemoteMappingActionError?
    var lastActionError: String? { lastActionFailure?.message }
    private let defaults: UserDefaults
    private let prefix = "remoteMapping."
    private let enabledPrefix = "remoteMappingEnabled."
    private let customPrefix = "remoteCustomMapping."
    private let applicationPrefix = "remoteApplicationMapping."
    private let repeatPrefix = "remoteMappingHoldRepeat."

    // Injectable defaults make migration/reset behavior independently testable.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installUncustomizedDirectionDefaults()
    }

    /// Seed only untouched direction buttons. Any existing per-gesture action,
    /// payload or repeat preference is a customization, including Disabled.
    /// Storing the default makes later edits and archive round trips stable.
    private func installUncustomizedDirectionDefaults() {
        let targets: [String: RemoteMappingTarget] = [
            "03": .scrollUp, "04": .scrollDown, "05": .scrollLeft, "06": .scrollRight
        ]
        for button in RemoteProfiles.chromecastButtons {
            guard let target = targets[button.id] else { continue }
            var keys = RemoteButtonGesture.allCases.flatMap { gesture in
                [prefix, customPrefix, applicationPrefix].map {
                    key($0, button: button, remote: .chromecast, gesture: gesture)
                }
            }
            keys.append(repeatPrefix + "chromecast." + button.id)
            guard keys.allSatisfy({ defaults.object(forKey: $0) == nil }) else { continue }
            defaults.set(target.rawValue,
                         forKey: key(prefix, button: button, remote: .chromecast, gesture: .longPress))
        }
    }

    /// Import/undo changes UserDefaults directly; notify active gestures too.
    func reload() {
        installUncustomizedDirectionDefaults()
        changed()
    }

    private func changed() {
        revision += 1
        lastActionFailure = nil
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func key(_ prefix: String, button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture) -> String {
        // Keep the exact legacy click key so existing custom mappings survive.
        let suffix = gesture == .click ? "" : "." + gesture.rawValue
        return prefix + remote.rawValue + "." + button.id + suffix
    }

    func isEnabled(_ remote: SupportedRemoteID) -> Bool {
        defaults.bool(forKey: enabledPrefix + remote.rawValue)
    }

    func setEnabled(_ enabled: Bool, for remote: SupportedRemoteID) {
        defaults.set(enabled, forKey: enabledPrefix + remote.rawValue)
        changed()
    }

    func target(for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) -> RemoteMappingTarget {
        guard !button.voiceControlled else { return gesture == .click ? .doubaoVoice : .disabled }
        guard button.remappable else { return .disabled }
        guard let raw = defaults.string(forKey: key(prefix, button: button, remote: remote, gesture: gesture)),
              let target = RemoteMappingTarget(rawValue: raw), target != .doubaoVoice
        else { return gesture == .click ? button.defaultTarget : .disabled }
        return target
    }

    func setTarget(_ target: RemoteMappingTarget, for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) {
        guard !button.voiceControlled, button.remappable, target != .doubaoVoice else { return }
        defaults.set(target.rawValue, forKey: key(prefix, button: button, remote: remote, gesture: gesture))
        changed()
    }

    func customShortcut(for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) -> RemoteCustomShortcut? {
        guard !button.voiceControlled, button.remappable,
              let data = defaults.data(forKey: key(customPrefix, button: button, remote: remote, gesture: gesture)) else { return nil }
        return try? JSONDecoder().decode(RemoteCustomShortcut.self, from: data)
    }

    func setCustomShortcut(_ shortcut: RemoteCustomShortcut, for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) {
        guard !button.voiceControlled, button.remappable,
              let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key(customPrefix, button: button, remote: remote, gesture: gesture))
        setTarget(.custom, for: button, remote: remote, gesture: gesture)
    }

    func application(for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) -> RemoteApplicationShortcut? {
        guard !button.voiceControlled, button.remappable,
              let data = defaults.data(forKey: key(applicationPrefix, button: button, remote: remote, gesture: gesture)) else { return nil }
        return try? JSONDecoder().decode(RemoteApplicationShortcut.self, from: data)
    }

    func setApplication(_ application: RemoteApplicationShortcut, for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) {
        guard !button.voiceControlled, button.remappable,
              let data = try? JSONEncoder().encode(application) else { return }
        defaults.set(data, forKey: key(applicationPrefix, button: button, remote: remote, gesture: gesture))
        setTarget(.launchApplication, for: button, remote: remote, gesture: gesture)
    }

    func action(for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) -> RemoteMappingAction {
        RemoteMappingAction(
            target: target(for: button, remote: remote, gesture: gesture),
            shortcut: customShortcut(for: button, remote: remote, gesture: gesture),
            application: application(for: button, remote: remote, gesture: gesture)
        )
    }

    func targetTitle(for button: RemoteButtonDefinition, remote: SupportedRemoteID, gesture: RemoteButtonGesture = .click) -> String {
        action(for: button, remote: remote, gesture: gesture).title
    }

    /// The stored preference is preserved while advanced gestures suspend it.
    func holdRepeats(for button: RemoteButtonDefinition, remote: SupportedRemoteID) -> Bool {
        guard !button.voiceControlled, button.remappable else { return false }
        let repeatKey = repeatPrefix + remote.rawValue + "." + button.id
        if defaults.object(forKey: repeatKey) != nil { return defaults.bool(forKey: repeatKey) }
        return [.arrowUp, .arrowDown, .arrowLeft, .arrowRight, .volumeUp, .volumeDown].contains(button.defaultTarget)
    }

    func setHoldRepeats(_ enabled: Bool, for button: RemoteButtonDefinition, remote: SupportedRemoteID) {
        guard !button.voiceControlled, button.remappable else { return }
        defaults.set(enabled, forKey: repeatPrefix + remote.rawValue + "." + button.id)
        changed()
    }

    func gestureConfiguration(for button: RemoteButtonDefinition, remote: SupportedRemoteID) -> RemoteGestureConfiguration {
        RemoteGestureConfiguration(
            hasDoubleClick: action(for: button, remote: remote, gesture: .doubleClick).isConfigured,
            hasLongPress: action(for: button, remote: remote, gesture: .longPress).isConfigured,
            repeatsWhileHeld: action(for: button, remote: remote).isContinuous ||
                (holdRepeats(for: button, remote: remote) && action(for: button, remote: remote).canRepeat),
            repeatsLongPress: action(for: button, remote: remote, gesture: .longPress).isContinuous
        )
    }

    func repeatConflictDescription(for button: RemoteButtonDefinition, remote: SupportedRemoteID) -> String? {
        let configuration = gestureConfiguration(for: button, remote: remote)
        guard holdRepeats(for: button, remote: remote),
              configuration.hasDoubleClick || configuration.hasLongPress else { return nil }
        return L10n.tr("support.mapping.repeatConflict")
    }

    func post(action: RemoteMappingAction, isDown: Bool, isRepeat: Bool = false) {
        if isDown, !isRepeat { lastActionFailure = nil }
        action.post(isDown: isDown, isRepeat: isRepeat) { [weak self] error in
            self?.lastActionFailure = error
            print("[CAST-MAP] " + error.message)
        }
    }

    func post(button: RemoteButtonDefinition, remote: SupportedRemoteID, isDown: Bool, gesture: RemoteButtonGesture = .click) {
        post(action: action(for: button, remote: remote, gesture: gesture), isDown: isDown)
    }

    func reset(_ remote: SupportedRemoteID) {
        for button in RemoteProfiles.buttons(for: remote) {
            for gesture in RemoteButtonGesture.allCases {
                for storagePrefix in [prefix, customPrefix, applicationPrefix] {
                    defaults.removeObject(forKey: key(storagePrefix, button: button, remote: remote, gesture: gesture))
                }
            }
            defaults.removeObject(forKey: repeatPrefix + remote.rawValue + "." + button.id)
        }
        installUncustomizedDirectionDefaults()
        changed()
    }
}
