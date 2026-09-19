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
                 scale: Double,
                 quickOpenTitle: String?,
                 choose: @escaping (BrowserDestination, BrowserOpenMode) -> Void,
                 copy: @escaping () -> Bool,
                 quickOpen: @escaping () -> Void) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        guard let screen else { return }
        let size = PickerSizing.panelSize(destinationCount: destinations.count, scale: scale)
        let frame = PickerPlacement.frame(size: size, cursor: pointer, screen: screen.visibleFrame)
        guard !frame.isEmpty else { return }
        contentView = NSHostingView(rootView: PickerView(link: link,
                                                         destinations: destinations,
                                                         appearance: appearance,
                                                         scale: scale,
                                                         quickOpenTitle: quickOpenTitle,
                                                         choose: choose,
                                                         copy: copy,
                                                         quickOpen: quickOpen))
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
}
