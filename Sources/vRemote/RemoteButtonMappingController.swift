import Foundation

/// Owns ordinary-button actions and their timer, independently of HID handles.
/// All entry points and scheduled callbacks run on the main thread. An injected
/// clock/scheduler/output lets lifecycle tests exercise real dispatch safely.
final class RemoteButtonMappingController {
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> (() -> Void)
    typealias PostAction = (RemoteMappingAction, Bool, Bool) -> Void

    private struct ButtonSession {
        let actions: [RemoteButtonGesture: RemoteMappingAction]
        var recognizer: RemoteButtonGestureRecognizer
    }

    private let store: RemoteMappingStore
    private let now: () -> TimeInterval
    private let schedule: Schedule
    private let post: PostAction
    private var mappingObserver: NSObjectProtocol?
    private var sessions: [String: ButtonSession] = [:]
    private var pressedButtons = Set<String>()
    private var cancelTimer: (() -> Void)?
    private var timerGeneration: UInt64 = 0
    private(set) var isRunning = false

    var hasScheduledTimer: Bool { cancelTimer != nil }
    var activeSessionCount: Int { sessions.count }

    init(
        store: RemoteMappingStore = .shared,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        schedule: @escaping Schedule = { delay, callback in
            let timer = Timer(timeInterval: delay, repeats: false) { _ in callback() }
            RunLoop.main.add(timer, forMode: .common)
            return { timer.invalidate() }
        },
        post: PostAction? = nil
    ) {
        self.store = store
        self.now = now
        self.schedule = schedule
        self.post = post ?? { action, isDown, isRepeat in
            store.post(action: action, isDown: isDown, isRepeat: isRepeat)
        }
    }

    deinit { stop() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        mappingObserver = NotificationCenter.default.addObserver(
            forName: RemoteMappingStore.didChangeNotification, object: store, queue: .main
        ) { [weak self] _ in self?.cancelHeldActions() }
    }

    func stop() {
        isRunning = false
        disconnected()
        if let mappingObserver {
            NotificationCenter.default.removeObserver(mappingObserver)
            self.mappingObserver = nil
        }
    }

    func disconnected() {
        cancelHeldActions()
        pressedButtons.removeAll()
    }

    /// Settings edits and sleep cancel immediately, but keep physical latches:
    /// duplicate down reports cannot restart scrolling until release/new press.
    func cancelHeldActions() {
        invalidateTimer()
        let oldSessions = sessions
        sessions.removeAll()
        for var session in oldSessions.values {
            dispatch(session.recognizer.cancel(), actions: session.actions)
        }
    }

    func handle(buttonID: String, isDown: Bool) {
        guard isRunning else { return }
        if isDown {
            guard pressedButtons.insert(buttonID).inserted, store.isEnabled(.chromecast),
                  let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == buttonID }),
                  button.remappable, !button.voiceControlled else { return }
            if sessions[buttonID] == nil {
                sessions[buttonID] = ButtonSession(
                    actions: Dictionary(uniqueKeysWithValues: RemoteButtonGesture.allCases.map {
                        ($0, store.action(for: button, remote: .chromecast, gesture: $0))
                    }),
                    recognizer: RemoteButtonGestureRecognizer(configuration: store.gestureConfiguration(for: button, remote: .chromecast))
                )
            }
        } else {
            pressedButtons.remove(buttonID)
        }
        guard var session = sessions[buttonID] else { return }
        let events = isDown ? session.recognizer.press(at: now()) : session.recognizer.release(at: now())
        sessions[buttonID] = session.recognizer.isIdle ? nil : session
        dispatch(events, actions: session.actions)
        scheduleTimer()
    }

    private func dispatch(_ events: [RemoteGestureEvent], actions: [RemoteButtonGesture: RemoteMappingAction]) {
        for event in events {
            switch event {
            case .keyDown, .keyUp, .repeatKeyDown:
                if let action = actions[.click] { post(action, event != .keyUp, event == .repeatKeyDown) }
            case .longPressDown, .longPressUp, .repeatLongPress:
                if let action = actions[.longPress] { post(action, event != .longPressUp, event == .repeatLongPress) }
            case .trigger(let gesture):
                guard let action = actions[gesture] else { continue }
                post(action, true, false)
                post(action, false, false)
            }
        }
    }

    private func invalidateTimer() {
        timerGeneration &+= 1
        cancelTimer?()
        cancelTimer = nil
    }

    private func scheduleTimer() {
        invalidateTimer()
        guard isRunning, let deadline = sessions.values.compactMap({ $0.recognizer.nextDeadline }).min() else { return }
        let generation = timerGeneration
        cancelTimer = schedule(max(0.001, deadline - now())) { [weak self] in
            guard let self, self.isRunning, self.timerGeneration == generation else { return }
            self.advance()
        }
    }

    private func advance() {
        let time = now()
        for buttonID in Array(sessions.keys) {
            guard var session = sessions[buttonID] else { continue }
            let events = session.recognizer.advance(to: time)
            sessions[buttonID] = session.recognizer.isIdle ? nil : session
            dispatch(events, actions: session.actions)
        }
        scheduleTimer()
    }
}
