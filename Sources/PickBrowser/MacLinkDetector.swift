import AppKit
import ApplicationServices
import PickBrowserCore

final class MacLinkDetector: LinkDetector {
    private let queue = DispatchQueue(label: "app.pickbrowser.accessibility", qos: .userInitiated)
    // Accessed on the main thread. Do not accumulate work behind a slow accessibility server.
    private var busy = false
    var onDiagnostic: ((String) -> Void)?

    func detect(at point: CGPoint, sourceID: String, completion: @escaping (LinkCandidate?) -> Void) {
        precondition(Thread.isMainThread)
        guard !busy, AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              Self.sourceID(app) == sourceID else { completion(nil); return }
        busy = true
        let pid = app.processIdentifier
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        queue.async {
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.15)
            // Read-only native accessibility handshake. Do not write AXManualAccessibility
            // or AXEnhancedUserInterface: Electron interprets them as screen-reader mode.
            _ = Self.attribute(application, kAXRoleAttribute)
            let result = Self.hitTest(application: application, point: point, primaryHeight: primaryHeight, sourceID: sourceID)
            DispatchQueue.main.async {
                self.busy = false
                self.onDiagnostic?("\(app.bundleIdentifier ?? "Application"): \(result.status)")
                completion(result.candidate)
            }
        }
    }

    static func sourceID(_ application: NSRunningApplication) -> String {
        "\(application.bundleIdentifier ?? "unknown"):\(application.processIdentifier)"
    }

    private static func hitTest(application: AXUIElement, point: CGPoint, primaryHeight: CGFloat,
                                sourceID: String) -> (candidate: LinkCandidate?, status: String) {
        var hit: AXUIElement?
        // Scope the hit test to the source app instead of rejecting by element PID:
        // embedded web content may legitimately belong to a different renderer process.
        let error = AXUIElementCopyElementAtPosition(application, Float(point.x), Float(primaryHeight - point.y), &hit)
        guard error == .success, let hit else {
            return (nil, "Accessibility hit test failed (\(error.rawValue))")
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.75
        let result = AccessibleLinkResolver.resolve(hit: hit, tree: MacLinkTree(primaryHeight: primaryHeight),
            sourceID: sourceID, point: point, budgetExpired: { ProcessInfo.processInfo.systemUptime >= deadline })
        return (result.candidate, "\(result.outcome.rawValue) [\(result.roles.joined(separator: " → "))]")
    }

    fileprivate static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(element, 0.12)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    fileprivate static func bounds(of element: AXUIElement, primaryHeight: CGFloat) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute),
              let size = attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
              origin.x.isFinite, origin.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite,
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(x: origin.x, y: primaryHeight - origin.y - dimensions.height,
                      width: dimensions.width, height: dimensions.height)
    }
}

private struct MacLinkTree: AccessibleLinkTree {
    let primaryHeight: CGFloat
    func role(of element: AXUIElement) -> String? {
        MacLinkDetector.attribute(element, kAXRoleAttribute) as? String
    }
    func linkURL(of element: AXUIElement) -> URL? {
        for key in [kAXURLAttribute, kAXValueAttribute] {
            let raw = MacLinkDetector.attribute(element, key)
            if let string = (raw as? URL)?.absoluteString ?? (raw as? String),
               let url = WebURL.validated(string) { return url }
        }
        return nil
    }
    func bounds(of element: AXUIElement) -> CGRect? {
        MacLinkDetector.bounds(of: element, primaryHeight: primaryHeight)
    }
    func parent(of element: AXUIElement) -> AXUIElement? {
        guard let parent = MacLinkDetector.attribute(element, kAXParentAttribute),
              CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
        return (parent as! AXUIElement)
    }
}
