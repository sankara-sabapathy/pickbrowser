import Foundation

/// Packaged releases must run from a stable Applications directory so macOS
/// can associate Accessibility consent and updates with one app location.
public enum ApplicationInstallLocation {
    public static func requiresInstallation(bundleURL: URL, homeDirectory: URL) -> Bool {
        let bundle = bundleURL.resolvingSymlinksInPath().standardizedFileURL
        // SwiftPM executables and developer diagnostics are not app bundles.
        guard bundle.pathExtension.lowercased() == "app" else { return false }

        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ].map { $0.resolvingSymlinksInPath().standardizedFileURL.path }

        return !roots.contains { root in
            bundle.path == root || bundle.path.hasPrefix(root + "/")
        }
    }
}
