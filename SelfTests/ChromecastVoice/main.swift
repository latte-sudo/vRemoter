import Foundation

// Minimal platform adapters let the real configuration/controller/state-machine
// compile and run without AppKit, CoreAudio, Bluetooth, or injected OS events.
// This suite does not replace a macOS build or hardware acceptance test.
enum InputTriggerKey: String, Codable { case option, command, control, shift, function }
enum AppStorage {
    static var inputTriggerKey: InputTriggerKey = .option
}
enum Key {
    static func triggerDown(_ key: InputTriggerKey) {}
    static func triggerUp(_ key: InputTriggerKey) {}
}
final class AudioPipe {
    static let shared = AudioPipe()
    func setRemoteActive(_ active: Bool) -> Bool { true }
}
enum L10n {
    static func text(_ chinese: String, _ english: String) -> String { english }
}
enum RemoteMicrophoneOpenResult: Equatable {
    case sent, alreadyStreaming, retryAfter(TimeInterval), unavailable, failed(String)
}
protocol DoubaoAudioStateProviding: AnyObject {
    var onSnapshotChanged: ((DoubaoAudioStateMonitor.Snapshot) -> Void)? { get set }
    func start()
    func stop()
    func snapshotNow() -> DoubaoAudioStateMonitor.Snapshot
}
final class DoubaoAudioStateMonitor: DoubaoAudioStateProviding {
    enum State { case unavailable, inactive, active }
    struct Snapshot { let state: State; var isRecording: Bool { state == .active } }
    var onSnapshotChanged: ((Snapshot) -> Void)?
    var state: State = .inactive
    var starts = 0
    func start() { starts += 1 }
    func stop() {}
    func snapshotNow() -> Snapshot { Snapshot(state: state) }
    func emit(_ state: State) {
        self.state = state
        onSnapshotChanged?(snapshotNow())
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    print("PASS: \(message)")
}

/// A deterministic main-queue clock. Cancellation and work scheduled by other
/// work use the same semantics as production, without assuming CI wall time.
final class VirtualScheduler {
    private struct Entry {
        let deadline: TimeInterval
        let order: Int
        let work: DispatchWorkItem
    }
    private var now: TimeInterval = 0
    private var order = 0
    private var entries = [Entry]()

    func schedule(after delay: TimeInterval, work: DispatchWorkItem) {
        entries.append(Entry(deadline: now + delay, order: order, work: work))
        order += 1
    }

    func advance(by interval: TimeInterval) {
        let end = now + interval
        while let index = nextIndex(through: end) {
            let entry = entries.remove(at: index)
            now = max(now, entry.deadline)
            if !entry.work.isCancelled { entry.work.perform() }
        }
        now = end
    }

    /// Reproduce a stalled main queue: elapsed time alone runs no callbacks.
    func stall(for interval: TimeInterval) { now += interval }
    func runReady() { advance(by: 0) }

    private func nextIndex(through deadline: TimeInterval) -> Int? {
        entries.indices.filter { entries[$0].deadline <= deadline }.min {
            let lhs = entries[$0], rhs = entries[$1]
            return lhs.deadline == rhs.deadline ? lhs.order < rhs.order : lhs.deadline < rhs.deadline
        }
    }
}

final class Harness {
    var configuration: VoiceConfiguration
    let monitor = DoubaoAudioStateMonitor()
    let scheduler = VirtualScheduler()
    var events = [String]()
    var openResults = [RemoteMicrophoneOpenResult]()
    var opens = 0
    var closes = 0
    var ended = 0
    var routeStopSucceeds = true
    var routeStartSucceeds = true
    var statuses = [String]()
    lazy var controller: ChromecastVoiceSessionController = {
        let value = ChromecastVoiceSessionController(
            configurationProvider: { [unowned self] in self.configuration },
            doubaoState: monitor,
            setRemoteRouteActive: { [unowned self] active in
                self.events.append("route:\(active)")
                return active ? self.routeStartSucceeds : self.routeStopSucceeds
            },
            triggerDown: { [unowned self] in self.events.append("down:\($0.rawValue)") },
            triggerUp: { [unowned self] in self.events.append("up:\($0.rawValue)") },
            schedule: { [unowned self] delay, work in self.scheduler.schedule(after: delay, work: work) }
        )
        value.onMicrophoneOpenRequested = { [unowned self] bypass in
            require(bypass, "physical release continuation bypasses debounce")
            self.opens += 1
            return self.openResults.isEmpty ? .sent : self.openResults.removeFirst()
        }
        value.onMicrophoneCloseRequested = { [unowned self] in self.closes += 1 }
        value.onSessionEnded = { [unowned self] in self.ended += 1 }
        value.onStateChanged = { [unowned self] in self.statuses.append($0) }
        return value
    }()

