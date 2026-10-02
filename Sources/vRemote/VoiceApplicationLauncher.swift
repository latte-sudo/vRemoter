import Foundation
#if canImport(AppKit)
import AppKit
#endif

struct VoiceApplicationLaunchSuccess: Equatable {
    let applicationURL: URL
    let activated: Bool
    var message: String {
        let name = applicationURL.deletingPathExtension().lastPathComponent
        return activated ? "已打开并激活 \(name)。" : "已启动 \(name)，但应用没有切到前台。请从菜单栏或 Dock 打开其设置。"
    }
}

enum VoiceApplicationLaunchError: LocalizedError, Equatable {
    case invalidConfiguration
    case notFound(String)
    case invalidApplication(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "请选择有效的 .app 应用，或填写有效的应用 Bundle ID。"
        case .notFound(let target): return "未找到语音工具（\(target)）。请先安装，或重新选择应用。"
        case .invalidApplication(let path): return "无法打开所选应用（\(path)）：不是可运行的 .app，或 Bundle ID 与所选工具不符。请重新选择。"
        case .launchFailed(let detail): return "打开语音工具失败：\(detail)"
        }
    }
}

/// Injected OS boundary keeps resolution, failures and asynchronous completion testable
/// without launching external applications. All callbacks are delivered on the caller's
/// executor; the AppKit implementation delivers its completion on the main queue.
struct VoiceApplicationLaunchEnvironment {
    var registeredApplication: (String) -> URL?
    var runningApplication: (String) -> URL?
    var isValidApplication: (URL, String?) -> Bool
    var exists: (URL) -> Bool
    var activateRunningApplication: (URL) -> Bool
    var openApplication: (URL, @escaping (Result<Bool, Error>) -> Void) -> Void
    var homeDirectory: URL
}

final class VoiceApplicationLauncher {
    // This is the settings application's identifier already used by the permission
    // guide. The input-method process ID remains separate for audio monitoring.
    static let doubaoSettingsBundleIdentifier = "com.bytedance.inputmethod.doubaoime.settings"
    private let environment: VoiceApplicationLaunchEnvironment

    init(environment: VoiceApplicationLaunchEnvironment) { self.environment = environment }

    func launch(configuration: VoiceConfiguration,
                completion: @escaping (Result<VoiceApplicationLaunchSuccess, VoiceApplicationLaunchError>) -> Void) {
        guard configuration.isValid else { completion(.failure(.invalidConfiguration)); return }
        let identifier = configuration.inputTool == .doubao
            ? Self.doubaoSettingsBundleIdentifier : configuration.targetBundleIdentifier
        let expectedIdentifier = identifier.isEmpty ? nil : identifier
        var candidates: [URL] = []
        if configuration.inputTool == .custom && !configuration.customApplicationPath.isEmpty {
            let selected = URL(fileURLWithPath: configuration.customApplicationPath)
            // If the selected file exists but is invalid, do not silently launch a
            // different application. A moved/deleted file may resolve again by ID.
            if environment.exists(selected) {
                guard environment.isValidApplication(selected, expectedIdentifier) else {
                    completion(.failure(.invalidApplication(selected.path))); return
                }
                candidates.append(selected)
            }
        }
        if !identifier.isEmpty {
            if let running = environment.runningApplication(identifier) { candidates.append(running) }
            if let registered = environment.registeredApplication(identifier) { candidates.append(registered) }
        }
        if configuration.inputTool == .doubao {
            candidates += [
                URL(fileURLWithPath: "/Library/Input Methods/DoubaoIme.app/Contents/DoubaoImeSettings.app"),
                environment.homeDirectory.appendingPathComponent("Library/Input Methods/DoubaoIme.app/Contents/DoubaoImeSettings.app")
            ]
        }
        guard let url = candidates.first(where: { environment.isValidApplication($0, expectedIdentifier) }) else {
            completion(.failure(.notFound(identifier.isEmpty ? configuration.customApplicationPath : identifier))); return
        }
        if environment.activateRunningApplication(url) {
            completion(.success(VoiceApplicationLaunchSuccess(applicationURL: url, activated: true))); return
        }
        environment.openApplication(url) { result in
            switch result {
            case .success(let activated):
                completion(.success(VoiceApplicationLaunchSuccess(applicationURL: url, activated: activated)))
            case .failure(let error): completion(.failure(.launchFailed(error.localizedDescription)))
            }
        }
    }
}

#if canImport(AppKit)
extension VoiceApplicationLauncher {
    convenience init() { self.init(environment: .workspace) }
}

extension VoiceApplicationLaunchEnvironment {
    static var workspace: Self {
        let workspace = NSWorkspace.shared
        return Self(
            registeredApplication: { workspace.urlForApplication(withBundleIdentifier: $0) },
            runningApplication: { identifier in
                NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                    .first(where: { !$0.isTerminated })?.bundleURL
            },
            isValidApplication: { url, identifier in
                guard url.isFileURL, VoiceConfiguration.isApplicationPath(url.path),
                      let bundle = Bundle(url: url),
                      bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
                      let executable = bundle.executableURL,
                      FileManager.default.isExecutableFile(atPath: executable.path)
                else { return false }
                return identifier == nil || bundle.bundleIdentifier == identifier
            },
            exists: { FileManager.default.fileExists(atPath: $0.path) },
            activateRunningApplication: { url in
                workspace.runningApplications.first(where: {
                    !$0.isTerminated && $0.bundleURL?.standardizedFileURL == url.standardizedFileURL
                })?.activate(options: [.activateIgnoringOtherApps]) ?? false
            },
            openApplication: { url, completion in
                let options = NSWorkspace.OpenConfiguration()
                options.activates = true
                workspace.openApplication(at: url, configuration: options) { application, error in
                    DispatchQueue.main.async {
                        if let error { completion(.failure(error)); return }
                        guard let application, !application.isTerminated else {
                            completion(.failure(VoiceApplicationLaunchError.launchFailed("系统未返回正在运行的应用。"))); return
                        }
                        let activated = application.isActive || application.activate(options: [.activateIgnoringOtherApps])
                        completion(.success(activated))
                    }
                }
            },
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        )
    }
}
#endif
