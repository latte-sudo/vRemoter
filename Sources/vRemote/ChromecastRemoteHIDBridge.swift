import Foundation
import IOKit.hid

private func chromecastRemoteMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidMatch(result: result, device: device)
}

private func chromecastRemoteRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceDidRemove(device)
}

private func chromecastRemoteInputReport(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, result == kIOReturnSuccess, reportLength > 0 else {
        return
    }
    Unmanaged<ChromecastRemoteHIDBridge>
        .fromOpaque(context)
        .takeUnretainedValue()
        .handleReport(
            reportID: reportID,
            data: Data(bytes: report, count: reportLength)
        )
}

/// Connection monitor for the Google Chromecast Remote HID interface.
///
/// Its voice key does not expose a dependable HID key-down usage on macOS;
/// voice gestures are therefore handled by the remote's ATVV control stream.
final class ChromecastRemoteHIDBridge {
    static let vendorID = 0x18D1
    static let productID = 0x9450

    var onConnectionChanged: ((Bool) -> Void)?
    var onButtonObserved: ((String) -> Void)?

    private var manager: IOHIDManager?
    private var activeDevice: IOHIDDevice?
    private var remappingEnabled = RemoteMappingStore.shared.isEnabled(.chromecast)
    private var lastButtonID: String?
    private var gestureTimer: Timer?
    private var mappingObserver: NSObjectProtocol?
    private var sessions: [String: ButtonSession] = [:]

    private struct ButtonSession {
        let button: RemoteButtonDefinition
        let actions: [RemoteButtonGesture: RemoteMappingAction]
        var recognizer: RemoteButtonGestureRecognizer
    }

    func start() {
        stop()
        mappingObserver = NotificationCenter.default.addObserver(
            forName: RemoteMappingStore.didChangeNotification,
            object: RemoteMappingStore.shared,
            queue: .main
        ) { [weak self] _ in
            // Never let deferred clicks execute after a settings change, and
            // release the old press-time mapping before accepting a new one.
            self?.cancelGestures()
        }
        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        IOHIDManagerSetDeviceMatching(
            manager,
            [
                kIOHIDVendorIDKey: Self.vendorID,
                kIOHIDProductIDKey: Self.productID,
            ] as CFDictionary
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            chromecastRemoteMatched,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            chromecastRemoteRemoved,
            context
        )
        IOHIDManagerRegisterInputReportCallback(
            manager,
            chromecastRemoteInputReport,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        // Open the manager exclusively, not just one IOHIDDevice returned by
        // the match callback. The remote exposes more than one HID
        // collection; seizing only the first collection still lets its media
        // usage reach macOS (for example Select can launch Apple Music).
        let openOptions = remappingEnabled
            ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
            : IOOptionBits(kIOHIDOptionsTypeNone)
        let result = IOHIDManagerOpen(manager, openOptions)
        guard result == kIOReturnSuccess else {
            print(
                "[CAST-HID] manager open failed: " +
                String(format: "0x%08X", UInt32(bitPattern: result))
            )
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
            return
        }
        self.manager = manager
        print("[CAST-HID] waiting for Chromecast Remote")
    }

    func stop() {
        cancelGestures()
        if let mappingObserver {
            NotificationCenter.default.removeObserver(mappingObserver)
            self.mappingObserver = nil
        }
        activeDevice = nil
        lastButtonID = nil
        onConnectionChanged?(false)

        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    func setRemappingEnabled(_ enabled: Bool) {
        guard remappingEnabled != enabled else { return }
        remappingEnabled = enabled
        start()
    }

    fileprivate func deviceDidMatch(
        result: IOReturn,
        device: IOHIDDevice
    ) {
        guard result == kIOReturnSuccess, activeDevice == nil else { return }
        // IOHIDManagerOpen already opened every current and future matching
        // HID collection with the requested access mode.
        activeDevice = device
        onConnectionChanged?(true)
        print(
            "[CAST-HID] connected VID=0x18d1 PID=0x9450 " +
            "mode=\(remappingEnabled ? "remap" : "observe")"
        )
    }

    fileprivate func deviceDidRemove(_ device: IOHIDDevice) {
        guard let activeDevice, CFEqual(activeDevice, device) else { return }
        cancelGestures()
        lastButtonID = nil
        self.activeDevice = nil
        onConnectionChanged?(false)
        print("[CAST-HID] disconnected")
    }

    fileprivate func handleReport(reportID: UInt32, data: Data) {
        guard reportID == 0x01 else { return }
        let payload = data.first == UInt8(truncatingIfNeeded: reportID)
            ? Data(data.dropFirst())
            : data
        guard let usage = payload.first else { return }

        if usage == 0 {
            guard let buttonID = lastButtonID else { return }
            lastButtonID = nil
            apply(buttonID: buttonID, isDown: false)
            return
        }

        let buttonID = String(format: "%02X", usage)
        guard lastButtonID != buttonID else { return }
        if let previous = lastButtonID {
            apply(buttonID: previous, isDown: false)
        }
        lastButtonID = buttonID
        onButtonObserved?(buttonID)
        apply(buttonID: buttonID, isDown: true)
    }

    private func apply(buttonID: String, isDown: Bool) {
        guard remappingEnabled,
              let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == buttonID }),
              button.remappable, !button.voiceControlled
        else { return }

        let store = RemoteMappingStore.shared
        if isDown, sessions[buttonID] == nil {
            let actions = Dictionary(uniqueKeysWithValues: RemoteButtonGesture.allCases.map {
                ($0, store.action(for: button, remote: .chromecast, gesture: $0))
            })
            sessions[buttonID] = ButtonSession(
                button: button,
                actions: actions,
                recognizer: RemoteButtonGestureRecognizer(
                    configuration: store.gestureConfiguration(for: button, remote: .chromecast)
                )
            )
        }
        guard var session = sessions[buttonID] else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let events = isDown
            ? session.recognizer.press(at: now)
            : session.recognizer.release(at: now)
        sessions[buttonID] = session.recognizer.isIdle ? nil : session
        dispatch(events, session: session)
        scheduleGestureTimer()
    }

