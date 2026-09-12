import AppKit
import SwiftUI
import ServiceManagement
import PickBrowserCore

struct DestinationIcon: View {
    let destination: BrowserDestination
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: destination.applicationURL.path))
            .resizable().frame(width: 26, height: 26).accessibilityHidden(true)
    }
}

struct PickerView: View {
    let link: LinkCandidate
    let destinations: [BrowserDestination]
    let choose: (BrowserDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "link").foregroundStyle(.secondary)
                Text(link.url.host ?? "Open link").font(.system(size: 12, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(destinations) { destination in
                        DestinationButton(destination: destination) { choose(destination) }
                    }
                }.padding(6)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct DestinationButton: View {
    let destination: BrowserDestination
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                DestinationIcon(destination: destination)
                Text(destination.title).font(.system(size: 13, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                if hovered { Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 9).frame(height: 40)
            .background(hovered ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Open in \(destination.title)")
        .accessibilityLabel("Open link in \(destination.title)")
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates = AppUpdater()

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .font(.system(size: 30)).foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PickBrowser").font(.title2.bold())
                    Text("Hover. Choose. Open.").foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(model.trusted ? "Accessibility enabled" : "Allow access to detect links",
                      systemImage: model.trusted ? "checkmark.circle.fill" : "hand.raised")
                    .font(.headline)
                Text("PickBrowser uses macOS Accessibility to read the link under your pointer. Links stay on your Mac and are never saved. Some apps don’t expose link destinations.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !model.trusted {
                    Button("Enable Accessibility", action: model.requestAccessibility)
                        .buttonStyle(.borderedProminent)
                    Text("Enable PickBrowser in System Settings, then return here. Detection starts automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Text("Destinations").font(.headline)
                Spacer()
                if model.refreshing { ProgressView().controlSize(.small) }
                Button("Refresh", action: model.refresh).disabled(model.refreshing)
            }
            if model.destinations.isEmpty {
                Text("No destinations found. Open Chrome, Edge, Brave, or Safari once, then refresh. Chrome-family profiles must use the browser’s standard data folder.")
                    .foregroundStyle(.secondary).font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.orderedDestinations.enumerated()), id: \.element.id) { index, destination in
                            HStack(spacing: 10) {
                                Toggle(isOn: Binding(get: { !model.hiddenIDs.contains(destination.id) },
                                                     set: { model.setVisible($0, id: destination.id) })) {
                                    HStack(spacing: 8) {
                                        DestinationIcon(destination: destination)
                                        Text(destination.title).lineLimit(1).help(destination.title)
                                    }
                                }.toggleStyle(.checkbox)
                                Spacer(minLength: 0)
                                Button { model.move(destination.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                    .disabled(index == 0).accessibilityLabel("Move \(destination.title) up")
                                Button { model.move(destination.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                    .disabled(index == model.destinations.count - 1).accessibilityLabel("Move \(destination.title) down")
                            }.padding(.vertical, 7).padding(.horizontal, 8)
                            if index < model.destinations.count - 1 { Divider() }
                        }
                    }
                }
                .frame(height: min(220, CGFloat(model.destinations.count) * 43))
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
            Text(model.visibleDestinations.isEmpty && !model.destinations.isEmpty
                 ? "All destinations are hidden. Enable one to show the hover picker."
                 : "Hover over a supported link, then choose a destination. Move away to dismiss. Safari manages its own profiles.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Text("Hover delay")
                Spacer()
                TextField("Seconds", value: Binding(get: { model.hoverDelay }, set: model.setHoverDelay),
                          format: .number.precision(.fractionLength(1...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 65)
                    .accessibilityLabel("Hover delay in seconds")
                Text("seconds").foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { model.hoverDelay }, set: model.setHoverDelay),
                   in: HoverTiming.range, step: 0.1).accessibilityLabel("Hover delay")
            Text("0.1–5 seconds. Default: 0.5 seconds.").font(.caption).foregroundStyle(.secondary)
            Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLoginEnabled))
            if model.loginNeedsApproval {
                Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = model.settingsError { Text(error).foregroundStyle(.red).font(.caption) }
            Divider()
            if updates.configured {
                Toggle("Check for updates automatically", isOn: Binding(get: { updates.automaticallyChecks }, set: updates.setAutomaticallyChecks))
                HStack {
                    Text("Downloads from GitHub. You choose when to install.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Check now…", action: updates.check).disabled(!updates.canCheck)
                }
            } else {
                HStack {
                    Text("In-app updates aren’t configured in this build.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("GitHub releases…", action: updates.openReleases)
                }
            }
            if let error = updates.error { Text(error).font(.caption).foregroundStyle(.red) }
            Toggle("Enable troubleshooting", isOn: $model.troubleshootingEnabled)
                .onChange(of: model.troubleshootingEnabled) { _, enabled in
                    if enabled { model.detectionStatus = "Hover over a link in another app, then return here to see the latest check." }
                }
            if model.troubleshootingEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.detectionStatus).textSelection(.enabled)
                    Text("Running copy: \(Bundle.main.bundleURL.path)").textSelection(.enabled)
                    Text("Detection uses read-only accessibility queries. Apps that do not expose links remain unsupported; PickBrowser never forces their screen-reader mode.")
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
            }
            HStack {
                Text("Local only · No link history").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(24).frame(width: 480)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
