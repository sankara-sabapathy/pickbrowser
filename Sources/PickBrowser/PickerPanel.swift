import AppKit
import SwiftUI
import PickBrowserCore

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        setAccessibilityLabel("Choose browser and profile")
    }

    func present(link: LinkCandidate, destinations: [BrowserDestination], choose: @escaping (BrowserDestination) -> Void) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        guard let screen else { return }
        let height = CGFloat(45 + min(destinations.count, 7) * 42 + 12)
        let frame = PickerPlacement.frame(size: CGSize(width: 300, height: height), link: link.bounds, screen: screen.visibleFrame)
        contentView = NSHostingView(rootView: PickerView(link: link, destinations: destinations, choose: choose))
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
}
