import ApplicationServices
import CoreGraphics
import Foundation

/// Observes the configured physical keyboard trigger for Chromecast voice.
/// The tap is listen-only: it never suppresses or remaps unrelated input.
final class KeyboardTriggerObserver {
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var triggerState = KeyboardTriggerState()
    private(set) var isAvailable = false
    var onTriggerDownObserved: ((Bool) -> Void)?
    var onTriggerUpObserved: ((Bool) -> Void)?

    func start() {
        stop()
        guard AXIsProcessTrusted() else {
            print("[INPUT-TRIGGER] accessibility permission unavailable")
            return
        }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let observer = Unmanaged<KeyboardTriggerObserver>
                .fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = observer.tapPort { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            observer.observeTriggerEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[INPUT-TRIGGER] unable to create event tap")
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            print("[INPUT-TRIGGER] unable to create run-loop source")
            return
        }
        tapPort = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isAvailable = true
        print("[INPUT-TRIGGER] keyboard observation ready")
    }

    func triggerConfigurationDidChange() {
        triggerState.reset()
        print("[INPUT-TRIGGER] listening for \(AppStorage.inputTriggerKey.title)")
    }

    func stop() {
        isAvailable = false
        triggerState.reset()
        if let tapPort {
            CGEvent.tapEnable(tap: tapPort, enable: false)
            CFMachPortInvalidate(tapPort)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tapPort = nil
    }

    deinit { stop() }

    private func observeTriggerEvent(type: CGEventType, event: CGEvent) {
        let kind: KeyboardTriggerState.EventKind
        switch type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        default: return
        }
        let trigger = AppStorage.inputTriggerKey
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isSynthetic = event.getIntegerValueField(.eventSourceUserData) == Key.syntheticMarker
        guard let edge = triggerState.observe(
            kind: kind,
            keyCode: keyCode,
            triggerKeyCodes: trigger.keyCodes,
            triggerFlagIsSet: event.flags.contains(trigger.flag),
            isSynthetic: isSynthetic
        ) else { return }
        print("[INPUT-TRIGGER] keyCode=0x\(String(keyCode, radix: 16)) edge=\(edge)")
        switch edge {
        case .down: onTriggerDownObserved?(false)
        case .up: onTriggerUpObserved?(false)
        }
    }
}
