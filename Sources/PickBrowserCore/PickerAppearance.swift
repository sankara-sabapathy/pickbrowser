import Foundation

/// The persisted visual treatment for the hover picker.
///
/// The color is intentionally stored as channels instead of an AppKit type so
/// that preferences remain portable and straightforward to validate.
public struct PickerAppearance: Equatable, Codable {
    public static let defaultOpacity = 0.88
    public static let opacityRange: ClosedRange<Double> = 0.35...1

    public let usesCustomColor: Bool
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(usesCustomColor: Bool = false,
                red: Double = 0.13,
                green: Double = 0.16,
                blue: Double = 0.20,
                opacity: Double = PickerAppearance.defaultOpacity) {
        self.usesCustomColor = usesCustomColor
        self.red = Self.channel(red)
        self.green = Self.channel(green)
        self.blue = Self.channel(blue)
        self.opacity = Self.validatedOpacity(opacity)
    }

    public static let `default` = PickerAppearance()

    /// Contrast against the tint composited over the light/dark material backing.
    public func prefersLightText(darkMode: Bool, reduceTransparency: Bool) -> Bool {
        let alpha = reduceTransparency ? 1 : opacity
        let backing = darkMode ? 0.14 : 0.96
        func linear(_ channel: Double) -> Double {
            let blended = channel * alpha + backing * (1 - alpha)
            return blended <= 0.04045 ? blended / 12.92 : pow((blended + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance < 0.179
    }

    private static func channel(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private static func validatedOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOpacity }
        return min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }
}
