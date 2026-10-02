/// Platform-neutral physical modifier edge tracking. Synthetic shortcuts must
/// never feed back into the voice controller that posted them.
struct KeyboardTriggerState {
    enum EventKind { case keyDown, keyUp, flagsChanged }
    enum Edge: Equatable { case down, up }

    private var keysDown = Set<Int64>()

    mutating func reset() { keysDown.removeAll() }

    mutating func observe(
        kind: EventKind,
        keyCode: Int64,
        triggerKeyCodes: Set<Int64>,
        triggerFlagIsSet: Bool,
        isSynthetic: Bool
    ) -> Edge? {
        guard !isSynthetic, triggerKeyCodes.contains(keyCode) else { return nil }
        let isDown: Bool
        switch kind {
        case .keyDown:
            isDown = true
        case .keyUp:
            isDown = false
        case .flagsChanged:
            // The aggregate modifier flag remains set when the other physical
            // key is held. Track each side separately to detect its release.
            if keysDown.contains(keyCode) {
                isDown = false
            } else {
                guard triggerFlagIsSet else { return nil }
                isDown = true
            }
        }
        if isDown {
            return keysDown.insert(keyCode).inserted ? .down : nil
        }
        return keysDown.remove(keyCode) != nil ? .up : nil
    }
}
