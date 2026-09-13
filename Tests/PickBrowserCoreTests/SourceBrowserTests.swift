import Testing
import Foundation
import CoreGraphics
@testable import PickBrowserCore

struct SourceBrowserTests {
    private func link(_ source: String, web: Bool = true) -> LinkCandidate {
        LinkCandidate(url: URL(string: "https://example.com")!, sourceID: source,
                      bounds: CGRect(x: 10, y: 10, width: 60, height: 20), isWebContent: web)
    }

    @Test func shortcutRequiresKnownBrowserAndWebContentEvidence() {
        for browser in SourceBrowser.allCases {
            #expect(SourceBrowser.forWebpage(link("\(browser.rawValue):12")) == browser)
            #expect(SourceBrowser.forWebpage(link("\(browser.rawValue):12", web: false)) == nil)
        }
        #expect(SourceBrowser.forWebpage(link("com.tinyspeck.slackmacgap:12")) == nil)
        #expect(SourceBrowser.forWebpage(link("com.apple.mail:12")) == nil)
        #expect(SourceBrowser.forWebpage(link("com.microsoft.teams2:12")) == nil)
    }

    @Test func malformedSourceCannotEnableShortcut() {
        for source in ["com.google.Chrome", "com.google.Chrome:0", "com.google.Chrome:-1",
                       "com.google.Chrome:x", "com.google.Chrome.fake:12"] {
            #expect(SourceBrowser.forWebpage(link(source)) == nil)
        }
    }
}
