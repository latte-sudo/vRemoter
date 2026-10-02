import Foundation

@main
struct RemoteButtonGestureTests {
    private static var assertions = 0

    static func expect<T: Equatable>(_ actual: T, _ expected: T, _ description: String) {
        assertions += 1
        guard actual == expected else {
            fatalError("FAIL: \(description)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    static func main() throws {
        immediateClick()
        delayedSingleClick()
        doubleClick()
        expiredDoubleClick()
        longPress()
        longPressWithoutDoubleDelay()
        combinedGestures()
        repeatAndConflict()
        cancelAndReconnect()
        try codableActions()
        print("PASS: \(assertions) ordinary-button gesture assertions")
    }

    static func immediateClick() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init())
        expect(recognizer.press(at: 0), [.keyDown], "Default click responds on down")
        expect(recognizer.nextDeadline, nil, "Default click has no double-click timer")
        expect(recognizer.press(at: 0.02), [], "Duplicate HID down ignored")
        expect(recognizer.release(at: 0.04), [.keyUp], "Default click has balanced release")
        expect(recognizer.release(at: 0.05), [], "Duplicate release ignored")
        expect(recognizer.isIdle, true, "Released click is idle")
        expect(recognizer.press(at: 0.1), [.keyDown], "Fast second click does not imply double gesture")
        expect(recognizer.release(at: 0.2), [.keyUp], "Both unconfigured clicks work")
    }

