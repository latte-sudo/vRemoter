# TODO

## Deferred: remote ↔ computer identity binding

- [ ] Design explicit identity binding when several physical Chromecast remotes
  or several computers are present, so the intended remote controls the intended
  Mac rather than relying only on a model's VID/PID
- [ ] Define device selection, stable per-device identity, HID/BLE association,
  reconnect behavior, reassignment/unbinding, and what to do when identity is
  missing or ambiguous
- [ ] Decide how existing model-level mappings migrate to per-device profiles
  without losing custom settings, then test simultaneous devices and reconnects

This is recorded for later design and implementation only. The current change
adds mapping actions and continuous scrolling; it does not implement multi-device
pairing, host switching, identity binding or per-device profiles.
