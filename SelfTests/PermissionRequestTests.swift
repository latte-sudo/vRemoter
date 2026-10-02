import Foundation

@main
struct PermissionRequestTests {
    static func main() {
        for permission in RequestablePermission.allCases {
            var gate = PermissionRequestGate()
            precondition(gate.prepare(permission, authorization: .authorized) == .alreadyGranted)
            precondition(gate.attempted.isEmpty, "preauthorized apps must not request")
            precondition(gate.prepare(permission, authorization: .denied) == .openSettings)
            precondition(gate.attempted.isEmpty, "denied access must direct to settings")
            precondition(gate.prepare(permission, authorization: .restricted) == .restricted)
            precondition(gate.prepare(permission, authorization: .unknown) == .unavailable)
            precondition(gate.attempted.isEmpty, "restrictions and unknown states must not request")
            precondition(gate.prepare(permission, authorization: .notDetermined) == .requested)
            precondition(gate.attempted == [permission])
            precondition(gate.prepare(permission, authorization: .notDetermined) == .openSettings,
                         "a second pending click must not re-open a prompt")
            precondition(gate.prepare(permission, authorization: .notGranted) == .openSettings)
            precondition(gate.prepare(permission, authorization: .authorized) == .alreadyGranted,
                         "granting in Settings must override the earlier attempt")
            precondition(gate.prepare(permission, authorization: .denied) == .openSettings)
        }
        var gate = PermissionRequestGate()
        for permission in RequestablePermission.allCases {
            precondition(gate.prepare(permission, authorization: .notGranted) == .requested,
                         "Boolean-only preflight must allow one explicit request per permission")
        }
        precondition(gate.attempted.count == 3, "one permission must not consume another's request")
        print("PASS: permission request gating, prior denial, restrictions, duplicate clicks and external grants")
    }
}