    static func delayedSingleClick() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(hasDoubleClick: true))
        expect(recognizer.press(at: 0), [], "Double mapping defers ordinary click")
        expect(recognizer.release(at: 0.05), [], "Wait for second click after release")
        expect(recognizer.advance(to: 0.34), [], "Do not fire early")
        expect(recognizer.advance(to: 0.36), [.trigger(.click)], "Fire single after double interval")
        expect(recognizer.advance(to: 1), [], "Deferred click executes exactly once")
        expect(recognizer.isIdle, true, "Deferred click completes")
    }

    static func doubleClick() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(hasDoubleClick: true))
        _ = recognizer.press(at: 0)
        _ = recognizer.release(at: 0.05)
        expect(recognizer.press(at: 0.2), [], "Second down cancels pending single")
        expect(recognizer.release(at: 0.25), [.trigger(.doubleClick)], "Double fires once on second release")
        expect(recognizer.advance(to: 2), [], "No single leaks after double")
        _ = recognizer.press(at: 2.1)
        _ = recognizer.release(at: 2.15)
        expect(recognizer.advance(to: 2.5), [.trigger(.click)], "Third tap begins a separate sequence")
    }

    static func expiredDoubleClick() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(hasDoubleClick: true))
        _ = recognizer.press(at: 0)
        _ = recognizer.release(at: 0)
        expect(recognizer.press(at: 0.30), [.trigger(.click)], "At deadline first click wins even if timer is late")
        _ = recognizer.release(at: 0.35)
        expect(recognizer.advance(to: 0.66), [.trigger(.click)], "Expired second tap is an independent single")
    }

    static func longPress() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(hasLongPress: true))
        expect(recognizer.press(at: 0), [], "Long mapping waits without firing single")
        expect(recognizer.advance(to: 0.54), [], "Long press respects threshold")
        expect(recognizer.advance(to: 0.55), [.trigger(.longPress)], "Long fires at threshold")
        expect(recognizer.advance(to: 4), [], "Long fires only once while held")
        expect(recognizer.release(at: 4.1), [], "Long release does not leak click")
        _ = recognizer.press(at: 5)
        expect(recognizer.release(at: 5.6), [.trigger(.longPress)], "Late timer still classifies long on release")
    }

    static func longPressWithoutDoubleDelay() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(hasLongPress: true))
        _ = recognizer.press(at: 0)
        expect(recognizer.release(at: 0.1), [.trigger(.click)], "Only-long configuration clicks immediately on release")
        expect(recognizer.nextDeadline, nil, "No double waiting window when double is disabled")
        _ = recognizer.press(at: 0.2)
        expect(recognizer.release(at: 0.3), [.trigger(.click)], "Two short taps remain two singles")
    }

    static func combinedGestures() {
        let configuration = RemoteGestureConfiguration(hasDoubleClick: true, hasLongPress: true)
        var recognizer = RemoteButtonGestureRecognizer(configuration: configuration)
        _ = recognizer.press(at: 0)
        _ = recognizer.release(at: 0.05)
        _ = recognizer.press(at: 0.2)
        expect(recognizer.release(at: 0.3), [.trigger(.doubleClick)], "Double wins for two short taps")
        _ = recognizer.press(at: 1)
        expect(recognizer.advance(to: 1.6), [.trigger(.longPress)], "Long mapping works alongside double")
        expect(recognizer.release(at: 1.7), [], "Long release is suppressed")
        _ = recognizer.press(at: 2)
        _ = recognizer.release(at: 2.05)
        _ = recognizer.press(at: 2.1)
        expect(recognizer.advance(to: 2.7), [.trigger(.longPress)], "Second tap held long supersedes the pending double sequence")
        expect(recognizer.release(at: 3), [], "No double or single leaks after second-tap hold")
        expect(recognizer.advance(to: 4), [], "Combined sequence completely settles")
    }

    static func repeatAndConflict() {
        var recognizer = RemoteButtonGestureRecognizer(configuration: .init(repeatsWhileHeld: true))
        expect(recognizer.press(at: 0), [.keyDown], "Repeat keeps initial click immediate")
        expect(recognizer.advance(to: 0.44), [], "Repeat initial delay")
        expect(recognizer.advance(to: 0.45), [.repeatKeyDown], "Repeat starts after delay")
        expect(recognizer.advance(to: 8), [.repeatKeyDown], "Late repeat timer never emits a backlog burst")
        expect(recognizer.release(at: 8.01), [.keyUp], "Repeated key still has balanced release")
        expect(recognizer.advance(to: 10), [], "Repeat stops on release")
        for configuration in [
            RemoteGestureConfiguration(hasDoubleClick: true, repeatsWhileHeld: true),
            RemoteGestureConfiguration(hasLongPress: true, repeatsWhileHeld: true),
            RemoteGestureConfiguration(hasDoubleClick: true, hasLongPress: true, repeatsWhileHeld: true),
        ] {
            expect(configuration.effectiveHoldRepeat, false, "Deferred gesture explicitly suspends hold repeat")
            var suspended = RemoteButtonGestureRecognizer(configuration: configuration)
            _ = suspended.press(at: 0)
            let events = suspended.advance(to: 2)
            expect(events.contains(.repeatKeyDown), false, "No repeat conflict can leak events")
            _ = suspended.cancel()
        }
    }

    static func cancelAndReconnect() {
        var immediate = RemoteButtonGestureRecognizer(configuration: .init(repeatsWhileHeld: true))
        _ = immediate.press(at: 0)
        expect(immediate.cancel(), [.keyUp], "Disconnect/disable/edit releases a held synthetic key")
        expect(immediate.cancel(), [], "Cancellation is idempotent")
        expect(immediate.advance(to: 3), [], "No repeat after stop")
        expect(immediate.press(at: 4), [.keyDown], "Reconnect starts fresh")
        expect(immediate.release(at: 4.1), [.keyUp], "Reconnect has balanced key state")
        var deferred = RemoteButtonGestureRecognizer(configuration: .init(hasDoubleClick: true, hasLongPress: true))
        _ = deferred.press(at: 0)
        _ = deferred.release(at: 0.1)
        expect(deferred.cancel(), [], "Cancel drops a deferred single")
        expect(deferred.advance(to: 1), [], "Deferred single never executes after cancel")
        _ = deferred.press(at: 2)
        expect(deferred.cancel(), [], "Cancel drops pending long gesture")
        expect(deferred.advance(to: 3), [], "No long gesture executes after cancel")
        expect(deferred.isIdle, true, "Canceled recognizer is idle")
        expect(deferred.nextDeadline, nil, "Canceled recognizer has no timers")
    }

    static func codableActions() throws {
        for gesture in RemoteButtonGesture.allCases {
            let data = try JSONEncoder().encode(gesture)
            expect(try JSONDecoder().decode(RemoteButtonGesture.self, from: data), gesture, "Gesture persistence round trip")
        }
        let application = RemoteApplicationShortcut(bundleIdentifier: "com.example.Editor", path: "/Applications/Editor.app", name: "Editor")
        let data = try JSONEncoder().encode(application)
        expect(try JSONDecoder().decode(RemoteApplicationShortcut.self, from: data), application, "Application metadata persistence round trip")
    }
}
