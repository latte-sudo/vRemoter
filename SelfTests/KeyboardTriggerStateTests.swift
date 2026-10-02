import Foundation

@main
struct KeyboardTriggerStateTests {
    static func main() {
        var state = KeyboardTriggerState()
        let option: Set<Int64> = [0x3A, 0x3D]
        var checks = 0
        func expect(
            _ kind: KeyboardTriggerState.EventKind,
            _ code: Int64,
            flag: Bool = false,
            synthetic: Bool = false,
            keys: Set<Int64>? = nil,
            _ edge: KeyboardTriggerState.Edge?
        ) {
            let observed = state.observe(kind: kind, keyCode: code,
                                         triggerKeyCodes: keys ?? option,
                                         triggerFlagIsSet: flag, isSynthetic: synthetic)
            precondition(observed == edge, "unexpected physical keyboard edge")
            checks += 1
        }
        // Normal modifiers, unrelated keys, duplicate DOWN and orphan UP.
        expect(.flagsChanged, 0x3A, nil)
        expect(.flagsChanged, 0x3A, flag: true, .down)
        expect(.keyDown, 0x3A, flag: true, nil)
        expect(.keyDown, 0x00, flag: true, nil)
        expect(.flagsChanged, 0x3A, .up)
        expect(.keyUp, 0x3A, nil)
        // Some input methods deliver the DOWN as keyDown and UP as flagsChanged.
        expect(.keyDown, 0x3A, .down)
        expect(.flagsChanged, 0x3A, .up)
        // Releasing one Option while the other is down leaves the aggregate flag set.
        expect(.flagsChanged, 0x3A, flag: true, .down)
        expect(.flagsChanged, 0x3D, flag: true, .down)
        expect(.flagsChanged, 0x3A, flag: true, .up)
        expect(.flagsChanged, 0x3D, .up)
        // Synthetic app-generated shortcuts neither trigger nor alter physical state.
        expect(.keyDown, 0x3A, synthetic: true, nil)
        expect(.keyUp, 0x3A, nil)
        expect(.keyDown, 0x3A, .down)
        expect(.flagsChanged, 0x3A, synthetic: true, nil)
        expect(.keyUp, 0x3A, synthetic: true, nil)
        expect(.keyUp, 0x3A, .up)
        // Stop/restart or configuration changes discard stale held-key state.
        expect(.keyDown, 0x3A, .down)
        state.reset()
        expect(.keyUp, 0x3A, nil)
        expect(.flagsChanged, 0x37, flag: true, keys: [0x37, 0x36], .down)
        expect(.keyDown, 0x3A, flag: true, keys: [0x37, 0x36], nil)
        expect(.flagsChanged, 0x37, keys: [0x37, 0x36], .up)
        for key in [Int64(0x3B), 0x38, 0x3F] {
            state.reset()
            expect(.flagsChanged, key, flag: true, keys: [key], .down)
            expect(.flagsChanged, key, keys: [key], .up)
        }
        print("PASS: \(checks) keyboard trigger state regressions")
    }
}