    private func dispatch(_ events: [RemoteGestureEvent], session: ButtonSession) {
        let store = RemoteMappingStore.shared
        for event in events {
            switch event {
            case .keyDown, .keyUp, .repeatKeyDown:
                guard let action = session.actions[.click] else { continue }
                store.post(action: action, isDown: event != .keyUp, isRepeat: event == .repeatKeyDown)
            case .trigger(let gesture):
                guard let action = session.actions[gesture] else { continue }
                store.post(action: action, isDown: true)
                store.post(action: action, isDown: false)
                print("[CAST-MAP] \(session.button.title) \(gesture.rawValue) -> \(action.title)")
            }
        }
    }

    private func scheduleGestureTimer() {
        gestureTimer?.invalidate()
        gestureTimer = nil
        guard let deadline = sessions.values.compactMap({ $0.recognizer.nextDeadline }).min() else { return }
        let delay = max(0.001, deadline - ProcessInfo.processInfo.systemUptime)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.advanceGestures()
        }
        // Common modes keep releases/gesture deadlines responsive during menus.
        RunLoop.main.add(timer, forMode: .common)
        gestureTimer = timer
    }

    private func advanceGestures() {
        let now = ProcessInfo.processInfo.systemUptime
        for buttonID in Array(sessions.keys) {
            guard var session = sessions[buttonID] else { continue }
            let events = session.recognizer.advance(to: now)
            sessions[buttonID] = session.recognizer.isIdle ? nil : session
            dispatch(events, session: session)
        }
        scheduleGestureTimer()
    }

    private func cancelGestures() {
        gestureTimer?.invalidate()
        gestureTimer = nil
        for var session in sessions.values {
            let events = session.recognizer.cancel()
            dispatch(events, session: session)
        }
        sessions.removeAll()
    }
}
