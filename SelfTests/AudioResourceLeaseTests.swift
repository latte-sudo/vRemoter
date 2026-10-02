import Foundation

func runAudioResourceLeaseTests() {
    func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), "AudioResourceLease: \(message)")
    }
    var lease = AudioResourceLease()
    check(lease.current == nil, "idle has no device owner")
    check(!lease.shouldCaptureMac(enabled: true, mixActive: false), "enabled Mac remains idle outside session")
    let tone = lease.acquire(.testTone)
    check(!lease.shouldCaptureMac(enabled: true, mixActive: true), "tone never owns capture")
    check(lease.release(tone), "tone completion releases output")
    check(!lease.release(tone), "duplicate completion is harmless")
    let interruptedTone = lease.acquire(.testTone)
    lease.invalidate()
    let session = lease.acquire(.session)
    check(!lease.release(interruptedTone), "late tone completion cannot close voice session")
    check(lease.current == session, "session remains owned")
    check(!lease.shouldCaptureMac(enabled: false, mixActive: true), "Mac defaults disabled")
    check(lease.shouldCaptureMac(enabled: true, mixActive: true), "enabled active session captures")
    check(!lease.shouldCaptureMac(enabled: true, mixActive: false), "session stop gates pending capture start")
    lease.invalidate()
    check(!lease.shouldCaptureMac(enabled: true, mixActive: true), "route loss revokes capture")
    check(!lease.release(session), "late session cleanup is stale after invalidation")
    let oldTone = lease.acquire(.testTone)
    let newTone = lease.acquire(.testTone)
    check(!lease.release(oldTone), "old tone timeout cannot stop newer tone")
    check(lease.release(newTone), "latest tone closes")
    for _ in 0..<100 {
        let owner = lease.acquire(.session)
        check(lease.release(owner), "repeated session releases exactly its output")
        check(lease.current == nil, "repeated session returns idle")
    }
    print("PASS: audio resource lease policy")
}
