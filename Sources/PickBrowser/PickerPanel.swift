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
        ScreenShareShield.apply(to: self)
        setAccessibilityLabel("Choose browser and profile")
    }

    func present(link: LinkCandidate,
                 destinations: [BrowserDestination],
                 appearance: PickerAppearance,
                 quickOpenTitle: String?,
                 choose: @escaping (BrowserDestination) -> Void,
                 copy: @escaping () -> Bool,
                 quickOpen: @escaping () -> Void) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        guard let screen else { return }
        let height = CGFloat(58 + min(max(destinations.count, 1), 7) * 42 + 12)
        let frame = PickerPlacement.frame(size: CGSize(width: 320, height: height), cursor: pointer, screen: screen.visibleFrame)
        guard !frame.isEmpty else { return }
        contentView = NSHostingView(rootView: PickerView(link: link,
                                                         destinations: destinations,
                                                         appearance: appearance,
                                                         quickOpenTitle: quickOpenTitle,
                                                         choose: choose,
                                                         copy: copy,
                                                         quickOpen: quickOpen))
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
}
