import Foundation
import CoreGraphics

public struct LinkCandidate: Equatable {
    public let url: URL
    public let sourceID: String
    /// Global screen coordinates, increasing upward (AppKit convention on macOS).
    public let bounds: CGRect
    /// True only when the accessibility ancestry establishes web content.
    public let isWebContent: Bool

    public init(url: URL, sourceID: String, bounds: CGRect, isWebContent: Bool = false) {
        self.url = url
        self.sourceID = sourceID
        self.bounds = bounds
        self.isWebContent = isWebContent
    }
}

public enum WebURL {
    public static func validated(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              !value.contains(where: { $0.isNewline || $0.asciiValue == 0 }) else { return nil }
        return url
    }

    /// Some web-based desktop apps expose a verified AXLink destination without
    /// its scheme. Call this only for values read from an actual link element.
    public static func fromExplicitLinkValue(_ value: String) -> URL? {
        if let absolute = validated(value) { return absolute }
        guard !value.isEmpty,
              !value.contains(where: { $0.isWhitespace || $0.asciiValue == 0 }),
              !value.contains("://"), !value.hasPrefix("//"),
              let components = URLComponents(string: "https://" + value),
              components.user == nil, components.password == nil,
              let host = components.host?.lowercased(),
              host == "localhost" || host.contains(".") || (host.hasPrefix("[") && host.hasSuffix("]")),
              let normalized = components.url else { return nil }
        return validated(normalized.absoluteString)
    }
}

public struct BrowserDestination: Identifiable, Equatable {
    public let id: String
    public let browserName: String
    public let profileName: String?
    public let applicationURL: URL
    public let executableURL: URL?
    public let userDataURL: URL?
    public let profileDirectory: String?
    public let nickname: String?

    public var title: String {
        nickname ?? detectedTitle
    }

    public var detectedTitle: String {
        profileName.map { "\(browserName) · \($0)" } ?? browserName
    }

    public var supportsPrivateBrowsing: Bool {
        guard profileDirectory != nil else { return false }
        return id.hasPrefix("com.google.Chrome:") ||
            id.hasPrefix("com.microsoft.edgemac:") ||
            id.hasPrefix("com.brave.Browser:")
    }

    public init(id: String, browserName: String, profileName: String? = nil,
                applicationURL: URL, executableURL: URL? = nil,
                userDataURL: URL? = nil, profileDirectory: String? = nil,
                nickname: String? = nil) {
        self.id = id
        self.browserName = browserName
        self.profileName = profileName
        self.applicationURL = applicationURL
        self.executableURL = executableURL
        self.userDataURL = userDataURL
        self.profileDirectory = profileDirectory
        self.nickname = DestinationNickname.normalized(nickname)
    }

    public func withNickname(_ nickname: String?) -> BrowserDestination {
        BrowserDestination(id: id, browserName: browserName, profileName: profileName,
                           applicationURL: applicationURL, executableURL: executableURL,
                           userDataURL: userDataURL, profileDirectory: profileDirectory,
                           nickname: nickname)
    }
}

public enum DestinationNickname {
    public static let maximumLength = 40

    public static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let singleLine = value.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else { return nil }
        return String(singleLine.prefix(maximumLength))
    }
}

public protocol LinkDetector {
    func detect(at point: CGPoint, sourceID: String, completion: @escaping (LinkCandidate?) -> Void)
}

public protocol BrowserCatalog {
    func discover() -> [BrowserDestination]
}

public protocol BrowserLauncher {
    func open(_ url: URL, in destination: BrowserDestination, mode: BrowserOpenMode,
              completion: @escaping (Result<Void, Error>) -> Void)
}

public enum BrowserOpenMode: Equatable {
    case normal
    case privateWindow
}
