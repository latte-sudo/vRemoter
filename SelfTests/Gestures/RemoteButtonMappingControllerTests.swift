// macOS-only integration harness. It uses the real store, recognizer, controller
// and CGEvent builders, but its output sink never posts an event to the system.
import AppKit
import CoreGraphics
import Foundation

enum L10n {
    static func text(_ chinese: String, _ english: String) -> String { english }
}
enum Key { static let syntheticMarker: Int64 = 0x56524D54 }

private var assertionCount = 0

private func expect<T: Equatable>(
    _ actual: T, _ expected: T, _ description: String,
    file: StaticString = #filePath, line: UInt = #line
) {
    assertionCount += 1
    guard actual == expected else {
        fatalError("FAIL: \(description)\nExpected: \(expected)\nActual: \(actual)", file: file, line: line)
    }
}

/// Retain even canceled callbacks: invalidating a Timer does not by itself
/// prove that a callback already queued by a scheduler cannot affect a new hold.
private final class FakeScheduler {
    private struct Entry {
        let id: Int
        let deadline: TimeInterval
        let callback: () -> Void
        var canceled = false
        var fired = false
    }

    var now: TimeInterval = 0
    private var entries: [Int: Entry] = [:]
    private var nextID = 0

    var pendingIDs: [Int] {
        entries.values.filter { !$0.canceled && !$0.fired }
            .sorted { lhs, rhs in
                lhs.deadline == rhs.deadline ? lhs.id < rhs.id : lhs.deadline < rhs.deadline
            }.map { $0.id }
    }

    var retainedIDs: [Int] { entries.keys.sorted() }

    func schedule(delay: TimeInterval, callback: @escaping () -> Void) -> (() -> Void) {
        nextID += 1
        let id = nextID
        entries[id] = Entry(id: id, deadline: now + delay, callback: callback)
        return { [weak self] in self?.entries[id]?.canceled = true }
    }

    @discardableResult
    func fireNext(at time: TimeInterval? = nil) -> Int {
        guard let id = pendingIDs.first, let entry = entries[id] else {
            fatalError("Expected a scheduled callback")
        }
        now = max(now, time ?? entry.deadline)
        expect(now >= entry.deadline, true, "Test scheduler never fires a live timer early")
        entries[id]?.fired = true
        entry.callback()
        return id
    }

    func fireRetained(_ id: Int) {
        guard let entry = entries[id] else { fatalError("Unknown callback \(id)") }
        entry.callback()
    }
}

private struct PostedAction: Equatable {
    let target: RemoteMappingTarget
    let shortcut: RemoteCustomShortcut?
    let application: RemoteApplicationShortcut?
    let isDown: Bool
    let isRepeat: Bool

    init(_ action: RemoteMappingAction, isDown: Bool, isRepeat: Bool) {
        target = action.target
        shortcut = action.shortcut
        application = action.application
        self.isDown = isDown
        self.isRepeat = isRepeat
    }
}

private final class OutputRecorder {
    var actions: [PostedAction] = []
    var scrollEvents: [CGEvent] = []
    var applicationSwitchEvents: [CGEvent] = []

    func receive(_ action: RemoteMappingAction, isDown: Bool, isRepeat: Bool) {
        actions.append(PostedAction(action, isDown: isDown, isRepeat: isRepeat))
        if isDown, action.target.scrollDelta != nil {
            guard let event = action.target.scrollEvent() else {
                fatalError("Failed to construct a scroll event")
            }
            scrollEvents.append(event)
        }
        if action.target == .switchApplications, isDown, !isRepeat {
            let events = RemoteMappingTarget.applicationSwitchEvents()
            expect(events.count, 4, "Build the complete app-switch sequence without posting")
            applicationSwitchEvents.append(contentsOf: events)
        }
    }
}

private final class Fixture {
    let suite: String
    let defaults: UserDefaults
    let store: RemoteMappingStore
    let scheduler: FakeScheduler
    let output: OutputRecorder
    let controller: RemoteButtonMappingController

    init() {
        let suite = "vRemote.mapping-controller-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RemoteMappingStore(defaults: defaults)
        let scheduler = FakeScheduler()
        let output = OutputRecorder()
        self.suite = suite
        self.defaults = defaults
        self.store = store
        self.scheduler = scheduler
        self.output = output
        controller = RemoteButtonMappingController(
            store: store,
            now: { scheduler.now },
            schedule: { delay, callback in scheduler.schedule(delay: delay, callback: callback) },
            post: { action, isDown, isRepeat in
                output.receive(action, isDown: isDown, isRepeat: isRepeat)
            }
        )
        store.setEnabled(true, for: .chromecast)
        controller.start()
    }