    init(remote: RemoteVoiceMode = .toggle, target: InputToolTriggerMode = .toggle, tool: VoiceInputTool = .custom) {
        configuration = VoiceConfiguration(
            remoteVoiceMode: remote,
            inputToolTriggerMode: target,
            inputTool: tool,
            customBundleIdentifier: "example.input.tool",
            triggerKey: .option
        )
        controller.start()
    }

    func press(receivesPCM: Bool = true) {
        controller.remoteAudioStarted(reason: 0x03)
        if receivesPCM { controller.remotePCMReceived() }
    }
    func release() { controller.remoteAudioStopped(reason: 0x02) }
    var downs: Int { events.filter { $0.hasPrefix("down:") }.count }
    var ups: Int { events.filter { $0.hasPrefix("up:") }.count }
}

// Gesture mode behavior has no dependency on elapsed press duration.
do {
    var m = ChromecastVoiceStateMachine()
    require(m.remoteAudioStarted(reason: 0x03, mode: .toggle) == [.beginSession], "toggle press starts immediately")
    require(m.remoteAudioStarted(reason: 0x03, mode: .toggle).isEmpty, "duplicate physical down is ignored")
    require(m.remoteAudioStopped(reason: 0x02) == [.requestHostOpen], "first toggle release reopens from host")
    let g = m.generation
    require(m.remoteAudioStopped(reason: 0x02).isEmpty && m.awaitingHostOpen, "duplicate release preserves pending reopen")
    require(m.remoteAudioStarted(reason: 0, mode: .toggle).isEmpty && m.isActive, "host start only confirms existing session")
    require(m.remoteAudioStarted(reason: 0x03, mode: .toggle) == [.endSession], "second toggle DOWN stops immediately")
    require(!m.acceptsHostOpenWork(generation: g), "old host work is rejected after close")
    require(m.remoteAudioStopped(reason: 0x02).isEmpty, "second toggle release never reopens")
    require(m.remoteAudioStarted(reason: 0, mode: .toggle) == [.rejectStream], "stale host start cannot resurrect session")
}
do {
    var m = ChromecastVoiceStateMachine()
    require(m.remoteAudioStarted(reason: 0x03, mode: .hold) == [.beginSession], "hold begins without a long-press threshold")
    require(m.remoteAudioStopped(reason: 0x02) == [.endSession] && !m.isActive, "hold ends on immediate release")
    require(m.remoteAudioStarted(reason: 0, mode: .hold) == [.rejectStream], "hold mode rejects late host start")
    _ = m.remoteAudioStarted(reason: 0x03, mode: .toggle)
    _ = m.remoteAudioStopped(reason: 0x02)
    let g = m.generation
    _ = m.close()
    _ = m.remoteAudioStarted(reason: 0x03, mode: .toggle)
    _ = m.remoteAudioStopped(reason: 0x02)
    require(!m.acceptsHostOpenWork(generation: g), "retry from older session cannot enter a new session")
}

// Both remote modes work with either target shortcut mode.
for remote in [RemoteVoiceMode.toggle, .hold] {
    for target in [InputToolTriggerMode.toggle, .hold] {
        let h = Harness(remote: remote, target: target)
        h.press()
        require(h.controller.isActive && h.downs == 1, "\(remote)/\(target) starts immediately with one key-down")
        if remote == .toggle {
            h.release()
            require(h.controller.isActive && h.opens == 1, "toggle/\(target) remains active after first release")
            h.controller.remoteAudioStarted(reason: 0)
            h.press()
            require(h.controller.debugSnapshot.phase == "closing", "toggle/\(target) starts closing at second press")
            h.release()
        } else {
            h.release()
            require(h.controller.debugSnapshot.phase == "closing" && h.opens == 0, "hold/\(target) closes without host reopen")
        }
        h.scheduler.advance(by: 0.23)
        require(!h.controller.isActive, "\(remote)/\(target) finishes after bounded audio drain")
        require(h.downs == h.ups, "\(remote)/\(target) releases every injected key")
        require(h.downs == (target == .toggle ? 2 : 1), "\(remote)/\(target) matches target shortcut semantics")
        require(h.ended == 1, "\(remote)/\(target) emits one session-ended callback")
        h.controller.stop()
    }
}

do {
    let h = Harness(target: .hold)
    h.openResults = [.retryAfter(0.04), .sent]
    h.press()
    h.release()
    h.controller.disconnected()
    h.scheduler.advance(by: 0.08)
    require(h.opens == 1, "disconnect cancels scheduled reopen")
    require(h.downs == h.ups && !h.controller.isActive, "disconnect synchronously releases held shortcut")
    h.controller.remoteAudioStarted(reason: 0)
    require(h.downs == 1 && !h.controller.isActive, "late host response after disconnect injects no key")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold)
    h.press()
    h.configuration.triggerKey = .command
    h.controller.configurationChanged()
    require(h.events.contains("up:option") && !h.events.contains("up:command"), "settings change releases original captured key")
    require(!h.controller.isActive, "settings change closes active session")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold)
    h.press()
    h.controller.stop(reason: "sleep")
    require(h.downs == h.ups && !h.controller.isActive, "sleep cleanup releases held key before returning")
    h.press()
    require(h.downs == 1, "sleeping controller rejects physical starts")
    h.controller.start()
    h.press()
    require(h.downs == 2, "wake permits a fresh session after start")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold)
    h.monitor.emit(.unavailable)
    h.press()
    require(h.monitor.starts == 0, "custom tool does not start Doubao monitor")
    h.monitor.emit(.inactive)
    require(h.controller.isActive, "custom tool is not rejected by unrelated inactive monitor")
    h.controller.remoteAudioStopped(reason: 0xFE)
    require(!h.controller.isActive && h.downs == h.ups, "transport timeout releases held key")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold, tool: .doubao)
    h.press()
    h.monitor.emit(.active)
    h.monitor.emit(.inactive)
    require(!h.controller.isActive && h.downs == h.ups, "observed capture end releases hold shortcut")
    h.monitor.emit(.active)
    require(!h.controller.isActive, "stale target active snapshot cannot reopen closed session")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold)
    h.controller.triggerDownObserved(isSynthetic: true)
    require(!h.controller.isActive, "synthetic events are not replayed")
    h.controller.triggerDownObserved(isSynthetic: false)
    require(h.controller.isActive && h.downs == 0, "physical keyboard hold starts transport without synthetic duplicate")
    h.controller.triggerUpObserved(isSynthetic: false)
    require(!h.controller.isActive && h.downs == 0, "physical keyboard release closes without synthetic duplicate")
    h.controller.stop()
}
do {
    let h = Harness(target: .hold)
    h.openResults = [.retryAfter(0.01), .retryAfter(0.01), .failed("busy")]
    h.press()
    h.release()
    h.scheduler.advance(by: 0.1)
    require(h.opens == 3 && !h.controller.isActive, "host open retries are bounded to three attempts")
    require(h.downs == h.ups, "exhausted retries release held key")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold)
    h.press()
    h.release()
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "closing", "settings remain locked while audio tail drains")
    h.press()
    h.scheduler.advance(by: 0.16)
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "open", "old drain completion cannot close a newer session")
    require(h.events.last == "down:option", "new session's held key survives stale drain callback")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .toggle, tool: .doubao)
    h.press()
    h.monitor.emit(.active)
    h.release()
    h.monitor.emit(.inactive)
    h.scheduler.advance(by: 0.23)
    require(h.downs == 1, "target stopping during drain is not toggled back on")
    h.controller.stop()
}
do {
    var configuration = VoiceConfiguration()
    configuration.inputTool = .custom
    configuration.customBundleIdentifier = "  example.input.tool  "
    require(configuration.isValid && configuration.targetBundleIdentifier == "example.input.tool", "custom bundle identifier is normalized")
    configuration.customBundleIdentifier = "invalid bundle"
    require(!configuration.isValid, "invalid custom target is rejected")
    let data = try JSONEncoder().encode(configuration)
    let decoded = try JSONDecoder().decode(VoiceConfiguration.self, from: data)
    require(decoded == configuration, "voice configuration round-trips through Codable")
}

