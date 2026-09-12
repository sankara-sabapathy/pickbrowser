import AppKit
import Combine
import Sparkle

/// Sparkle owns update verification, download, installation, relaunch, and preferences.
/// Unconfigured development builds do not start the updater or contact the network.
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var error: String?
    private var controller: SPUStandardUpdaterController?

    var configured: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host == "github.com" else { return false }
        return true
    }

    func start() {
        guard configured, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main).assign(to: &$automaticallyChecks)
        do { try controller.updater.start() }
        catch { self.error = "Updates unavailable: \(error.localizedDescription)" }
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func check() {
        guard canCheck else { return }
        controller?.checkForUpdates(nil)
    }

    func openReleases() {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PickBrowserReleasesURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host == "github.com" else { return }
        NSWorkspace.shared.open(url)
    }
}
