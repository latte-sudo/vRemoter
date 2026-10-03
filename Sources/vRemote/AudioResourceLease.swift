// Pure ownership policy shared by AudioPipe and hardware-independent tests.
// The caller serializes transitions and performs device operations outside its
// render lock. A token can release only the exact lease that issued it.
struct AudioResourceLease {
    enum Owner: Equatable { case session, testTone }
    struct Token: Equatable {
        let generation: UInt64
        let owner: Owner
    }
    private(set) var current: Token?
    private var generation: UInt64 = 0

    mutating func acquire(_ owner: Owner) -> Token {
        generation &+= 1
        let token = Token(generation: generation, owner: owner)
        current = token
        return token
    }

    @discardableResult
    mutating func release(_ token: Token) -> Bool {
        guard current == token else { return false }
        current = nil
        return true
    }

    mutating func invalidate() {
        generation &+= 1
        current = nil
    }

    func shouldCaptureMac(enabled: Bool, mixActive: Bool) -> Bool {
        enabled && mixActive && current?.owner == .session
    }
}
