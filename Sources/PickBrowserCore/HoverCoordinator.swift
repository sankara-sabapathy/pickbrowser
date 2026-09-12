import Foundation
import CoreGraphics

public struct DetectionRequest: Equatable {
    public let id: UInt64
    public let point: CGPoint
    public let sourceID: String
}

public enum HoverAction: Equatable {
    case detect(DetectionRequest)
    case present(LinkCandidate)
    case dismiss
}

/// Deterministic state machine. The host supplies monotonic time and screen geometry.
public struct HoverCoordinator {
    public private(set) var activeLink: LinkCandidate?
    private var sourceID: String?
    private var anchor: CGPoint?
    private var dwellStarted: TimeInterval = 0
    private var outsideStarted: TimeInterval?
    private var request: DetectionRequest?
    private var generation: UInt64 = 0
    private var suppressedBounds: CGRect?
    public let dwell: TimeInterval
    public let dismissalGrace: TimeInterval

    public init(dwell: TimeInterval = 0.5, dismissalGrace: TimeInterval = 0.25) {
        self.dwell = HoverTiming.validated(dwell)
        self.dismissalGrace = dismissalGrace
    }

    public mutating func tick(point: CGPoint, sourceID newSource: String,
                              time: TimeInterval, enabled: Bool,
                              mouseDown: Bool = false, pickerBounds: CGRect? = nil) -> [HoverAction] {
        if !enabled || newSource.isEmpty {
            let actions = reset()
            sourceID = nil
            return actions
        }
        if sourceID != newSource {
            let actions = reset()
            sourceID = newSource
            anchor = point
            dwellStarted = time
            return actions
        }
        if let bounds = suppressedBounds {
            if bounds.insetBy(dx: -3, dy: -3).contains(point) { return [] }
            suppressedBounds = nil
            anchor = nil
        }
        if mouseDown { return dismissAndSuppress(at: point, time: time) }
        if let link = activeLink {
            // Only the actual link and panel keep the picker alive. The grace period
            // allows crossing the gap, without creating a large sticky rectangle.
            let overLink = link.bounds.contains(point)
            let overPicker = pickerBounds?.contains(point) == true
            if overLink || overPicker {
                outsideStarted = nil
            } else if let started = outsideStarted, time - started >= dismissalGrace {
                return resetAt(point: point, time: time)
            } else if outsideStarted == nil {
                outsideStarted = time
            }
            return []
        }
        if anchor == nil || distance(anchor!, point) > 4 {
            invalidateRequest()
            anchor = point
            dwellStarted = time
        }
        if request == nil, time - dwellStarted >= dwell {
            generation &+= 1
            let next = DetectionRequest(id: generation, point: point, sourceID: newSource)
            request = next
            return [.detect(next)]
        }
        return []
    }

    public mutating func resolve(_ candidate: LinkCandidate?, for completed: DetectionRequest,
                                 time: TimeInterval) -> [HoverAction] {
        guard request == completed, sourceID == completed.sourceID else { return [] }
        request = nil
        dwellStarted = time
        guard let candidate, candidate.sourceID == completed.sourceID,
              WebURL.validated(candidate.url.absoluteString) != nil,
              !candidate.bounds.isEmpty,
              candidate.bounds.insetBy(dx: -4, dy: -4).contains(completed.point) else { return [] }
        activeLink = candidate
        outsideStarted = nil
        return [.present(candidate)]
    }

    public mutating func dismissAndSuppress(at point: CGPoint, time: TimeInterval) -> [HoverAction] {
        let bounds = activeLink?.bounds ?? CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
        let actions = resetAt(point: point, time: time)
        suppressedBounds = bounds
        return actions
    }

    public mutating func reset() -> [HoverAction] {
        let hadLink = activeLink != nil
        activeLink = nil
        anchor = nil
        outsideStarted = nil
        suppressedBounds = nil
        invalidateRequest()
        return hadLink ? [.dismiss] : []
    }

    private mutating func resetAt(point: CGPoint, time: TimeInterval) -> [HoverAction] {
        let actions = reset()
        anchor = point
        dwellStarted = time
        return actions
    }

    private mutating func invalidateRequest() {
        generation &+= 1
        request = nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

public enum HoverTiming {
    public static let defaultDelay: TimeInterval = 0.5
    public static let range: ClosedRange<TimeInterval> = 0.1...5

    public static func validated(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultDelay }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

public enum PickerPlacement {
    public static func frame(size: CGSize, link: CGRect, screen: CGRect) -> CGRect {
        let gap: CGFloat = 8
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        var origin = CGPoint(x: link.minX, y: link.minY - gap - height)
        if origin.y < screen.minY { origin.y = link.maxY + gap }
        // Very tall links: prefer the side before clamping to the visible screen.
        if origin.y + height > screen.maxY {
            origin = CGPoint(x: link.maxX + gap, y: link.maxY - height)
            if origin.x + width > screen.maxX { origin.x = link.minX - gap - width }
        }
        origin.x = min(max(origin.x, screen.minX), screen.maxX - width)
        origin.y = min(max(origin.y, screen.minY), screen.maxY - height)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
