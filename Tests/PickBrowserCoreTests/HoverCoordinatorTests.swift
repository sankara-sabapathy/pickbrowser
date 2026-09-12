import Testing
import Foundation
import CoreGraphics
@testable import PickBrowserCore

struct HoverCoordinatorTests {
    private let point = CGPoint(x: 120, y: 200)
    private let source = "test.app:123"
    private var candidate: LinkCandidate {
        LinkCandidate(url: URL(string: "https://example.com/path")!, sourceID: source,
                      bounds: CGRect(x: 100, y: 190, width: 130, height: 20))
    }

    private func request(_ coordinator: inout HoverCoordinator) throws -> DetectionRequest {
        #expect(coordinator.tick(point: point, sourceID: source, time: 0, enabled: true).isEmpty)
        let actions = coordinator.tick(point: point, sourceID: source, time: 0.5, enabled: true)
        guard case .detect(let request) = actions.first else {
            Issue.record("Expected a detection request")
            throw TestError.noRequest
        }
        return request
    }

    private func show(_ coordinator: inout HoverCoordinator) throws {
        let next = try request(&coordinator)
        #expect(coordinator.resolve(candidate, for: next, time: 0.51) == [.present(candidate)])
    }

    @Test func dwellWaitsHalfASecond() {
        var coordinator = HoverCoordinator()
        _ = coordinator.tick(point: point, sourceID: source, time: 0, enabled: true)
        #expect(coordinator.tick(point: point, sourceID: source, time: 0.49, enabled: true).isEmpty)
        #expect(coordinator.tick(point: point, sourceID: source, time: 0.5, enabled: true).count == 1)
        #expect(coordinator.tick(point: point, sourceID: source, time: 0.9, enabled: true).isEmpty)
    }

    @Test func movementResetsDwellAndCancelsStaleResults() throws {
        var coordinator = HoverCoordinator()
        let next = try request(&coordinator)
        let moved = CGPoint(x: 150, y: 200)
        #expect(coordinator.tick(point: moved, sourceID: source, time: 0.6, enabled: true).isEmpty)
        #expect(coordinator.resolve(candidate, for: next, time: 0.61).isEmpty)
        #expect(coordinator.tick(point: moved, sourceID: source, time: 1, enabled: true).isEmpty)
        #expect(coordinator.tick(point: moved, sourceID: source, time: 1.11, enabled: true).count == 1)
    }

    @Test func appSwitchRejectsResult() throws {
        var coordinator = HoverCoordinator()
        let next = try request(&coordinator)
        _ = coordinator.tick(point: point, sourceID: "another.app:456", time: 0.6, enabled: true)
        #expect(coordinator.resolve(candidate, for: next, time: 0.61).isEmpty)
    }

    @Test func permissionRevocationRejectsPendingResult() throws {
        var coordinator = HoverCoordinator()
        let next = try request(&coordinator)
        _ = coordinator.tick(point: point, sourceID: source, time: 0.6, enabled: false)
        #expect(coordinator.resolve(candidate, for: next, time: 0.7).isEmpty)
    }