    func cleanUp() {
        controller.stop()
        defaults.removePersistentDomain(forName: suite)
    }

    func press(_ id: String) { controller.handle(buttonID: id, isDown: true) }
    func release(_ id: String) { controller.handle(buttonID: id, isDown: false) }

    func expectIdle(_ description: String) {
        expect(controller.activeSessionCount, 0, description + ": no session")
        expect(controller.hasScheduledTimer, false, description + ": no owned timer")
        expect(scheduler.pendingIDs, [], description + ": scheduler canceled")
    }
}

@main
struct RemoteButtonMappingControllerTests {
    private static let directions: [(id: String, click: RemoteMappingTarget, scroll: RemoteMappingTarget, vertical: Int64, horizontal: Int64)] = [
        ("03", .arrowUp, .scrollUp, 20, 0),
        ("04", .arrowDown, .scrollDown, -20, 0),
        ("05", .arrowLeft, .scrollLeft, 0, 20),
        ("06", .arrowRight, .scrollRight, 0, -20)
    ]

    private static func button(_ id: String) -> RemoteButtonDefinition {
        RemoteProfiles.chromecastButtons.first { $0.id == id }!
    }

    private static func withFixture(_ body: (Fixture) throws -> Void) rethrows {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        try body(fixture)
    }

    static func main() throws {
        expect(Thread.isMainThread, true, "Controller harness uses the production main-thread contract")
        directionalLongHoldsAndShortClicks()
        delayedReleaseNeverStartsScrolling()
        clickScrollingRepeatsUntilRelease()
        arbitraryButtonDeferredScrolling()
        disconnectAndStopLifecycle()
        mappingAndSleepCancellation()
        pendingDoubleClickCancellation()
        staleTimerCannotAdvanceNewSession()
        try customizedPressTimeRelease()
        switchApplicationsDoesNotRepeat()
        print("PASS: \(assertionCount) mapping-controller and non-posting CGEvent assertions")
    }

