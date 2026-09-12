import Foundation
import CoreGraphics

/// A narrow view of an accessibility tree: never reads labels or document contents.
public protocol AccessibleLinkTree {
    associatedtype Element: Equatable
    func role(of element: Element) -> String?
    func linkURL(of element: Element) -> URL?
    func bounds(of element: Element) -> CGRect?
    func parent(of element: Element) -> Element?
}

public struct LinkResolution {
    public enum Outcome: String {
        case linkFound = "Link detected"
        case noLink = "No accessible link at pointer"
        case noURL = "Link has no HTTP/HTTPS destination"
        case invalidBounds = "Link does not expose usable bounds"
        case timedOut = "Source application timed out"
        case searchLimit = "No link within the bounded ancestor search"
    }
    public let candidate: LinkCandidate?
    public let outcome: Outcome
    public let roles: [String]
}

public enum AccessibleLinkResolver {
    public static func resolve<Tree: AccessibleLinkTree>(hit: Tree.Element, tree: Tree,
        sourceID: String, point: CGPoint, budgetExpired: () -> Bool = { false }) -> LinkResolution {
        var element = hit
        var visited: [Tree.Element] = []
        var roles: [String] = []
        func result(_ outcome: LinkResolution.Outcome, _ candidate: LinkCandidate? = nil) -> LinkResolution {
            LinkResolution(candidate: candidate, outcome: outcome, roles: roles)
        }
        for _ in 0..<8 {
            guard !budgetExpired() else { return result(.timedOut) }
            guard !visited.contains(element) else { return result(.noLink) }
            visited.append(element)
            let role = tree.role(of: element) ?? "AXUnknown"
            // Diagnostic roles contain no arbitrary app-provided text.
            roles.append(role.hasPrefix("AX") && role.count < 50 && role.allSatisfy(\.isLetter) ? role : "AXUnknown")
            if role == "AXLink" {
                guard let url = tree.linkURL(of: element), WebURL.validated(url.absoluteString) != nil else {
                    return result(.noURL)
                }
                guard let bounds = tree.bounds(of: element), !bounds.isEmpty,
                      bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                      bounds.width.isFinite, bounds.height.isFinite,
                      bounds.insetBy(dx: -4, dy: -4).contains(point) else { return result(.invalidBounds) }
                return result(.linkFound, LinkCandidate(url: url, sourceID: sourceID, bounds: bounds))
            }
            if ["AXWebArea", "AXWindow", "AXApplication", "AXDocument"].contains(role) { return result(.noLink) }
            guard let parent = tree.parent(of: element) else { return result(.noLink) }
            element = parent
        }
        return result(.searchLimit)
    }
}