// A busy CI main queue can run the 120ms drain at 230ms or later. The final
// 60ms toggle pulse starts THEN, so asserting balanced keys merely because
// 230ms elapsed was incorrect. Verify both stages, including cancellation.
do {
    let h = Harness(remote: .toggle, target: .toggle)
    h.press(); h.release(); h.controller.remoteAudioStarted(reason: 0); h.press(); h.release()
    h.scheduler.stall(for: 0.23)
    h.scheduler.runReady()
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "closing"
            && h.controller.debugSnapshot.syntheticKeyDown && h.ended == 0,
            "delayed drain remains closing until final toggle key-up")
    h.scheduler.advance(by: 0.059)
    require(h.controller.debugSnapshot.syntheticKeyDown, "final pulse keeps its own 60ms deadline")
    h.scheduler.advance(by: 0.002)
    require(h.downs == h.ups && !h.controller.debugSnapshot.syntheticKeyDown
            && !h.controller.isActive && h.ended == 1,
            "delayed final pulse releases every injected key before reporting ended")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .toggle)
    h.press(); h.release()
    h.scheduler.stall(for: 1)
    h.scheduler.runReady()
    h.controller.stop(reason: "quit during final pulse")
    require(h.downs == h.ups && h.ended == 1, "quit synchronously releases delayed final pulse once")
    h.scheduler.advance(by: 1)
    require(h.downs == h.ups, "cancelled pulse callback cannot add a stale key-up")
}

