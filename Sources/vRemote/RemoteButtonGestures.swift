import Foundation

/// Voice input deliberately uses its separate ATVV state machine.
enum RemoteButtonGesture: String, CaseIterable, Identifiable, Codable, Hashable {
    case click
    case doubleClick
    case longPress

    var id: String { rawValue }
}

struct RemoteGestureConfiguration: Equatable {
    var hasDoubleClick = false
    var hasLongPress = false
    var repeatsWhileHeld = false
    var doubleClickInterval: TimeInterval = 0.30
    var longPressInterval: TimeInterval = 0.55
    var repeatDelay: TimeInterval = 0.45
    var repeatInterval: TimeInterval = 0.07

    // Repeating and deferred gestures cannot both own the same held button.
    var effectiveHoldRepeat: Bool {
        repeatsWhileHeld && !hasDoubleClick && !hasLongPress
    }
}

enum RemoteGestureEvent: Equatable {
    /// The ordinary mapping can be held when no deferred gestures are configured.
    case keyDown
    case keyUp
    case repeatKeyDown
    /// Deferred gestures produce one balanced down/up pair, or one app launch.
    case trigger(RemoteButtonGesture)
}

/// A deterministic, clock-injected recognizer. It has no timers or macOS APIs,
/// so both boundary behavior and interrupted sequences can be tested offline.
struct RemoteButtonGestureRecognizer {
    let configuration: RemoteGestureConfiguration
    private(set) var isPressed = false
    private var pressedAt: TimeInterval?
    private var pendingClickDeadline: TimeInterval?
    private var nextRepeatAt: TimeInterval?
    private var isSecondClick = false
    private var longPressFired = false
    private var keyIsDown = false

    init(configuration: RemoteGestureConfiguration) {
        self.configuration = configuration
    }

    var isIdle: Bool { !isPressed && pendingClickDeadline == nil }

    var nextDeadline: TimeInterval? {
        var deadlines = [TimeInterval]()
        if let pendingClickDeadline { deadlines.append(pendingClickDeadline) }
        if let nextRepeatAt { deadlines.append(nextRepeatAt) }
        if let pressedAt, configuration.hasLongPress, !longPressFired {
            deadlines.append(pressedAt + configuration.longPressInterval)
        }
        return deadlines.min()
    }

    mutating func press(at time: TimeInterval) -> [RemoteGestureEvent] {
        guard !isPressed else { return [] } // Ignore duplicate HID down reports.
        var events = advance(to: time)
        isPressed = true
        pressedAt = time
        longPressFired = false
        isSecondClick = pendingClickDeadline != nil
        pendingClickDeadline = nil

        if !configuration.hasDoubleClick && !configuration.hasLongPress {
            keyIsDown = true
            events.append(.keyDown)
            if configuration.effectiveHoldRepeat {
                nextRepeatAt = time + configuration.repeatDelay
            }
        }
        return events
    }

    mutating func release(at time: TimeInterval) -> [RemoteGestureEvent] {
        guard isPressed else { return [] }
        var events = advance(to: time)
        isPressed = false
        pressedAt = nil
        nextRepeatAt = nil
        if keyIsDown {
            keyIsDown = false
            events.append(.keyUp)
        } else if !longPressFired {
            if configuration.hasDoubleClick {
                if isSecondClick {
                    events.append(.trigger(.doubleClick))
                } else {
                    pendingClickDeadline = time + configuration.doubleClickInterval
                }
            } else {
                // With only a long mapping, click executes immediately on release;
                // there is no unnecessary double-click waiting window.
                events.append(.trigger(.click))
            }
        }
        isSecondClick = false
        longPressFired = false
        return events
    }

    mutating func advance(to time: TimeInterval) -> [RemoteGestureEvent] {
        var events = [RemoteGestureEvent]()
        if let deadline = pendingClickDeadline, time >= deadline {
            pendingClickDeadline = nil
            events.append(.trigger(.click))
        }
        if isPressed,
           let pressedAt,
           configuration.hasLongPress,
           !longPressFired,
           time >= pressedAt + configuration.longPressInterval {
            longPressFired = true
            isSecondClick = false
            events.append(.trigger(.longPress))
        }
        if isPressed, let deadline = nextRepeatAt, time >= deadline {
            // A late timer emits one repeat, never a burst of stale repeats.
            nextRepeatAt = time + configuration.repeatInterval
            events.append(.repeatKeyDown)
        }
        return events
    }

    /// Disconnect, disable, settings edits and stop discard deferred actions,
    /// but always release a synthetic key that has already been pressed.
    mutating func cancel() -> [RemoteGestureEvent] {
        let events: [RemoteGestureEvent] = keyIsDown ? [.keyUp] : []
        isPressed = false
        pressedAt = nil
        pendingClickDeadline = nil
        nextRepeatAt = nil
        isSecondClick = false
        longPressFired = false
        keyIsDown = false
        return events
    }
}

/// An explicit user-selected application, not an executable command or URL.
struct RemoteApplicationShortcut: Codable, Hashable {
    let bundleIdentifier: String?
    let path: String
    let name: String
}
