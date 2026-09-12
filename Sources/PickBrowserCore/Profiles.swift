import Foundation

public struct BrowserProfile: Equatable {
    public let directory: String
    public let name: String
}

public enum ProfileMetadata {
    /// Chromium's Local State contains profile display metadata under profile.info_cache.
    public static func parse(_ data: Data) -> [BrowserProfile] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: [String: Any]] else { return [] }
        return cache.keys.sorted().compactMap { directory in
            guard isSafeDirectory(directory),
                  let entry = cache[directory], entry["is_ephemeral"] as? Bool != true,
                  entry["is_omitted_from_profile_list"] as? Bool != true else { return nil }
            let name = (entry["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return BrowserProfile(directory: directory, name: name?.isEmpty == false ? name! : directory)
        }
    }

    public static func isSafeDirectory(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." &&
        !value.contains("/") && !value.contains("\\") && !value.contains("\0") &&
        value != "Guest Profile" && value != "System Profile"
    }
}

public enum LaunchError: LocalizedError {
    case invalidURL, missingApplication, missingProfile, unavailableExecutable, failed(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "This link is not a valid HTTP or HTTPS URL."
        case .missingApplication: return "This browser is no longer installed. Refresh destinations in Settings."
        case .missingProfile: return "This profile is no longer available. Refresh destinations in Settings."
        case .unavailableExecutable: return "This browser could not be launched. Check its installation."
        case .failed(let code): return "The browser could not open the link (exit \(code))."
        }
    }
}

public struct LaunchCommand: Equatable {
    public let executable: URL
    public let arguments: [String]

    public static func chromium(url: URL, destination: BrowserDestination,
                                fileManager: FileManager = .default) throws -> LaunchCommand {
        guard WebURL.validated(url.absoluteString) != nil else { throw LaunchError.invalidURL }
        guard fileManager.fileExists(atPath: destination.applicationURL.path) else {
            throw LaunchError.missingApplication
        }
        guard let executable = destination.executableURL,
              fileManager.isExecutableFile(atPath: executable.path) else { throw LaunchError.unavailableExecutable }
        guard let root = destination.userDataURL, let directory = destination.profileDirectory,
              ProfileMetadata.isSafeDirectory(directory) else { throw LaunchError.missingProfile }
        let profile = root.appendingPathComponent(directory).resolvingSymlinksInPath().standardizedFileURL
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard profile.deletingLastPathComponent() == resolvedRoot, profile.lastPathComponent == directory,
              fileManager.fileExists(atPath: profile.appendingPathComponent("Preferences").path),
              let data = try? Data(contentsOf: root.appendingPathComponent("Local State")),
              ProfileMetadata.parse(data).contains(where: { $0.directory == directory }) else {
            throw LaunchError.missingProfile
        }
        return LaunchCommand(executable: executable,
                             arguments: ["--user-data-dir=\(root.path)", "--profile-directory=\(directory)", url.absoluteString])
    }
}

public enum DestinationOrder {
    public static func reconcile(saved: [String], discovered: [String]) -> [String] {
        // Keep IDs of temporarily unavailable browsers/profiles so their order survives reinstall.
        var seen = Set<String>()
        return (saved + discovered).filter { seen.insert($0).inserted }
    }
}
