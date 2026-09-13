import AppKit
import SwiftUI
import PickBrowserCore

struct DestinationIcon: View {
    let destination: BrowserDestination

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: destination.applicationURL.path))
            .resizable()
            .frame(width: 26, height: 26)
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
    let quickOpenTitle: String?
    let choose: (BrowserDestination) -> Void
    let copy: () -> Bool
    let quickOpen: () -> Void

    init(link: LinkCandidate,
         destinations: [BrowserDestination],
         appearance: PickerAppearance = .default,
         quickOpenTitle: String? = nil,
         choose: @escaping (BrowserDestination) -> Void = { _ in },
         copy: @escaping () -> Bool = { false },
         quickOpen: @escaping () -> Void = {}) {
        self.link = link
        self.destinations = destinations
        self.appearance = appearance
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
                VStack(spacing: 2) {
                    ForEach(destinations) { destination in
                        DestinationButton(destination: destination, foreground: foreground) {
                            choose(destination)
                        }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(foreground)
        .background(surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(foreground.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.72))
            Text(previewTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(link.url.absoluteString)
            Spacer(minLength: 0)
            Button { copied = copy() } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(copied ? "Link copied" : "Copy link address")
            .accessibilityLabel(copied ? "Link copied" : "Copy link address")
            .accessibilityHint("Copies the full link address")

            if let quickOpenTitle {
                Button(action: quickOpen) {
                    Image(systemName: "plus.square.on.square")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Open in a new tab in \(quickOpenTitle) (browser controls tab and profile routing)")
                .accessibilityLabel("Open in a new tab in \(quickOpenTitle)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var previewTitle: String {
        link.url.host(percentEncoded: false) ?? link.url.absoluteString
    }

    private var foreground: Color {
        guard appearance.usesCustomColor else { return .primary }
        return appearance.prefersLightText(darkMode: colorScheme == .dark, reduceTransparency: reduceTransparency)
            ? .white : .black
    }

    @ViewBuilder
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
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
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                DestinationIcon(destination: destination)
                Text(destination.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if hovered {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundStyle(foreground.opacity(0.7))
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 40)
            .background(hovered ? Color.accentColor.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Open in \(destination.title)")
        .accessibilityLabel("Open link in \(destination.title)")
    }
}
