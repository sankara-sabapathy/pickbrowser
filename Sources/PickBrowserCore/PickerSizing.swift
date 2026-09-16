import CoreGraphics

/// Bounded picker scaling keeps the widget legible and placeable near the pointer.
public enum PickerSizing {
    public static let defaultScale = 1.0
    public static let scaleRange: ClosedRange<Double> = 0.8...1.4

    public static func validated(_ scale: Double) -> Double {
        guard scale.isFinite else { return defaultScale }
        return min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
    }

    public static func panelSize(destinationCount: Int, scale: Double) -> CGSize {
        let scale = CGFloat(validated(scale))
        let visibleRows = min(max(destinationCount, 1), 7)
        return CGSize(width: 320 * scale,
                      height: CGFloat(58 + visibleRows * 42 + 12) * scale)
    }
}