for interruption in ["settings", "disconnect", "new press"] {
    let h = Harness(remote: .hold, target: .toggle)
    h.press(); h.release()
    h.scheduler.advance(by: 0.12)
    require(h.controller.isActive && h.controller.debugSnapshot.syntheticKeyDown && h.ended == 0,
            "\(interruption) starts during final toggle pulse")
    let oldDowns = h.downs
    if interruption == "settings" {
        h.configuration.triggerKey = .command
        h.controller.configurationChanged()
    } else if interruption == "disconnect" {
        h.controller.disconnected()
    } else {
        h.configuration.inputToolTriggerMode = .hold
        h.press()
    }
    require(h.ended == 1, "\(interruption) ends old session exactly once")
    require(h.downs == oldDowns + (interruption == "new press" ? 1 : 0),
            "\(interruption) never emits duplicate stop toggle")
    h.scheduler.advance(by: 0.10)
    if interruption == "new press" {
        require(h.controller.isActive && h.controller.debugSnapshot.syntheticKeyDown,
                "old final-pulse callback cannot release newer session's held key")
    } else {
        require(!h.controller.isActive && h.downs == h.ups,
                "\(interruption) leaves no held key or active session")
    }
    h.controller.stop()
    require(h.downs == h.ups, "\(interruption) cleanup balances all keys")
}
// Route acquisition must precede any synthetic target shortcut. Failed starts
// cannot accidentally toggle an idle target on during their cleanup.
for target in [InputToolTriggerMode.hold, .toggle] {
    let h = Harness(remote: .hold, target: target)
    h.routeStartSucceeds = false
    h.press(receivesPCM: false)
    require(!h.controller.isActive && h.downs == 0 && h.ups == 0,
            "failed route start injects no \(target) shortcut")
    require(h.closes > 0, "failed route start closes remote microphone")
    h.scheduler.advance(by: 5)
    require(h.downs == 0 && !h.controller.isActive, "failed route start leaves no delayed shortcut")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold)
    h.press(receivesPCM: false)
    h.scheduler.advance(by: 1.99)
    require(h.controller.isActive, "first PCM watchdog allows bounded startup grace")
    h.scheduler.advance(by: 0.02)
    require(!h.controller.isActive && h.downs == h.ups && h.events.last == "route:false",
            "missing first PCM releases key and route at startup deadline")
    h.controller.remotePCMReceived()
    require(!h.controller.isActive, "late PCM cannot revive timed-out session")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold)
    h.press(receivesPCM: false)
    h.scheduler.advance(by: 1.9)
    h.controller.remotePCMReceived()
    let statusCount = h.statuses.count
    h.controller.remotePCMReceived()
    require(h.statuses.count == statusCount, "later PCM packets do not repeat UI state publication")
    h.scheduler.advance(by: 30)
    require(h.controller.isActive && h.controller.debugSnapshot.syntheticKeyDown,
            "one real PCM packet cancels startup watchdog across natural speech pauses")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold)
    h.press(receivesPCM: false)
    h.scheduler.advance(by: 1)
    h.controller.forceClose()
    h.press(receivesPCM: false)
    h.scheduler.advance(by: 1.1)
    require(h.controller.isActive, "old first PCM deadline cannot close next session")
    h.controller.remotePCMReceived()
    h.scheduler.advance(by: 2)
    require(h.controller.isActive, "next session independently cancels its first PCM watchdog")
    h.controller.stop()
}

