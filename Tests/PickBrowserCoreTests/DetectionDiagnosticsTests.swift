import Testing
@testable import PickBrowserCore

struct DetectionDiagnosticsTests {
    @Test func retainsMessageCheckWhenReturningThroughMenuBar() {
        var diagnostics = DetectionDiagnostics()
        diagnostics.record("Teams: Link has no HTTP/HTTPS destination [AXLink]")
        diagnostics.record("Teams: No accessible link at pointer [AXMenuBar → AXApplication]")
        diagnostics.record("Teams: No accessible link at pointer [AXMenuBar → AXApplication]")
        #expect(diagnostics.entries.count == 2)
        #expect(diagnostics.entries.first?.contains("AXLink") == true)
        diagnostics.clear()
        #expect(diagnostics.entries.isEmpty)
    }
    @Test func keepsOnlyEightRecentChecks() {
        var diagnostics = DetectionDiagnostics()
        for index in 0..<20 { diagnostics.record("Check \(index)") }
        #expect(diagnostics.entries.count == 8)
        #expect(diagnostics.entries.first == "Check 12")
    }
}