    @Test func permissionRevocationDismissesVisiblePicker() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        #expect(coordinator.tick(point: point, sourceID: source, time: 0.6, enabled: false) == [.dismiss])
        #expect(coordinator.activeLink == nil)
    }

    @Test func pickerCorridorAndDismissalGrace() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        let panel = CGRect(x: 100, y: 80, width: 300, height: 100)
        #expect(coordinator.tick(point: CGPoint(x: 130, y: 185), sourceID: source,
                                time: 0.8, enabled: true, pickerBounds: panel).isEmpty)
        #expect(coordinator.tick(point: CGPoint(x: 300, y: 100), sourceID: source,
                                time: 1, enabled: true, pickerBounds: panel).isEmpty)
        let outside = CGPoint(x: 800, y: 700)
        #expect(coordinator.tick(point: outside, sourceID: source, time: 2, enabled: true, pickerBounds: panel).isEmpty)
        #expect(coordinator.tick(point: outside, sourceID: source, time: 2.24, enabled: true, pickerBounds: panel).isEmpty)
        #expect(coordinator.tick(point: outside, sourceID: source, time: 2.26, enabled: true, pickerBounds: panel) == [.dismiss])
    }

    @Test func returningToPickerCancelsDismissal() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        _ = coordinator.tick(point: .zero, sourceID: source, time: 1, enabled: true)
        _ = coordinator.tick(point: point, sourceID: source, time: 1.2, enabled: true)
        #expect(coordinator.tick(point: point, sourceID: source, time: 2, enabled: true).isEmpty)
        #expect(coordinator.activeLink != nil)
    }

    @Test func emptyAreaInUnionOfLinkAndPickerDoesNotKeepPickerOpen() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        let panel = CGRect(x: 100, y: 80, width: 300, height: 100)
        // To the right of the short link, above the wider panel: inside the old union.
        let away = CGPoint(x: 360, y: 200)
        #expect(coordinator.tick(point: away, sourceID: source, time: 1, enabled: true, pickerBounds: panel).isEmpty)
        #expect(coordinator.tick(point: away, sourceID: source, time: 1.26, enabled: true, pickerBounds: panel) == [.dismiss])
        #expect(coordinator.activeLink == nil)
    }

    @Test func lingeringInGapDismissesButQuickTraversalDoesNot() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        let panel = CGRect(x: 100, y: 80, width: 300, height: 100)
        let gap = CGPoint(x: 120, y: 185)
        _ = coordinator.tick(point: gap, sourceID: source, time: 1, enabled: true, pickerBounds: panel)
        #expect(coordinator.tick(point: gap, sourceID: source, time: 1.26, enabled: true, pickerBounds: panel) == [.dismiss])
    }

    @Test func customDelayAndInvalidValues() {
        #expect(HoverTiming.validated(.nan) == 0.5)
        #expect(HoverTiming.validated(.infinity) == 0.5)
        #expect(HoverTiming.validated(-1) == 0.1)
        #expect(HoverTiming.validated(100) == 5)
        var coordinator = HoverCoordinator(dwell: 1.7)
        _ = coordinator.tick(point: point, sourceID: source, time: 0, enabled: true)
        #expect(coordinator.tick(point: point, sourceID: source, time: 1.69, enabled: true).isEmpty)
        #expect(coordinator.tick(point: point, sourceID: source, time: 1.7, enabled: true).count == 1)
    }

    @Test func selectionAndEscapeSuppressUntilLeavingLink() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        #expect(coordinator.dismissAndSuppress(at: point, time: 1) == [.dismiss])
        #expect(coordinator.tick(point: point, sourceID: source, time: 10, enabled: true).isEmpty)
        _ = coordinator.tick(point: .zero, sourceID: source, time: 11, enabled: true)
        _ = coordinator.tick(point: point, sourceID: source, time: 12, enabled: true)
        #expect(coordinator.tick(point: point, sourceID: source, time: 12.5, enabled: true).count == 1)
    }

    @Test func ordinaryClickDismissesAndDoesNotReopen() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        #expect(coordinator.tick(point: point, sourceID: source, time: 1, enabled: true, mouseDown: true) == [.dismiss])
        #expect(coordinator.tick(point: point, sourceID: source, time: 3, enabled: true).isEmpty)
    }

    @Test func unsupportedLinkStaysSilentAndCanRetry() throws {
        var coordinator = HoverCoordinator()
        let next = try request(&coordinator)
        #expect(coordinator.resolve(nil, for: next, time: 0.6).isEmpty)
        #expect(coordinator.tick(point: point, sourceID: source, time: 0.9, enabled: true).isEmpty)
        #expect(coordinator.tick(point: point, sourceID: source, time: 1.11, enabled: true).count == 1)
    }

    @Test func wrongSourceOrBoundsAreRejected() throws {
        for invalid in [
            LinkCandidate(url: candidate.url, sourceID: "wrong", bounds: candidate.bounds),
            LinkCandidate(url: candidate.url, sourceID: source, bounds: .zero),
            LinkCandidate(url: candidate.url, sourceID: source, bounds: CGRect(x: 800, y: 800, width: 100, height: 20))
        ] {
            var coordinator = HoverCoordinator()
            let next = try request(&coordinator)
            #expect(coordinator.resolve(invalid, for: next, time: 0.6).isEmpty)
        }
    }

    @Test func lateDuplicateCompletionCannotShowAgain() throws {
        var coordinator = HoverCoordinator()
        let next = try request(&coordinator)
        _ = coordinator.resolve(candidate, for: next, time: 0.6)
        _ = coordinator.dismissAndSuppress(at: point, time: 0.7)
        #expect(coordinator.resolve(candidate, for: next, time: 0.8).isEmpty)
    }

    @Test func appSwitchDismissesVisiblePicker() throws {
        var coordinator = HoverCoordinator()
        try show(&coordinator)
        #expect(coordinator.tick(point: point, sourceID: "other:456", time: 1, enabled: true) == [.dismiss])
    }

    @Test func panelPlacementOnNegativeCoordinateDisplay() {
        let screen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let link = CGRect(x: -60, y: -190, width: 50, height: 20)
        let panel = PickerPlacement.frame(size: CGSize(width: 300, height: 350), link: link, screen: screen)
        #expect(screen.contains(panel))
        #expect(!panel.intersects(link))
    }

    @Test func panelPlacementOnDisplayAbovePrimary() {
        let screen = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let link = CGRect(x: 400, y: 1800, width: 100, height: 20)
        let panel = PickerPlacement.frame(size: CGSize(width: 300, height: 350), link: link, screen: screen)
        #expect(screen.contains(panel))
        #expect(panel.maxY < link.minY)
    }

    private enum TestError: Error { case noRequest }
}