// Keep output through the tail and complete the final pulse before releasing
// this session's route. Main-queue delay cannot invert that ownership order.
do {
    let h = Harness(remote: .hold, target: .toggle)
    h.press()
    require(h.events.first == "route:true" && h.events.dropFirst().first == "down:option",
            "route starts before target shortcut")
    h.release()
    h.scheduler.advance(by: 0.119)
    require(!h.events.contains("route:false"), "route remains acquired during audio tail")
    h.scheduler.advance(by: 0.002)
    require(h.controller.debugSnapshot.syntheticKeyDown && !h.events.contains("route:false"),
            "route remains acquired during final toggle pulse")
    h.scheduler.advance(by: 0.06)
    require(h.events.suffix(2).elementsEqual(["up:option", "route:false"]),
            "final key-up precedes route release")
    h.controller.stop()
}

do {
    let h = Harness(remote: .hold, target: .toggle)
    h.press(); h.release()
    h.routeStopSucceeds = false
    h.scheduler.advance(by: 0.2)
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "closing"
            && h.downs == h.ups && h.ended == 0,
            "failed route cleanup keeps session closing after final key-up")
    require(h.statuses.last == "Local audio resources are still closing · retry stop",
            "failed cleanup never reports local voice closed")
    let previousDowns = h.downs
    h.press()
    require(h.controller.debugSnapshot.phase == "closing" && h.downs == previousDowns,
            "new press cannot inject shortcut while old route cleanup fails")
    h.routeStopSucceeds = true
    h.press()
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "open"
            && h.downs == previousDowns + 1 && h.ended == 1,
            "new press retries cleanup before starting replacement session")
    h.controller.stop()
}

// Post-stop target observation is read-only and never equates unavailable or
// custom-tool state with a confirmed microphone release.
for state in [DoubaoAudioStateMonitor.State.inactive, .active, .unavailable] {
    let h = Harness(remote: .hold, target: .hold, tool: .doubao)
    h.press()
    h.monitor.emit(.active)
    h.release()
    h.scheduler.advance(by: 0.13)
    require(!h.controller.isActive && h.statuses.last?.contains("not yet confirmed") == true,
            "local cleanup does not claim immediate target stop confirmation")
    let eventCount = h.events.count
    h.monitor.state = state
    h.scheduler.advance(by: 1.51)
    let expected: String
    switch state {
    case .inactive: expected = "Local voice closed · Doubao stopped recording"
    case .active: expected = "Local voice closed · warning: Doubao is still recording; stop it in Doubao"
    case .unavailable: expected = "Local voice closed · Doubao stop not confirmed"
    }
    require(h.statuses.last == expected, "post-stop \(state) snapshot reports honest target status")
    require(h.events.count == eventCount && h.downs == h.ups,
            "post-stop \(state) verification injects no recovery shortcut")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold, tool: .custom)
    h.press(); h.release()
    h.scheduler.advance(by: 2)
    require(h.statuses.last == "Local voice closed · custom tool stop not confirmed",
            "custom tool stop remains explicitly unconfirmed")
    require(h.monitor.starts == 0, "custom post-stop check never starts Doubao observer")
    h.controller.stop()
}
do {
    let h = Harness(remote: .hold, target: .hold, tool: .doubao)
    h.press(); h.monitor.emit(.active); h.release()
    h.scheduler.advance(by: 0.13)
    h.press(); h.monitor.emit(.active)
    let statusCount = h.statuses.count
    h.scheduler.advance(by: 1.5)
    require(h.controller.isActive && h.statuses.count == statusCount && h.statuses.last == "Recording",
            "previous stop confirmation cannot label a new recording session")
    h.controller.stop()
}

do {
    let h = Harness()
    h.routeStopSucceeds = false
    h.controller.disconnected()
    require(h.controller.isActive && h.controller.debugSnapshot.phase == "closing"
            && h.statuses.last == "Local audio resources are still closing · retry stop",
            "idle temporary-output cleanup failure remains closing on disconnect")
    h.routeStopSucceeds = true
    h.controller.forceClose()
    require(!h.controller.isActive && h.downs == 0, "idle cleanup retry releases without target shortcut")
    h.controller.stop()
}

runTransportVoiceTests()
runAudioResourceLeaseTests()
print("All Chromecast voice regression tests passed.")
