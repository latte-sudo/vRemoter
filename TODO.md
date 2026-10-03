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
- [ ] Decide how to keep reconnection stable if the system Bluetooth name changes;
  the current BLE saved-UUID path also validates the `Chromecast Remote` name hint

This is recorded for later design and implementation only. The current change
adds mapping actions, continuous scrolling and an app-local display name; it does
not implement multi-device pairing, host switching, identity binding, per-device
profiles or system Bluetooth renaming. See [display-name scope](docs/NATIVE_INTERFACE_IMPLEMENTATION.md#remote-display-name-and-identity).

## Deferred: final product identity and coordinated migration

- [ ] Choose the final product name and the correct person/company attribution
  for new contributions; Remote Voice Utility / 遥控器语音工具 / 遙控器語音工具
  are descriptive placeholders. Do not replace inherited copyright holders
- [ ] Confirm the final icon and rights/physical accuracy of the supplied remote
  photo. The generic generated icon replaces inherited branding; native localized
  permission illustrations replace the old screenshots
- [ ] Choose an owner-controlled bundle/signing namespace and installation policy
  (upgrade versus side-by-side), then coordinate package/target/executable/app
  paths, launch-agent label, installer receipt and distribution filenames
- [ ] Design and test preferences, archive and local-data migration before changing
  existing `vRemoter.*` / `vRemote` keys or paths. Preserve custom mappings, language,
  appearance, saved routes, old imports, unrelated data and user-created files
- [ ] Test permission reauthorization, signatures, login-item removal/replacement,
  upgrade/rollback and coexistence. A new display name alone must not imply those
  technical identities changed or that macOS grants survive
- [ ] Resolve the separate BlackHole source/license/distribution gate before any
  driver migration or PKG release; preserve device UID/route compatibility until
  an explicitly tested migration exists

See the [field-level inventory and contribution/license boundaries](docs/PROJECT_OWNERSHIP_AND_LICENSES.md).
This list authorizes no installation, user-data cleanup, new author assignment,
relicense, source-notice removal or release approval.
