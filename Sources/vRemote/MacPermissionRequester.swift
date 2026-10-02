import ApplicationServices
import CoreBluetooth
import CoreGraphics
import Foundation

/// Invoke only from a deliberate permission button, never a refresh/timer.
@MainActor
final class MacPermissionRequester {
    private var gate = PermissionRequestGate()
    // Keep the manager alive while the system Bluetooth prompt is pending.
    // No scan, connection, recording, or grant is performed by this helper.
    private var bluetoothAuthorizationManager: CBCentralManager?

    func request(_ permission: RequestablePermission) -> PermissionRequestResult {
        let result = gate.prepare(permission, authorization: authorization(for: permission))
        guard result == .requested else { return result }

        switch permission {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
        case .bluetooth:
            // CoreBluetooth has no separate requestAuthorization method.
            // Creating a manager requests access when it is not determined.
            bluetoothAuthorizationManager = CBCentralManager(delegate: nil, queue: .main)
        }

        // AX/Bluetooth prompts can resolve asynchronously. Never interpret
        // "request sent" as permission granted; the UI re-reads system state.
        return authorization(for: permission) == .authorized ? .alreadyGranted : .requested
    }

    private func authorization(for permission: RequestablePermission) -> PermissionAuthorization {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .authorized : .notGranted
        case .inputMonitoring:
            return CGPreflightListenEventAccess() ? .authorized : .notGranted
        case .bluetooth:
            switch CBManager.authorization {
            case .allowedAlways: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .unknown
            }
        }
    }
}