    private static func expectScrollEvent(_ event: CGEvent, vertical: Int64, horizontal: Int64) {
        expect(event.type, .scrollWheel, "Built event is a real CGEvent scroll wheel event")
        expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), vertical, "Signed pixel delta on the vertical axis")
        expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2), horizontal, "Signed pixel delta on the horizontal axis")
        expect(event.getIntegerValueField(.scrollWheelEventIsContinuous), 1, "Pixel scrolling is marked continuous")
        expect(event.getIntegerValueField(.eventSourceUserData), Key.syntheticMarker, "Scroll carries the synthetic-event marker")
        expect(event.flags.rawValue, CGEventFlags().rawValue, "Scroll has no stuck keyboard modifiers")
    }

    private static func directionalLongHoldsAndShortClicks() {
        for direction in directions {
            withFixture { fixture in
                let definition = button(direction.id)
                expect(fixture.store.target(for: definition, remote: .chromecast), direction.click, "Untouched D-pad retains its arrow click")
                expect(fixture.store.target(for: definition, remote: .chromecast, gesture: .longPress), direction.scroll, "Untouched D-pad seeds directional long scrolling")
                expect(fixture.store.gestureConfiguration(for: definition, remote: .chromecast).repeatsLongPress, true, "Long scrolling is continuous")

                for cycle in 0..<3 {
                    let actionStart = fixture.output.actions.count
                    let scrollStart = fixture.output.scrollEvents.count
                    let pressedAt = fixture.scheduler.now
                    fixture.press(direction.id)
                    let initialTimer = fixture.scheduler.pendingIDs
                    expect(initialTimer.count, 1, "Each long hold schedules one deadline")
                    expect(fixture.controller.activeSessionCount, 1, "Exactly one session for one physical button")
                    fixture.scheduler.now = pressedAt + 0.20
                    fixture.press(direction.id)
                    expect(fixture.scheduler.pendingIDs, initialTimer, "Duplicate HID down cannot restart the threshold")
                    expect(fixture.output.actions.count, actionStart, "Long mapping defers the ordinary click")
                    fixture.scheduler.fireNext()
                    expect(fixture.output.actions.count, actionStart + 1, "Long hold begins once at its deadline")
                    expect(fixture.output.actions.last?.target, direction.scroll, "Correct held direction in cycle \(cycle)")
                    expect(fixture.output.actions.last?.isRepeat, false, "First scroll is not a repeat")
                    for _ in 0..<3 {
                        let pending = fixture.scheduler.pendingIDs
                        fixture.press(direction.id)
                        expect(fixture.scheduler.pendingIDs, pending, "Repeated HID down does not disturb the repeat timer")
                        fixture.scheduler.fireNext()
                        expect(fixture.output.actions.last?.isRepeat, true, "Held long scroll repeats")
                    }
                    expect(fixture.output.scrollEvents.count, scrollStart + 4, "One initial scroll and three repeats")
                    for event in fixture.output.scrollEvents.dropFirst(scrollStart) {
                        expectScrollEvent(event, vertical: direction.vertical, horizontal: direction.horizontal)
                    }
                    let stale = fixture.scheduler.pendingIDs[0]
                    // The release arrives well after the next repeat deadline,
                    // before that timer had a chance to run.
                    fixture.scheduler.now += 5
                    fixture.release(direction.id)
                    expect(fixture.output.actions.count, actionStart + 5, "Release emits only the balancing long-up")
                    expect(fixture.output.actions.last?.target, direction.scroll, "Release retains the long action")
                    expect(fixture.output.actions.last?.isDown, false, "Release balances the held action")
                    expect(fixture.output.actions.last?.isRepeat, false, "Release never becomes a repeat")
                    expect(fixture.output.scrollEvents.count, scrollStart + 4, "Delayed release creates no extra CGEvent scroll")
                    fixture.expectIdle("Released long hold")
                    let released = fixture.output.actions
                    fixture.scheduler.fireRetained(stale)
                    fixture.release(direction.id)
                    expect(fixture.output.actions, released, "Canceled callback and duplicate release stay silent")
                    fixture.expectIdle("Late callback after release")
                    fixture.scheduler.now += 1
                }

                let actionStart = fixture.output.actions.count
                let scrollStart = fixture.output.scrollEvents.count
                fixture.press(direction.id)
                fixture.scheduler.now += 0.10
                fixture.release(direction.id)
                expect(fixture.output.actions.dropFirst(actionStart).map { $0.target }, [direction.click, direction.click], "Short click still emits the arrow action")
                expect(fixture.output.actions.dropFirst(actionStart).map { $0.isDown }, [true, false], "Short click is balanced")
                expect(fixture.output.scrollEvents.count, scrollStart, "Short click emits no scroll")
                fixture.expectIdle("Short D-pad click")
            }
        }
    }

    private static func delayedReleaseNeverStartsScrolling() {
        for direction in directions {
            withFixture { fixture in
                fixture.press(direction.id)
                let stale = fixture.scheduler.pendingIDs[0]
                fixture.scheduler.now += 10
                fixture.release(direction.id)
                expect(fixture.output.actions, [], "A late release without a timer tick never starts continuous long scroll or leaks a click")
                expect(fixture.output.scrollEvents.count, 0, "No phantom scroll CGEvent on late release")
                fixture.expectIdle("Unticked long hold released")
                fixture.scheduler.fireRetained(stale)
                expect(fixture.output.actions, [], "Expired long timer cannot resurrect a released hold")
                fixture.expectIdle("Expired long timer")
            }
        }
    }

    private static func clickScrollingRepeatsUntilRelease() {
        for direction in directions {
            withFixture { fixture in
                fixture.store.setTarget(direction.scroll, for: button("07"), remote: .chromecast)
                fixture.store.setHoldRepeats(false, for: button("07"), remote: .chromecast)
                fixture.press("07")
                expect(fixture.output.scrollEvents.count, 1, "Click-mapped scroll begins immediately")
                fixture.scheduler.fireNext()
                expect(fixture.output.actions.last?.isRepeat, true, "Continuous click scroll repeats even without keyboard-repeat preference")
                let count = fixture.output.scrollEvents.count
                fixture.scheduler.now += 5
                fixture.release("07")
                expect(fixture.output.scrollEvents.count, count, "Overdue repeat never scrolls on release")
                for event in fixture.output.scrollEvents {
                    expectScrollEvent(event, vertical: direction.vertical, horizontal: direction.horizontal)
                }
                fixture.expectIdle("Click scroll released")
            }
        }
    }

    private static func arbitraryButtonDeferredScrolling() {
        for direction in directions {
            for gesture in [RemoteButtonGesture.doubleClick, .longPress] {
                withFixture { fixture in
                    fixture.store.setTarget(direction.scroll, for: button("07"), remote: .chromecast, gesture: gesture)
                    fixture.press("07")
                    expect(fixture.output.actions, [], "Configured deferred gesture on a non-D-pad button waits")
                    if gesture == .doubleClick {
                        fixture.scheduler.now += 0.05
                        fixture.release("07")
                        fixture.scheduler.now += 0.10
                        fixture.press("07")
                        fixture.scheduler.now += 0.05
                        fixture.release("07")
                        expect(fixture.output.actions.map { $0.target }, [direction.scroll, direction.scroll], "Double-click scroll emits only its assigned action")
                        expect(fixture.output.actions.map { $0.isDown }, [true, false], "Double-click scroll is balanced")
                        expect(fixture.output.scrollEvents.count, 1, "Double-click scroll emits exactly one pulse")
                    } else {
                        fixture.scheduler.fireNext()
                        expect(fixture.output.actions.last?.target, direction.scroll, "Non-D-pad long press uses the assigned scroll direction")
                        fixture.scheduler.fireNext()
                        fixture.scheduler.fireNext()
                        expect(fixture.output.scrollEvents.count, 3, "Non-D-pad long scroll continues while held")
                        expect(fixture.output.actions.map { $0.isRepeat }, [false, true, true], "Long scroll repeats only after its initial pulse")
                        fixture.scheduler.now += 5
                        fixture.release("07")
                        expect(fixture.output.scrollEvents.count, 3, "Non-D-pad long scroll stops without a final pulse")
                        expect(fixture.output.actions.last?.isDown, false, "Non-D-pad long scroll is balanced on release")
                    }
                    fixture.expectIdle("Deferred scroll gesture completed")
                    for event in fixture.output.scrollEvents {
                        expectScrollEvent(event, vertical: direction.vertical, horizontal: direction.horizontal)
                    }
                    let completed = fixture.output.actions
                    fixture.scheduler.now += 5
                    for id in fixture.scheduler.retainedIDs { fixture.scheduler.fireRetained(id) }
                    expect(fixture.output.actions, completed, "Completed deferred scroll cannot be restarted by an old timer")
                    fixture.expectIdle("Deferred scroll stale callbacks")
                }
            }
        }
    }

    private static func disconnectAndStopLifecycle() {
        for shouldStop in [false, true] {
            for beginScrolling in [false, true] {
                withFixture { fixture in
                    fixture.press("03")
                    if beginScrolling { fixture.scheduler.fireNext() }
                    fixture.press("07")
                    let obsoleteCallbacks = fixture.scheduler.retainedIDs
                    let before = fixture.output.actions.count
                    expect(fixture.controller.activeSessionCount, 2, "Lifecycle interruption includes concurrent sessions")
                    if shouldStop { fixture.controller.stop() }
                    else { fixture.controller.disconnected() }
                    expect(fixture.output.actions.count, before + (beginScrolling ? 2 : 1), "Interrupt balances started actions and discards pending ones")
                    expect(fixture.output.actions.dropFirst(before).allSatisfy { !$0.isDown && !$0.isRepeat }, true, "Cleanup emits only releases")
                    fixture.expectIdle("Interrupted controller")
                    let interrupted = fixture.output.actions
                    fixture.scheduler.now += 5
                    for id in obsoleteCallbacks { fixture.scheduler.fireRetained(id) }
                    expect(fixture.output.actions, interrupted, "Old callbacks remain silent across interruption")
                    fixture.expectIdle("Interrupted callbacks")
                    if shouldStop {
                        fixture.press("03")
                        expect(fixture.output.actions, interrupted, "Stopped controller ignores input")
                        fixture.expectIdle("Input while stopped")
                        fixture.controller.start()
                        fixture.controller.start()
                    }
                    // Reconnection/restart clears physical latches, so the next
                    // down is valid even if disconnection swallowed the old up.
                    fixture.press("03")
                    expect(fixture.controller.activeSessionCount, 1, "Reconnect/restart admits the next physical hold")
                    let newTimer = fixture.scheduler.pendingIDs
                    expect(newTimer.count, 1, "Restart creates exactly one timer")
                    fixture.scheduler.now += 0.10
                    for id in obsoleteCallbacks { fixture.scheduler.fireRetained(id) }
                    expect(fixture.scheduler.pendingIDs, newTimer, "Stale callback cannot replace the new timer")
                    expect(fixture.output.actions, interrupted, "Stale callback cannot act in the new session")
                    fixture.scheduler.fireNext()
                    expect(fixture.output.actions.last?.target, .scrollUp, "Fresh hold scrolls after its own deadline")
                    fixture.release("03")
                    fixture.expectIdle("Fresh lifecycle hold released")
                    fixture.controller.stop()
                    let stopped = fixture.output.actions
                    fixture.controller.stop()
                    expect(fixture.output.actions, stopped, "Stop is idempotent")
                }
            }
        }
    }

    private static func mappingAndSleepCancellation() {
        let changes: [(name: String, nextTarget: RemoteMappingTarget, change: (Fixture) -> Void)] = [
            ("mapping edit", .scrollDown, { fixture in
                fixture.store.setTarget(.scrollDown, for: button("03"), remote: .chromecast, gesture: .longPress)
            }),
            ("mapping reset", .scrollUp, { fixture in fixture.store.reset(.chromecast) }),
            ("archive reload", .scrollLeft, { fixture in
                fixture.defaults.set(RemoteMappingTarget.scrollLeft.rawValue, forKey: "remoteMapping.chromecast.03.longPress")
                fixture.store.reload()
            }),
            ("disable/re-enable", .scrollUp, { fixture in
                fixture.store.setEnabled(false, for: .chromecast)
                fixture.press("04")
                expect(fixture.controller.activeSessionCount, 0, "Disabled controller cannot start another button")
                fixture.release("04")
                fixture.store.setEnabled(true, for: .chromecast)
            }),
            // The HID bridge invokes this same cancellation entry point when
            // suspended or put to sleep; OS notification delivery is not tested.
            ("suspend cleanup", .scrollUp, { fixture in fixture.controller.cancelHeldActions() }),
            ("sleep cleanup", .scrollUp, { fixture in fixture.controller.cancelHeldActions() })
        ]
        for change in changes {
            for beginScrolling in [false, true] {
                withFixture { fixture in
                    fixture.press("03")
                    if beginScrolling { fixture.scheduler.fireNext() }
                    let oldTimers = fixture.scheduler.retainedIDs
                    let before = fixture.output.actions.count
                    change.change(fixture)
                    expect(fixture.output.actions.count, before + (beginScrolling ? 1 : 0), change.name + " releases only an action that started")
                    if beginScrolling {
                        expect(fixture.output.actions.last?.target, .scrollUp, change.name + " releases the original direction")
                        expect(fixture.output.actions.last?.isDown, false, change.name + " sends a balancing release")
                    }
                    fixture.expectIdle(change.name)
                    let canceled = fixture.output.actions
                    fixture.scheduler.now += 3
                    for id in oldTimers { fixture.scheduler.fireRetained(id) }
                    fixture.press("03")
                    fixture.controller.cancelHeldActions()
                    fixture.press("03")
                    expect(fixture.output.actions, canceled, change.name + " rejects duplicate held reports until physical release")
                    fixture.expectIdle(change.name + " remains canceled")
                    fixture.release("03")
                    expect(fixture.output.actions, canceled, change.name + " does not turn the old up into a click")
                    fixture.press("03")
                    fixture.scheduler.fireNext()
                    expect(fixture.output.actions.last?.target, change.nextTarget, change.name + " uses current mapping for the next genuine press")
                    fixture.release("03")
                    fixture.expectIdle(change.name + " fresh press released")
                }
            }
        }
    }

    private static func pendingDoubleClickCancellation() {
        for reloadFromDefaults in [false, true] {
            withFixture { fixture in
                fixture.store.setTarget(.commandC, for: button("07"), remote: .chromecast)
                fixture.store.setTarget(.commandV, for: button("07"), remote: .chromecast, gesture: .doubleClick)
                fixture.press("07")
                fixture.scheduler.now += 0.05
                fixture.release("07")
                expect(fixture.output.actions, [], "Deferred click waits for double-click deadline")
                let stale = fixture.scheduler.pendingIDs[0]
                if reloadFromDefaults {
                    fixture.defaults.set(RemoteMappingTarget.commandZ.rawValue, forKey: "remoteMapping.chromecast.07")
                    fixture.store.reload()
                } else {
                    fixture.store.setTarget(.commandZ, for: button("07"), remote: .chromecast)
                }
                fixture.expectIdle("Edit/reload discards deferred click")
                fixture.scheduler.now += 1
                fixture.scheduler.fireRetained(stale)
                expect(fixture.output.actions, [], "Canceled deferred click never fires after edit/reload")
                fixture.press("07")
                fixture.scheduler.now += 0.05
                fixture.release("07")
                fixture.scheduler.fireNext()
                expect(fixture.output.actions.map { $0.target }, [.commandZ, .commandZ], "Fresh click completes with the current mapping after cancellation")
                expect(fixture.output.actions.map { $0.isDown }, [true, false], "Fresh deferred click is balanced")
                fixture.expectIdle("Fresh deferred click completed")
            }
        }
    }

    private static func staleTimerCannotAdvanceNewSession() {
        withFixture { fixture in
            fixture.press("03")
            let oldTimer = fixture.scheduler.pendingIDs[0]
            fixture.scheduler.now = 0.10
            fixture.release("03")
            let firstClick = fixture.output.actions
            fixture.scheduler.now = 0.20
            fixture.press("03")
            let newTimer = fixture.scheduler.pendingIDs
            expect(newTimer.count, 1, "New hold owns its own threshold timer")
            // Old deadline was 0.55; new deadline is 0.75. Merely checking the
            // event count misses a stale callback that replaces the new timer.
            fixture.scheduler.now = 0.60
            fixture.scheduler.fireRetained(oldTimer)
            expect(fixture.output.actions, firstClick, "Old timer cannot start the new long hold early")
            expect(fixture.scheduler.pendingIDs, newTimer, "Old callback cannot reschedule a newer session")
            fixture.scheduler.now = 0.80
            fixture.scheduler.fireRetained(oldTimer)
            expect(fixture.output.actions, firstClick, "Even after the new deadline only its own timer can advance it")
            expect(fixture.scheduler.pendingIDs, newTimer, "Generation guard protects the newer overdue timer")
            fixture.scheduler.fireNext()
            expect(fixture.output.actions.count, firstClick.count + 1, "New timer emits exactly one initial long scroll")
            let active = fixture.output.actions
            let repeatTimer = fixture.scheduler.pendingIDs
            fixture.scheduler.fireRetained(oldTimer)
            expect(fixture.output.actions, active, "Old timer cannot repeat a new active hold")
            expect(fixture.scheduler.pendingIDs, repeatTimer, "Old timer cannot disturb the new repeat deadline")
            fixture.release("03")
            fixture.expectIdle("Generation-guard hold released")
        }
    }

    private static func customizedPressTimeRelease() throws {
        let original = RemoteCustomShortcut(keyCode: 8, flags: CGEventFlags.maskCommand.rawValue, label: "Original ⌘C")
        let replacement = RemoteCustomShortcut(keyCode: 9, flags: CGEventFlags.maskShift.rawValue, label: "New ⇧V")
        for reloadFromDefaults in [false, true] {
            try withFixture { fixture in
                fixture.store.setCustomShortcut(original, for: button("07"), remote: .chromecast)
                fixture.store.setHoldRepeats(true, for: button("07"), remote: .chromecast)
                fixture.press("07")
                expect(fixture.output.actions.last?.shortcut, original, "Initial custom down captures the original shortcut")
                let stale = fixture.scheduler.pendingIDs[0]
                if reloadFromDefaults {
                    fixture.defaults.set(try JSONEncoder().encode(replacement), forKey: "remoteCustomMapping.chromecast.07")
                    fixture.store.reload()
                } else {
                    fixture.store.setCustomShortcut(replacement, for: button("07"), remote: .chromecast)
                }
                expect(fixture.output.actions.count, 2, "Editing a held shortcut balances exactly one down/up pair")
                expect(fixture.output.actions.map { $0.shortcut }, [original, original], "Release uses immutable press-time shortcut, not the edited mapping")
                expect(fixture.output.actions.map { $0.isDown }, [true, false], "Original custom shortcut is balanced")
                fixture.expectIdle("Custom mapping edit")
                let canceled = fixture.output.actions
                fixture.scheduler.now += 2
                fixture.scheduler.fireRetained(stale)
                fixture.press("07")
                expect(fixture.output.actions, canceled, "Old repeat and duplicate custom down are suppressed after edit")
                fixture.release("07")
                fixture.press("07")
                expect(fixture.output.actions.last?.shortcut, replacement, "Next physical press uses the replacement shortcut")
                fixture.release("07")
                expect(fixture.output.actions.suffix(2).map { $0.shortcut }, [replacement, replacement], "Replacement shortcut also balances correctly")
                expect(fixture.output.actions.suffix(2).map { $0.isDown }, [true, false], "Replacement emits down then up")
                fixture.expectIdle("Replacement shortcut released")
            }
        }
    }

    private static func expectApplicationSwitchSequence(_ events: [CGEvent]) {
        expect(events.count, 4, "App switch is a complete four-event sequence")
        expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [0x37, 0x30, 0x30, 0x37], "Command down, Tab down, Tab up, Command up keycodes")
        // Quartz may represent a modifier transition as flagsChanged. Its
        // keycode and Command flag below still unambiguously identify down/up.
        expect(events[0].type == .keyDown || events[0].type == .flagsChanged, true, "First event presses Command")
        expect(events[1].type, .keyDown, "Second event presses Tab")
        expect(events[2].type, .keyUp, "Third event releases Tab")
        expect(events[3].type == .keyUp || events[3].type == .flagsChanged, true, "Final event releases Command")
        expect(events.map { $0.flags.rawValue }, [CGEventFlags.maskCommand.rawValue, CGEventFlags.maskCommand.rawValue, CGEventFlags.maskCommand.rawValue, 0], "Command applies through Tab up and is cleared by final release")
        for event in events {
            expect(event.getIntegerValueField(.eventSourceUserData), Key.syntheticMarker, "Every app-switch event carries the synthetic marker")
            expect(event.getIntegerValueField(.keyboardEventAutorepeat), 0, "App-switch sequence never marks an autorepeat")
        }
    }

    private static func switchApplicationsDoesNotRepeat() {
        expectApplicationSwitchSequence(RemoteMappingTarget.applicationSwitchEvents())
        for useLongPress in [false, true] {
            withFixture { fixture in
                // Select has no seeded D-pad long gesture, so the click case is
                // immediate rather than accidentally deferred by scroll defaults.
                fixture.store.setTarget(.switchApplications, for: button("07"), remote: .chromecast, gesture: useLongPress ? .longPress : .click)
                fixture.store.setHoldRepeats(true, for: button("07"), remote: .chromecast)
                let action = fixture.store.action(for: button("07"), remote: .chromecast, gesture: useLongPress ? .longPress : .click)
                expect(action.canRepeat, false, "Application switching is never repeatable")
                expect(fixture.store.gestureConfiguration(for: button("07"), remote: .chromecast).effectiveHoldRepeat, false, "Stored repeat preference cannot repeat application switching")
                for _ in 0..<3 {
                    let before = fixture.output.applicationSwitchEvents.count
                    fixture.press("07")
                    if useLongPress { fixture.scheduler.fireNext() }
                    expect(fixture.output.applicationSwitchEvents.count, before + 4, "Each genuine gesture builds one complete app switch")
                    expectApplicationSwitchSequence(Array(fixture.output.applicationSwitchEvents.suffix(4)))
                    expect(fixture.controller.hasScheduledTimer, false, "App switch schedules no hold repeats")
                    expect(fixture.scheduler.pendingIDs, [], "No app-switch repeat callbacks remain")
                    let held = fixture.output.actions
                    fixture.scheduler.now += 20
                    fixture.press("07")
                    for id in fixture.scheduler.retainedIDs { fixture.scheduler.fireRetained(id) }
                    expect(fixture.output.actions, held, "Long hold, duplicate down and stale callback cannot repeat app switch")
                    fixture.release("07")
                    expect(fixture.output.applicationSwitchEvents.count, before + 4, "Physical release never creates another app switch")
                    expect(fixture.output.actions.filter { $0.isRepeat }, [], "Controller emits no app-switch repeat action")
                    fixture.expectIdle("Application switch released")
                    fixture.scheduler.now += 1
                }
            }
        }
    }
}
