import Foundation

enum InputTriggerKey: String, Codable { case option }
enum AppStorage { static var inputTriggerKey = InputTriggerKey.option }

@main
struct VoiceApplicationLauncherTests {
    static func main() throws {
        func success(_ result: Result<VoiceApplicationLaunchSuccess, VoiceApplicationLaunchError>?) -> VoiceApplicationLaunchSuccess {
            guard case .success(let value) = result else { preconditionFailure("expected success") }
            return value
        }
        let url = URL(fileURLWithPath: "/Applications/Voice.app")
        var resolvedIDs: [String] = []
        var opened: [URL] = []
        var pending: ((Result<Bool, Error>) -> Void)?
        var environment = VoiceApplicationLaunchEnvironment(
            registeredApplication: { resolvedIDs.append($0); return url },
            runningApplication: { _ in nil },
            isValidApplication: { candidate, _ in candidate == url },
            exists: { $0 == url },
            activateRunningApplication: { _ in false },
            openApplication: { target, completion in opened.append(target); pending = completion },
            homeDirectory: URL(fileURLWithPath: "/Users/test")
        )
        var outcome: Result<VoiceApplicationLaunchSuccess, VoiceApplicationLaunchError>?
        VoiceApplicationLauncher(environment: environment).launch(configuration: VoiceConfiguration()) { outcome = $0 }
        precondition(resolvedIDs == [VoiceApplicationLauncher.doubaoSettingsBundleIdentifier])
        precondition(outcome == nil && opened == [url], "must await asynchronous launch completion")
        pending?(.success(true))
        precondition(success(outcome).activated == true)

        // A system failure reaches the user instead of reporting launch success.
        outcome = nil
        VoiceApplicationLauncher(environment: environment).launch(configuration: VoiceConfiguration()) { outcome = $0 }
        pending?(.failure(NSError(domain: "LaunchTest", code: 9, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])))
        guard case .failure(.launchFailed(let detail)) = outcome else { preconditionFailure("missing launch error") }
        precondition(detail == "Permission denied")

        // Already-running apps activate without relaunching.
        environment.activateRunningApplication = { _ in true }
        opened = []
        VoiceApplicationLauncher(environment: environment).launch(configuration: VoiceConfiguration()) { outcome = $0 }
        precondition(opened.isEmpty)
        precondition(success(outcome).activated == true)

        // A selected application works without LaunchServices registration or an ID.
        var custom = VoiceConfiguration(inputTool: .custom, customApplicationPath: url.path)
        environment.registeredApplication = { _ in nil }
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        precondition(success(outcome).applicationURL == url)

        environment.isValidApplication = { _, _ in false }
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        guard case .failure(.invalidApplication) = outcome else { preconditionFailure("invalid selected bundle accepted") }
        custom.customApplicationPath = "/bin/sh"
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        guard case .failure(.invalidConfiguration) = outcome else { preconditionFailure("arbitrary executable accepted") }
        custom.customApplicationPath = "/Applications/../Bad.app"
        precondition(!custom.isValid)

        custom = VoiceConfiguration(inputTool: .custom, customBundleIdentifier: "example.voice")
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        guard case .failure(.notFound) = outcome else { preconditionFailure("missing app not reported") }

        // A moved app is found via its running process even if registration is absent.
        custom.customApplicationPath = "/Old/Voice.app"
        environment.isValidApplication = { candidate, _ in candidate == url }
        environment.runningApplication = { _ in url }
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        precondition(success(outcome).applicationURL == url)

        // Launching an input method must report when there is no foreground UI.
        environment.activateRunningApplication = { _ in false }
        VoiceApplicationLauncher(environment: environment).launch(configuration: custom) { outcome = $0 }
        pending?(.success(false))
        precondition(success(outcome).activated == false)

        // The verified nested Doubao settings app is available even without an
        // entry in LaunchServices; reject a stale registered URL before fallback.
        let settingsURL = URL(fileURLWithPath: "/Library/Input Methods/DoubaoIme.app/Contents/DoubaoImeSettings.app")
        environment.runningApplication = { _ in nil }
        environment.registeredApplication = { _ in URL(fileURLWithPath: "/Applications/Stale.app") }
        environment.isValidApplication = { candidate, identifier in
            candidate == settingsURL && identifier == VoiceApplicationLauncher.doubaoSettingsBundleIdentifier
        }
        environment.activateRunningApplication = { _ in true }
        VoiceApplicationLauncher(environment: environment).launch(configuration: VoiceConfiguration()) { outcome = $0 }
        precondition(success(outcome).applicationURL == settingsURL)

        // A settings bundle with an unexpected identifier must not be launched.
        environment.isValidApplication = { _, _ in false }
        VoiceApplicationLauncher(environment: environment).launch(configuration: VoiceConfiguration()) { outcome = $0 }
        guard case .failure(.notFound) = outcome else { preconditionFailure("invalid preset accepted") }

        // Legacy v1 JSON is accepted, while wrong types still fail archive validation.
        let legacy = Data(#"{"remoteVoiceMode":"toggle","inputToolTriggerMode":"hold","inputTool":"custom","customBundleIdentifier":"example.voice","triggerKey":"option"}"#.utf8)
        let decoded = try JSONDecoder().decode(VoiceConfiguration.self, from: legacy)
        precondition(decoded.customApplicationPath.isEmpty && decoded.isValid)
        let roundTrip = try JSONDecoder().decode(VoiceConfiguration.self, from: JSONEncoder().encode(custom))
        precondition(roundTrip == custom)
        print("PASS: voice app resolution, selected app, running activation, async completion/errors, missing/invalid apps, legacy configuration")
    }
}
