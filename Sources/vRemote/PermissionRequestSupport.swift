import Foundation

/// Only permissions used by the Chromecast-only release. Receiving PCM over
/// Bluetooth does not require capturing the Mac's microphone.
enum RequestablePermission: CaseIterable, Hashable {
    case bluetooth
    case accessibility
    case inputMonitoring
}

enum PermissionAuthorization: Equatable {
    case authorized
    case notDetermined
    // Accessibility and Input Monitoring expose a Boolean preflight result,
    // so false must not be presented as a known previous denial.
    case notGranted
    case denied
    case restricted
    case unknown
}

enum PermissionRequestResult: Equatable {
    case alreadyGranted
    case requested
    case openSettings
    case restricted
    case unavailable
}

/// A request is an explicit user action. Reading permission status never uses
/// this gate, and repeated clicks do not continuously re-open system prompts.
struct PermissionRequestGate {
    private(set) var attempted: Set<RequestablePermission> = []

    mutating func prepare(
        _ permission: RequestablePermission,
        authorization: PermissionAuthorization
    ) -> PermissionRequestResult {
        switch authorization {
        case .authorized: return .alreadyGranted
        case .denied: return .openSettings
        case .restricted: return .restricted
        case .unknown: return .unavailable
        case .notDetermined, .notGranted:
            guard attempted.insert(permission).inserted else { return .openSettings }
            return .requested
        }
    }
}
