import Foundation

/// Raw ATVV control packets run through the production parser and lifecycle,
/// then the real session controller. CoreBluetooth delivery and CoreAudio are
/// adapters only; this is a regression simulation, not a hardware claim.
private final class TransportHarness {
    let app = Harness()
    let wire = ATVVProtocol()
    var transport = ATVVStreamLifecycle(tracksPhysicalVoiceEdges: true)
    var decodedFrames = 0
    var decoderStarts = 0
    var openCommands = 0
    var closeCommands = 0

    init() {
        try! wire.acceptCapabilities(ATVVCapabilities(
            version: .v10, codecs: 2, interactionModel: 0, frameSize: 20
        ))
        app.controller.onMicrophoneOpenRequested = { [unowned self] _ in
            if self.transport.isClosing && self.transport.isStreaming { return .retryAfter(0.5) }
            guard !self.transport.isStreaming else { return .alreadyStreaming }
            self.wire.prepareForAudioStream()
            self.transport.requestedOpen()
            self.openCommands += 1
            return .sent
        }
        app.controller.onMicrophoneCloseRequested = { [unowned self] in
            self.closeCommands += 1
            self.transport.requestedClose()
        }
    }

    func receive(_ bytes: [UInt8]) {
        switch wire.parseControl(Data(bytes)) {
        case .audioStart(let reason, let codec, let sid):
            guard transport.start(reason: reason, streamID: sid) else { return }
            wire.beginAudioStream(codec: codec)
            decoderStarts += 1
            app.controller.remoteAudioStarted(reason: reason)
        case .audioStop(let reason):
            switch transport.stop(reason: reason) {
            case .ignore: return
            case .releaseOnly: app.controller.remoteAudioStopped(reason: reason)
            case .finishLocally:
                transport.finish()
                wire.endAudioStream()
            case .finishStream:
                transport.finish()
                wire.endAudioStream()
                app.controller.remoteAudioStopped(reason: reason)
            }
        default: break
        }
    }

    func pcm() {
        guard transport.acceptsPCM,
              let frame = wire.decodeAudio(Data([0x11, 0x22])), !frame.samples.isEmpty else { return }
        decodedFrames += 1
        app.controller.remotePCMReceived()
    }

    func start(_ sid: UInt8) { receive([0x04, 0x03, 0x02, sid]); pcm() }
    func release() { receive([0x00, 0x02]) }
    func hostStart(_ sid: UInt8) { receive([0x04, 0x00, 0x02, sid]); pcm() }
}

func runTransportVoiceTests() {
    let h = TransportHarness()
    for cycle in 0..<20 {
        let sid = UInt8(cycle * 3)
        h.start(sid)
        let downCount = h.app.downs
        let decoderCount = h.decoderStarts
        h.receive([0x04, 0x03, 0x02, sid])
        require(h.app.downs == downCount && h.decoderStarts == decoderCount,
                "wire duplicate START does not retoggle or reset decoder (cycle \(cycle))")
        h.release()
        require(h.transport.awaitingHostStart && h.openCommands == cycle + 1,
                "wire physical release requests exactly one continuation (cycle \(cycle))")
        h.release()
        h.hostStart(sid + 1)
        h.release()
        require(h.app.controller.isActive && h.transport.acceptsPCM,
                "duplicate release cannot kill host continuation (cycle \(cycle))")
        h.start(sid + 2) // deliberate second click closes the recording
        let closingGeneration = h.transport.generation
        let framesAtClose = h.decodedFrames
        h.pcm()
        require(h.decodedFrames == framesAtClose && !h.transport.acceptsPCM,
                "MIC_CLOSE immediately gates late PCM (cycle \(cycle))")
        h.receive([0x00, 0x00]) // MIC_CLOSE acknowledged BEFORE physical release
        h.app.scheduler.advance(by: 0.3)
        require(!h.app.controller.isActive && h.app.controller.debugSnapshot.physicalButtonDown,
                "closed transport retains pending physical release (cycle \(cycle))")
        h.release() // formerly dropped by BLEBridge's wasStreaming check
        require(!h.app.controller.debugSnapshot.physicalButtonDown,
                "idle wire release unlatches next physical cycle (cycle \(cycle))")
        h.hostStart(sid + 1) // stale host response from the old stream
        require(!h.app.controller.isActive && !h.transport.acceptsPCM,
                "stale host START cannot restart closed route (cycle \(cycle))")
        require(!h.transport.acceptsCloseTimeout(generation: closingGeneration),
                "old close timeout cannot act after transport generation changes")
        require(h.app.downs == (cycle + 1) * 2 && h.app.downs == h.app.ups,
                "each physical toggle cycle has one balanced start/end shortcut")
    }
    // New physical activity before an old close deadline remains authoritative.
    h.start(100)
    h.release(); h.hostStart(101); h.start(102)
    let oldGeneration = h.transport.generation
    h.release()
    h.app.scheduler.advance(by: 0.3)
    h.start(103)
    require(h.transport.acceptsPCM && h.app.controller.isActive
            && !h.transport.acceptsCloseTimeout(generation: oldGeneration),
            "new stream survives a queued previous-session close timeout")
    h.app.controller.stop()
    h.transport.reset()
    require(!h.transport.physicalButtonDown && !h.transport.acceptsPCM,
            "connection reset clears physical and PCM ownership")

    let keyboard = TransportHarness()
    keyboard.start(1)
    keyboard.app.controller.forceClose()
    keyboard.app.controller.triggerDownObserved(isSynthetic: false)
    require(keyboard.app.controller.isActive
            && keyboard.app.controller.debugSnapshot.awaitingHostOpen,
            "keyboard replacement waits for closing BLE stream, not false alreadyStreaming")
    keyboard.receive([0x00, 0x00])
    require(keyboard.app.controller.isActive,
            "previous close acknowledgement cannot cancel pending keyboard session")
    keyboard.release()
    keyboard.app.scheduler.advance(by: 0.51)
    keyboard.hostStart(2)
    require(keyboard.transport.acceptsPCM && keyboard.app.controller.isActive
            && !keyboard.app.controller.debugSnapshot.awaitingHostOpen,
            "keyboard replacement opens after old close acknowledgement")
    keyboard.app.controller.stop()
}
