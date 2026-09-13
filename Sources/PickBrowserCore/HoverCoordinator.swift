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
    public private(set) var dwell: TimeInterval
    public let dismissalGrace: TimeInterval

    public init(dwell: TimeInterval = 0.5, dismissalGrace: TimeInterval = 0.25) {
        self.dwell = HoverTiming.validated(dwell)
        self.dismissalGrace = dismissalGrace
    }

    public mutating func updateDwell(_ value: TimeInterval) -> [HoverAction] {
        let delay = HoverTiming.validated(value)
        guard delay != dwell else { return [] }
        dwell = delay
        // Preserve request generation across preference changes; replacing the
        // coordinator could allow an old completion to match a new request ID.
        return reset()
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
    /// Places the picker adjacent to the pointer captured when it was shown.
    /// Coordinates are AppKit global screen coordinates, so “below” decreases Y.
    public static func frame(size: CGSize, cursor: CGPoint, screen: CGRect, gap: CGFloat = 10) -> CGRect {
        let visible = screen.standardized
        guard visible.width.isFinite, visible.height.isFinite,
              visible.origin.x.isFinite, visible.origin.y.isFinite,
              cursor.x.isFinite, cursor.y.isFinite,
              visible.width > 0, visible.height > 0 else { return .zero }

        let width = min(max(size.width.isFinite ? size.width : 0, 0), visible.width)
        let height = min(max(size.height.isFinite ? size.height : 0, 0), visible.height)
        let spacing = max(gap.isFinite ? gap : 10, 0)
        let dimensions = CGSize(width: width, height: height)

        // Prefer the lower-right quadrant. The remaining order keeps the picker
        // adjacent to the pointer while adapting to the nearest usable edge.
        let preferredOrigins = [
            CGPoint(x: cursor.x + spacing, y: cursor.y - spacing - height),
            CGPoint(x: cursor.x + spacing, y: cursor.y + spacing),
            CGPoint(x: cursor.x - spacing - width, y: cursor.y - spacing - height),
            CGPoint(x: cursor.x - spacing - width, y: cursor.y + spacing)
        ]
        let preferredFrames = preferredOrigins.map { CGRect(origin: $0, size: dimensions) }
        if let fitting = preferredFrames.first(where: { visible.contains($0) }) {
            return fitting
        }

        let candidates = preferredFrames.enumerated().map { index, preferred in
            (index, clamp(preferred, to: visible), preferred.origin)
        }
        // On very small screens no quadrant can fit unchanged. Favor an
        // adjacent, non-overlapping frame, then the closest clamped origin.
        let nearest = candidates.min { lhs, rhs in
            let lhsOverlaps = lhs.1.contains(cursor)
            let rhsOverlaps = rhs.1.contains(cursor)
            if lhsOverlaps != rhsOverlaps { return !lhsOverlaps }

            let lhsDistance = squaredDistance(lhs.1, to: cursor)
            let rhsDistance = squaredDistance(rhs.1, to: cursor)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }

            let lhsClamp = squaredDistance(lhs.1.origin, lhs.2)
            let rhsClamp = squaredDistance(rhs.1.origin, rhs.2)
            if lhsClamp != rhsClamp { return lhsClamp < rhsClamp }
            return lhs.0 < rhs.0
        }?.1 ?? CGRect(origin: visible.origin, size: dimensions)
        if !nearest.contains(cursor) { return nearest }

        // If the original panel would cover the pointer, shrink onto the largest
        // available side. The destination list scrolls rather than swallowing the hover.
        let sides = [
            CGRect(x: cursor.x + spacing, y: visible.minY,
                   width: max(0, visible.maxX - cursor.x - spacing), height: visible.height),
            CGRect(x: visible.minX, y: visible.minY, width: visible.width,
                   height: max(0, cursor.y - spacing - visible.minY)),
            CGRect(x: visible.minX, y: visible.minY,
                   width: max(0, cursor.x - spacing - visible.minX), height: visible.height),
            CGRect(x: visible.minX, y: cursor.y + spacing, width: visible.width,
                   height: max(0, visible.maxY - cursor.y - spacing))
        ].map { $0.intersection(visible) }.filter { !$0.isEmpty && !$0.isNull }
        guard let side = sides.max(by: {
            min($0.width, width) * min($0.height, height) < min($1.width, width) * min($1.height, height)
        }) else { return .zero }
        return clamp(CGRect(x: cursor.x + spacing, y: cursor.y - spacing - min(height, side.height),
                            width: min(width, side.width), height: min(height, side.height)), to: side)
    }

    private static func clamp(_ frame: CGRect, to screen: CGRect) -> CGRect {
        let x = min(max(frame.minX, screen.minX), screen.maxX - frame.width)
        let y = min(max(frame.minY, screen.minY), screen.maxY - frame.height)
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }

    private static func squaredDistance(_ frame: CGRect, to point: CGPoint) -> CGFloat {
        let x = min(max(point.x, frame.minX), frame.maxX)
        let y = min(max(point.y, frame.minY), frame.maxY)
        let dx = point.x - x
        let dy = point.y - y
        return dx * dx + dy * dy
    }

    private static func squaredDistance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }
}
