import AppKit
import PickBrowserCore

struct MacBrowserCatalog: BrowserCatalog {
    private struct ChromiumBrowser {
        let id: String
        let name: String
        let dataPath: String
    }

    func discover() -> [BrowserDestination] {
        let browsers = [
            ChromiumBrowser(id: "com.google.Chrome", name: "Chrome", dataPath: "Google/Chrome"),
            ChromiumBrowser(id: "com.microsoft.edgemac", name: "Edge", dataPath: "Microsoft Edge"),
            ChromiumBrowser(id: "com.brave.Browser", name: "Brave", dataPath: "BraveSoftware/Brave-Browser")
        ]
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        var result: [BrowserDestination] = []
        for browser in browsers {
            guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.id),
                  let executable = Bundle(url: application)?.executableURL else { continue }
            let root = support.appendingPathComponent(browser.dataPath)
            guard let data = try? Data(contentsOf: root.appendingPathComponent("Local State")) else { continue }
            for profile in ProfileMetadata.parse(data) {
                let directory = root.appendingPathComponent(profile.directory).resolvingSymlinksInPath().standardizedFileURL
                guard directory.deletingLastPathComponent() == root.resolvingSymlinksInPath().standardizedFileURL,
                      directory.lastPathComponent == profile.directory,
                      FileManager.default.fileExists(atPath: directory.appendingPathComponent("Preferences").path) else { continue }
                result.append(BrowserDestination(id: "\(browser.id):\(profile.directory)", browserName: browser.name,
                    profileName: profile.name, applicationURL: application, executableURL: executable,
                    userDataURL: root, profileDirectory: profile.directory))
            }
        }
        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            result.append(BrowserDestination(id: "com.apple.Safari", browserName: "Safari", applicationURL: safari))
        }
        return result
    }
}

final class MacBrowserLauncher: BrowserLauncher {
    func open(_ url: URL, in destination: BrowserDestination,
              completion: @escaping (Result<Void, Error>) -> Void) {
        guard WebURL.validated(url.absoluteString) != nil else { completion(.failure(LaunchError.invalidURL)); return }
        if destination.profileDirectory == nil {
            guard destination.id == "com.apple.Safari",
                  FileManager.default.fileExists(atPath: destination.applicationURL.path) else {
                completion(.failure(LaunchError.missingApplication)); return
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: destination.applicationURL, configuration: config) { _, error in
                DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let command = try LaunchCommand.chromium(url: url, destination: destination)
                let process = Process()
                process.executableURL = command.executable
                process.arguments = command.arguments
                // Browser output can include URLs. Do not collect or persist it.
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.standardInput = FileHandle.nullDevice
                // A cold browser process can stay alive for hours. A warm launch normally exits
                // quickly after forwarding to the existing instance. Resolve once, never kill it.
                let result = LaunchCompletion(completion)
                process.terminationHandler = { process in
                    result.finish(process.terminationStatus == 0 ? .success(()) : .failure(LaunchError.failed(process.terminationStatus)))
                }
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    // Keep the process alive through dispatch verification and catch a quick exit
                    // even if its termination callback has not been scheduled yet.
                    if process.isRunning || process.terminationStatus == 0 { result.finish(.success(())) }
                    else { result.finish(.failure(LaunchError.failed(process.terminationStatus))) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

private final class LaunchCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: ((Result<Void, Error>) -> Void)?

    init(_ callback: @escaping (Result<Void, Error>) -> Void) { self.callback = callback }

    func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let callback = self.callback
        self.callback = nil
        lock.unlock()
        if let callback { DispatchQueue.main.async { callback(result) } }
    }
}
