import Testing
import Foundation
import CoreGraphics
@testable import PickBrowserCore

struct AccessibleLinkResolverTests {
    private let point = CGPoint(x: 20, y: 20)
    private let bounds = CGRect(x: 10, y: 10, width: 100, height: 25)
    private let url = URL(string: "https://example.com/target")!

    @Test func nestedTextResolvesToActualLink() {
        let tree = FakeTree(nodes: [
            0: Node(role: "AXStaticText", parent: 1),
            1: Node(role: "AXLink", url: url, bounds: bounds, parent: 2),
            2: Node(role: "AXWebArea", url: URL(string: "https://example.com/document"))
        ])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.candidate?.url == url)
        #expect(result.candidate?.sourceID == "app:1")
        #expect(result.candidate?.isWebContent == true)
        #expect(result.roles == ["AXStaticText", "AXLink", "AXWebArea"])
        #expect(tree.urlReads == [1])
    }

    @Test func ordinaryNamedContentLinkPassesAfterContextInspection() {
        let tree = FakeTree(nodes: [
            0: Node(role: "AXStaticText", parent: 1),
            1: Node(role: "AXLink", url: url, bounds: bounds, parent: 2),
            2: Node(role: "AXGroup", parent: 3),
            3: Node(role: "AXWebArea")
        ])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.candidate?.url == url)
        #expect(result.candidate?.isWebContent == true)
        #expect(result.outcome == .linkFound)
        #expect(result.roles == ["AXStaticText", "AXLink", "AXGroup", "AXWebArea"])
    }

    @Test func navigationLandmarkIsExcludedByDefaultAndAllowedWhenOptedIn() {
        let tree = FakeTree(nodes: [
            0: Node(role: "AXLink", url: url, bounds: bounds, parent: 1),
            1: Node(role: "AXGroup", subrole: "AXLandmarkNavigation", parent: 2),
            2: Node(role: "AXWebArea")
        ])
        let filtered = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(filtered.candidate == nil)
        #expect(filtered.outcome == .filteredControl)
        let included = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point,
                                                      includeNavigationLinks: true)
        #expect(included.candidate?.url == url)
        #expect(included.candidate?.isWebContent == true)
        #expect(included.outcome == .linkFound)
    }

    @Test func buttonAncestorIsExcludedButCannotCreateALink() {
        let linkedTree = FakeTree(nodes: [
            0: Node(role: "AXStaticText", parent: 1),
            1: Node(role: "AXLink", url: url, bounds: bounds, parent: 2),
            2: Node(role: "AXButton", parent: 3),
            3: Node(role: "AXWebArea")
        ])
        let filtered = AccessibleLinkResolver.resolve(hit: 0, tree: linkedTree, sourceID: "app:1", point: point)
        #expect(filtered.outcome == .filteredControl)
        let buttonOnlyTree = FakeTree(nodes: [
            0: Node(role: "AXButton", url: url, bounds: bounds, parent: 1),
            1: Node(role: "AXWebArea")
        ])
        let buttonOnly = AccessibleLinkResolver.resolve(hit: 0, tree: buttonOnlyTree, sourceID: "app:1", point: point,
                                                        includeNavigationLinks: true)
        #expect(buttonOnly.candidate == nil)
        #expect(buttonOnly.outcome == .noLink)
        #expect(buttonOnlyTree.urlReads.isEmpty)
    }

    @Test func containingDocumentURLIsNeverReadOrUsed() {
        let tree = FakeTree(nodes: [
            0: Node(role: "AXStaticText", parent: 1),
            1: Node(role: "AXWebArea", url: url, bounds: bounds, parent: 2),
            2: Node(role: "AXLink", url: url, bounds: bounds)
        ])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.candidate == nil)
        #expect(result.outcome == .noLink)
        #expect(tree.urlReads.isEmpty)
    }

    @Test func toolbarAndMenuContextsAreOptionalWithoutReadingTheirURL() {
        for role in ["AXButton", "AXMenu", "AXMenuBar", "AXMenuItem", "AXToolbar", "AXTab", "AXTabGroup"] {
            let tree = FakeTree(nodes: [
                0: Node(role: "AXLink", url: url, bounds: bounds, parent: 1),
                1: Node(role: role, url: URL(string: "https://example.com/not-the-link"), parent: 2),
                2: Node(role: "AXWindow")
            ])
            #expect(AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point).candidate == nil)
            let allowed = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point,
                                                        includeNavigationLinks: true)
            #expect(allowed.candidate?.url == url)
            #expect(allowed.candidate?.isWebContent == false)
            #expect(tree.urlReads.allSatisfy { $0 == 0 })
        }
    }

    @Test func outerLinkCannotReplaceTheActualHitDestination() {
        let tree = FakeTree(nodes: [
            0: Node(role: "AXLink", url: url, bounds: bounds, parent: 1),
            1: Node(role: "AXLink", url: URL(string: "https://example.com/outer"), bounds: bounds, parent: 2),
            2: Node(role: "AXWebArea")
        ])
        #expect(AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point).candidate?.url == url)
        #expect(tree.urlReads == [0])
    }

    @Test func explicitLinkWithNonWebSchemeIsRejected() {
        let tree = FakeTree(nodes: [0: Node(role: "AXLink", url: URL(string: "javascript:alert(1)"), bounds: bounds)])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.candidate == nil)
        #expect(result.outcome == .noURL)
    }

    @Test func missingOrOffscreenLinkBoundsAreRejected() {
        for rectangle in [nil, CGRect.zero, CGRect(x: 1000, y: 1000, width: 30, height: 30)] as [CGRect?] {
            let tree = FakeTree(nodes: [0: Node(role: "AXLink", url: url, bounds: rectangle)])
            let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
            #expect(result.candidate == nil)
            #expect(result.outcome == .invalidBounds)
        }
    }

    @Test func cyclicParentsAndTimeoutsTerminate() {
        let tree = FakeTree(nodes: [0: Node(role: "AXGroup", parent: 1), 1: Node(role: "AXGroup", parent: 0)])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.outcome == .noLink)
        #expect(result.roles.count == 2)
        let timeout = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point, budgetExpired: { true })
        #expect(timeout.outcome == .timedOut)
        #expect(timeout.roles.isEmpty)
    }

    @Test func incompleteContextAfterALinkFailsClosed() {
        let cycle = FakeTree(nodes: [
            0: Node(role: "AXLink", url: url, bounds: bounds, parent: 1),
            1: Node(role: "AXGroup", parent: 0)
        ])
        let cyclicResult = AccessibleLinkResolver.resolve(hit: 0, tree: cycle, sourceID: "app:1", point: point)
        #expect(cyclicResult.candidate == nil)
        #expect(cyclicResult.outcome == .filteredControl)
        let missingRole = FakeTree(nodes: [
            0: Node(role: "AXLink", url: url, bounds: bounds, parent: 1),
            1: Node(role: nil)
        ])
        let missingRoleResult = AccessibleLinkResolver.resolve(hit: 0, tree: missingRole, sourceID: "app:1", point: point)
        #expect(missingRoleResult.candidate == nil)
        #expect(missingRoleResult.outcome == .filteredControl)
    }

    @Test func ancestorBudgetIsBounded() {
        let nodes = Dictionary(uniqueKeysWithValues: (0..<20).map { ($0, Node(role: "AXGroup", parent: $0 + 1)) })
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: FakeTree(nodes: nodes), sourceID: "app:1", point: point)
        #expect(result.outcome == .searchLimit)
        #expect(result.roles.count == 12)
    }

    @Test func diagnosticRolesDoNotIncludeArbitraryText() {
        let tree = FakeTree(nodes: [0: Node(role: "AXPrivate https://personal.example")])
        let result = AccessibleLinkResolver.resolve(hit: 0, tree: tree, sourceID: "app:1", point: point)
        #expect(result.roles == ["AXUnknown"])
    }

    private struct Node {
        let role: String?
        var subrole: String? = nil
        var url: URL? = nil
        var bounds: CGRect? = nil
        var parent: Int? = nil
    }
    private final class FakeTree: AccessibleLinkTree {
        let nodes: [Int: Node]
        var urlReads: [Int] = []
        init(nodes: [Int: Node]) { self.nodes = nodes }
        func role(of element: Int) -> String? { nodes[element]?.role }
        func subrole(of element: Int) -> String? { nodes[element]?.subrole }
        func linkURL(of element: Int) -> URL? { urlReads.append(element); return nodes[element]?.url }
        func bounds(of element: Int) -> CGRect? { nodes[element]?.bounds }
        func parent(of element: Int) -> Int? { nodes[element]?.parent }
    }
}
