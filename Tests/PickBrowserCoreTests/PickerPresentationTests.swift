import CoreGraphics
import Testing
@testable import PickBrowserCore

struct PickerPresentationTests {
    private let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    private let size = CGSize(width: 200, height: 150)

    @Test func prefersLowerRightBesideTheCursor() {
        let cursor = CGPoint(x: 400, y: 400)
        let panel = PickerPlacement.frame(size: size, cursor: cursor, screen: screen)

        #expect(panel == CGRect(x: 410, y: 240, width: 200, height: 150))
        #expect(!panel.contains(cursor))
    }

    @Test func usesTheAvailableQuadrantAtEveryScreenCorner() {
        let cases: [(CGPoint, CGRect)] = [
            (CGPoint(x: 10, y: 790), CGRect(x: 20, y: 630, width: 200, height: 150)), // lower-right
            (CGPoint(x: 990, y: 790), CGRect(x: 780, y: 630, width: 200, height: 150)), // lower-left
            (CGPoint(x: 10, y: 10), CGRect(x: 20, y: 20, width: 200, height: 150)), // upper-right
            (CGPoint(x: 990, y: 10), CGRect(x: 780, y: 20, width: 200, height: 150)) // upper-left
        ]

        for (cursor, expected) in cases {
            let panel = PickerPlacement.frame(size: size, cursor: cursor, screen: screen)
            #expect(panel == expected)
            #expect(screen.contains(panel))
            #expect(!panel.contains(cursor))
        }
    }

    @Test func clampsToNarrowAndNegativeOriginDisplays() {
        let narrow = CGRect(x: -100, y: 600, width: 120, height: 100)
        let panel = PickerPlacement.frame(size: CGSize(width: 320, height: 250),
                                          cursor: CGPoint(x: -25, y: 650),
                                          screen: narrow)
        #expect(narrow.contains(panel))
        #expect(!panel.contains(CGPoint(x: -25, y: 650)))

        let negative = CGRect(x: -1_920, y: -200, width: 1_920, height: 1_080)
        let negativePanel = PickerPlacement.frame(size: size,
                                                  cursor: CGPoint(x: -20, y: -170),
                                                  screen: negative)
        #expect(negative.contains(negativePanel))
        #expect(!negativePanel.contains(CGPoint(x: -20, y: -170)))
    }

    @Test func ignoresLinkGeometryBecauseTheCursorIsTheOnlyAnchor() {
        let cursor = CGPoint(x: 350, y: 350)
        let panel = PickerPlacement.frame(size: size, cursor: cursor, screen: screen)

        // A link can span the entire display; it cannot influence the placement.
        let enormousLink = CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)
        #expect(enormousLink.contains(cursor))
        #expect(panel == CGRect(x: 360, y: 190, width: 200, height: 150))
    }

    @Test func appearanceDefaultsAndClampsInvalidValues() {
        #expect(PickerAppearance.default == PickerAppearance())
        #expect(PickerAppearance.default.opacity == PickerAppearance.defaultOpacity)

        let appearance = PickerAppearance(usesCustomColor: true,
                                          red: .nan,
                                          green: -2,
                                          blue: 3,
                                          opacity: .nan)
        #expect(appearance.usesCustomColor)
        #expect(appearance.red == 0)
        #expect(appearance.green == 0)
        #expect(appearance.blue == 1)
        #expect(appearance.opacity == PickerAppearance.defaultOpacity)

        let bounded = PickerAppearance(red: .infinity, green: 0.4, blue: -.infinity, opacity: -1)
        #expect(bounded.red == 0)
        #expect(bounded.green == 0.4)
        #expect(bounded.blue == 0)
        #expect(bounded.opacity == PickerAppearance.opacityRange.lowerBound)
    }

    @Test func customTintContrastAccountsForOpacityAndAccessibility() {
        let black = PickerAppearance(usesCustomColor: true, red: 0, green: 0, blue: 0, opacity: 0.35)
        #expect(!black.prefersLightText(darkMode: false, reduceTransparency: false))
        #expect(black.prefersLightText(darkMode: true, reduceTransparency: false))
        #expect(black.prefersLightText(darkMode: false, reduceTransparency: true))
        let white = PickerAppearance(usesCustomColor: true, red: 1, green: 1, blue: 1, opacity: 1)
        #expect(!white.prefersLightText(darkMode: true, reduceTransparency: false))
    }

    @Test func cursorStaysOutsideAtEdgesAndMidpoints() {
        for x in stride(from: 0, through: 1000, by: 100) {
            for y in stride(from: 0, through: 800, by: 100) {
                let point = CGPoint(x: x, y: y)
                let frame = PickerPlacement.frame(size: CGSize(width: 320, height: 360), cursor: point, screen: screen)
                #expect(screen.contains(frame))
                #expect(!frame.contains(point))
                let dx = max(frame.minX - point.x, point.x - frame.maxX, 0)
                let dy = max(frame.minY - point.y, point.y - frame.maxY, 0)
                #expect(hypot(dx, dy) <= 15)
            }
        }
    }
}
