import AppKit
import SwiftUI
import ServiceManagement
import PickBrowserCore

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
                    if model.permissionPreviouslyGranted {
                        Text("Access was enabled before. macOS no longer recognizes this updated copy. In Accessibility settings, remove the old PickBrowser entry and add the current copy from Applications, then quit and reopen PickBrowser. This app cannot grant itself access.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                Text("No destinations found. Open Chrome, Edge, Brave, or Safari once, then refresh.")
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
                 : "Hover over a supported link, then choose a destination. Move away to dismiss.")
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
            Toggle("Include navigation links", isOn: Binding(get: { model.includeNavigationLinks }, set: model.setIncludeNavigationLinks))
            Text("Off by default. Includes navigation and button-like links only when the app identifies them as hyperlinks with an HTTP or HTTPS destination.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Background opacity")
                        Spacer()
                        Text(model.pickerAppearance.opacity, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: pickerOpacity, in: PickerAppearance.opacityRange, step: 0.01)
                        .accessibilityLabel("Picker background opacity")
                    Toggle("Use custom background color", isOn: useCustomBackgroundColor)
                    if model.pickerAppearance.usesCustomColor {
                        ColorPicker("Background color", selection: pickerBackgroundColor, supportsOpacity: false)
                    }
                    Button("Reset appearance", action: model.resetPickerAppearance)
                }
                .padding(.top, 6)
            }
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
                    DisclosureGroup("Recent checks (temporary, no URLs)") {
                        ForEach(Array(model.detectionDiagnostics.entries.enumerated()), id: \.offset) { _, entry in
                            Text(entry).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
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

    private var pickerOpacity: Binding<Double> {
        Binding(
            get: { model.pickerAppearance.opacity },
            set: { opacity in
                let appearance = model.pickerAppearance
                model.setPickerAppearance(PickerAppearance(
                    usesCustomColor: appearance.usesCustomColor,
                    red: appearance.red,
                    green: appearance.green,
                    blue: appearance.blue,
                    opacity: opacity
                ))
            }
        )
    }

    private var useCustomBackgroundColor: Binding<Bool> {
        Binding(
            get: { model.pickerAppearance.usesCustomColor },
            set: { usesCustomColor in
                let appearance = model.pickerAppearance
                model.setPickerAppearance(PickerAppearance(
                    usesCustomColor: usesCustomColor,
                    red: appearance.red,
                    green: appearance.green,
                    blue: appearance.blue,
                    opacity: appearance.opacity
                ))
            }
        )
    }

    private var pickerBackgroundColor: Binding<Color> {
        Binding(
            get: {
                let appearance = model.pickerAppearance
                return Color(.sRGB, red: appearance.red, green: appearance.green, blue: appearance.blue, opacity: 1)
            },
            set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                let appearance = model.pickerAppearance
                model.setPickerAppearance(PickerAppearance(
                    usesCustomColor: appearance.usesCustomColor,
                    red: Double(rgb.redComponent),
                    green: Double(rgb.greenComponent),
                    blue: Double(rgb.blueComponent),
                    opacity: appearance.opacity
                ))
            }
        )
    }
}
