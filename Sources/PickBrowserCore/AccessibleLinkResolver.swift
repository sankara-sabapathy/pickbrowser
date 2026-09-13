import Foundation
import CoreGraphics

/// A narrow view of an accessibility tree: never reads labels or document contents.
public protocol AccessibleLinkTree {
    associatedtype Element: Equatable
    func role(of element: Element) -> String?
    /// Optional because older accessibility clients and narrow test doubles may not expose it.
    /// It is only used to recognize the platform's explicit navigation landmark.
    func subrole(of element: Element) -> String?
    func linkURL(of element: Element) -> URL?
    func bounds(of element: Element) -> CGRect?
    func parent(of element: Element) -> Element?
}

public extension AccessibleLinkTree {
    func subrole(of element: Element) -> String? { nil }
}

public struct LinkResolution {
    public enum Outcome: String {
        case linkFound = "Link detected"
        case noLink = "No accessible link at pointer"
        case noURL = "Link has no HTTP/HTTPS destination"
        case invalidBounds = "Link does not expose usable bounds"
        case filteredControl = "Link is in excluded control or navigation context"
        case timedOut = "Source application timed out"
        case searchLimit = "No link within the bounded ancestor search"
    }
    public let candidate: LinkCandidate?
    public let outcome: Outcome
    public let roles: [String]
}

public enum AccessibleLinkResolver {
    public static func resolve<Tree: AccessibleLinkTree>(hit: Tree.Element, tree: Tree,
        sourceID: String, point: CGPoint, includeNavigationLinks: Bool = false,
        budgetExpired: () -> Bool = { false }) -> LinkResolution {
        var element = hit
        var visited: [Tree.Element] = []
        var roles: [String] = []
        // Do not construct the candidate until the whole bounded context has been
        // checked: the browser UI must know whether this is actually web content.
        var destination: (url: URL, bounds: CGRect)?
        var isWebContent = false
        var hasExcludedContext = false
        func result(_ outcome: LinkResolution.Outcome, _ candidate: LinkCandidate? = nil) -> LinkResolution {
            LinkResolution(candidate: candidate, outcome: outcome, roles: roles)
        }
        // Twelve elements keep this passive AX walk bounded while accommodating the
        // nested groups commonly inserted by Chromium and Slack before an AXLink.
        // A candidate is withheld when its enclosing context cannot be checked in time.
        for _ in 0..<12 {
            guard !budgetExpired() else { return result(.timedOut) }
            guard !visited.contains(element) else {
                return result(destination == nil ? .noLink : .filteredControl)
            }
            visited.append(element)
            guard let rawRole = tree.role(of: element) else {
                return result(destination == nil ? .noLink : .filteredControl)
            }
            let role = rawRole
            // Diagnostic roles contain no arbitrary app-provided text.
            roles.append(role.hasPrefix("AX") && role.count < 50 && role.allSatisfy(\.isLetter) ? role : "AXUnknown")
            if isExcludedContext(role: role, subrole: role == "AXGroup" ? tree.subrole(of: element) : nil) {
                hasExcludedContext = true
            }
            if role == "AXLink", destination == nil {
                guard let url = tree.linkURL(of: element), WebURL.validated(url.absoluteString) != nil else {
                    return result(.noURL)
                }
                guard let bounds = tree.bounds(of: element), !bounds.isEmpty,
                      bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                      bounds.width.isFinite, bounds.height.isFinite,
                      bounds.insetBy(dx: -4, dy: -4).contains(point) else { return result(.invalidBounds) }
                destination = (url, bounds)
            }
            if role == "AXWebArea" { isWebContent = true }
            if ["AXWebArea", "AXWindow", "AXApplication", "AXDocument"].contains(role) {
                guard !budgetExpired() else { return result(.timedOut) }
                return resolved(destination: destination, sourceID: sourceID, isWebContent: isWebContent,
                                excluded: hasExcludedContext,
                                includeNavigationLinks: includeNavigationLinks, result: result)
            }
            guard let parent = tree.parent(of: element) else {
                guard !budgetExpired() else { return result(.timedOut) }
                return resolved(destination: destination, sourceID: sourceID, isWebContent: isWebContent,
                                excluded: hasExcludedContext,
                                includeNavigationLinks: includeNavigationLinks, result: result)
            }
            element = parent
        }
        return result(.searchLimit)
    }

    private static func resolved(
        destination: (url: URL, bounds: CGRect)?,
        sourceID: String,
        isWebContent: Bool,
        excluded: Bool,
        includeNavigationLinks: Bool,
        result: (LinkResolution.Outcome, LinkCandidate?) -> LinkResolution
    ) -> LinkResolution {
        guard let destination else { return result(.noLink, nil) }
        guard includeNavigationLinks || !excluded else { return result(.filteredControl, nil) }
        return result(.linkFound, LinkCandidate(url: destination.url, sourceID: sourceID,
                                                 bounds: destination.bounds, isWebContent: isWebContent))
    }

    private static func isExcludedContext(role: String, subrole: String?) -> Bool {
        // AXLandmarkNavigation is the public macOS Web accessibility subrole.
        // Chromium commonly exposes it on an AXGroup rather than as a distinct role.
        subrole == "AXLandmarkNavigation" || [
            "AXButton", "AXMenu", "AXMenuBar", "AXMenuItem", "AXToolbar", "AXTab", "AXTabGroup"
        ].contains(role)
    }
}
