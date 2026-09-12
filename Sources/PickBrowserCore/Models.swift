import Foundation
import CoreGraphics

public struct LinkCandidate: Equatable {
    public let url: URL
    public let sourceID: String
    /// Global screen coordinates, increasing upward (AppKit convention on macOS).
    public let bounds: CGRect

    public init(url: URL, sourceID: String, bounds: CGRect) {
        self.url = url
        self.sourceID = sourceID
        self.bounds = bounds
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
}

public struct BrowserDestination: Identifiable, Equatable {
    public let id: String
    public let browserName: String
    public let profileName: String?
    public let applicationURL: URL
    public let executableURL: URL?
    public let userDataURL: URL?
    public let profileDirectory: String?

    public var title: String {
        profileName.map { "\(browserName) · \($0)" } ?? browserName
    }

    public init(id: String, browserName: String, profileName: String? = nil,
                applicationURL: URL, executableURL: URL? = nil,
                userDataURL: URL? = nil, profileDirectory: String? = nil) {
        self.id = id
        self.browserName = browserName
        self.profileName = profileName
        self.applicationURL = applicationURL
        self.executableURL = executableURL
        self.userDataURL = userDataURL
        self.profileDirectory = profileDirectory
    }
}

public protocol LinkDetector {
    func detect(at point: CGPoint, sourceID: String, completion: @escaping (LinkCandidate?) -> Void)
}

public protocol BrowserCatalog {
    func discover() -> [BrowserDestination]
}

public protocol BrowserLauncher {
    func open(_ url: URL, in destination: BrowserDestination,
              completion: @escaping (Result<Void, Error>) -> Void)
}
