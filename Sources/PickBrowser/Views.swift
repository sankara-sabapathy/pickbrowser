import AppKit
import SwiftUI
import PickBrowserCore

struct DestinationIcon: View {
    let destination: BrowserDestination
    var size: CGFloat = 26

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: destination.applicationURL.path))
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct PickerView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false
    let link: LinkCandidate
    let destinations: [BrowserDestination]
    let appearance: PickerAppearance
    let scale: Double
    let quickOpenTitle: String?
    let choose: (BrowserDestination, BrowserOpenMode) -> Void
    let copy: () -> Bool
    let quickOpen: () -> Void

    init(link: LinkCandidate,
         destinations: [BrowserDestination],
         appearance: PickerAppearance = .default,
         scale: Double = PickerSizing.defaultScale,
         quickOpenTitle: String? = nil,
         choose: @escaping (BrowserDestination, BrowserOpenMode) -> Void = { _, _ in },
         copy: @escaping () -> Bool = { false },
         quickOpen: @escaping () -> Void = {}) {
        self.link = link
        self.destinations = destinations
        self.appearance = appearance
        self.scale = PickerSizing.validated(scale)
        self.quickOpenTitle = quickOpenTitle
        self.choose = choose
        self.copy = copy
        self.quickOpen = quickOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(foreground.opacity(0.14))
            ScrollView {
                VStack(spacing: 2 * scaled) {
                    ForEach(destinations) { destination in
                        DestinationButton(destination: destination, foreground: foreground, scale: scaled,
                                          open: { choose(destination, .normal) },
                                          openPrivately: { choose(destination, .privateWindow) })
                    }
                }
                .padding(6 * scaled)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(foreground)
        .background(surface)
        .overlay(RoundedRectangle(cornerRadius: 14 * scaled).stroke(foreground.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scaled))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12 * scaled, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.72))
            Text(previewTitle)
                .font(.system(size: 12 * scaled, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(link.url.absoluteString)
            Spacer(minLength: 0)
            Button { copied = copy() } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 18 * scaled, height: 18 * scaled)
            }
            .buttonStyle(.plain)
            .help(copied ? "Link copied" : "Copy link address")
            .accessibilityLabel(copied ? "Link copied" : "Copy link address")
            .accessibilityHint("Copies the full link address")

            if let quickOpenTitle {
                Button(action: quickOpen) {
                    Image(systemName: "plus.square.on.square")
                        .frame(width: 18 * scaled, height: 18 * scaled)
                }
                .buttonStyle(.plain)
                .help("Open in a new tab in \(quickOpenTitle) (browser controls tab and profile routing)")
                .accessibilityLabel("Open in a new tab in \(quickOpenTitle)")
            }
        }
        .padding(.horizontal, 14 * scaled)
        .padding(.vertical, 12 * scaled)
    }

    private var previewTitle: String {
        link.url.host(percentEncoded: false) ?? link.url.absoluteString
    }

    private var scaled: CGFloat { CGFloat(scale) }

    private var foreground: Color {
        guard appearance.usesCustomColor else { return .primary }
        return appearance.prefersLightText(darkMode: colorScheme == .dark, reduceTransparency: reduceTransparency)
            ? .white : .black
    }

    @ViewBuilder
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: 14 * scaled)
        if appearance.usesCustomColor {
            let tint = Color(red: appearance.red, green: appearance.green, blue: appearance.blue)
            if reduceTransparency {
                shape.fill(tint)
            } else {
                // A blurred material underlay preserves legibility over busy pages.
                shape.fill(.regularMaterial).overlay(shape.fill(tint.opacity(appearance.opacity)))
            }
        } else if reduceTransparency {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else {
            shape.fill(.regularMaterial).opacity(appearance.opacity)
        }
    }
}

private struct DestinationButton: View {
    let destination: BrowserDestination
    let foreground: Color
    let scale: CGFloat
    let open: () -> Void
    let openPrivately: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 2 * scale) {
            Button(action: open) {
                HStack(spacing: 10 * scale) {
                    DestinationIcon(destination: destination, size: 26 * scale)
                    Text(destination.title)
                        .font(.system(size: 13 * scale, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if hovered {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11 * scale))
                            .foregroundStyle(foreground.opacity(0.7))
                    }
                }
                .padding(.leading, 9 * scale)
                .frame(height: 40 * scale)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open in \(destination.title)")
            .accessibilityLabel("Open link in \(destination.title)")
            if destination.supportsPrivateBrowsing {
                Button(action: openPrivately) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .frame(width: 36 * scale, height: 36 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open privately in \(destination.title)")
                .accessibilityLabel("Open link privately in \(destination.title)")
                .accessibilityHint("Opens a private or InPrivate window in the selected browser profile")
            }
        }
        .padding(.trailing, 4 * scale)
        .background(hovered ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 8 * scale))
        .onHover { hovered = $0 }
    }
}
