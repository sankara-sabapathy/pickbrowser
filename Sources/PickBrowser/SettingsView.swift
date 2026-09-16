import AppKit
import SwiftUI
import ServiceManagement
import PickBrowserCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates = AppUpdater()
    @FocusState private var focusedNicknameID: String?
    @State private var savedNicknameID: String?

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
                Label(permissionTitle, systemImage: permissionIcon)
                    .font(.headline)
                Text("PickBrowser uses macOS Accessibility to read the link under your pointer. Links stay on your Mac and are never saved. Some apps don’t expose link destinations.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if accessibilityNeedsRepair {
                    Divider()
                    Label("Action required to restore hover detection", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                    Text("macOS no longer recognizes this copy as approved—usually after an update replaces an ad-hoc signed build, or after permission was revoked. Hover detection is off. Repair access only when this warning is visible:")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("1. Open Accessibility Settings.")
                        Text("2. Remove old PickBrowser entries with the minus button.")
                        Text("3. Add /Applications/PickBrowser.app, then turn it on.")
                        Text("4. Return here. If the status does not update, quit and reopen PickBrowser.")
                    }
                    .font(.caption)
                    .textSelection(.enabled)
                    Button("Open Accessibility Settings…", action: model.requestAccessibility)
                        .buttonStyle(.borderedProminent)
                    Text("Why this happens: current GitHub releases are ad-hoc signed and not Apple-notarized. macOS ties Accessibility approval to an app’s code identity, which can change with an update. This warning does not mean PickBrowser requested new access; its open-source code still uses Accessibility only for link detection. Install updates only from the official project release page.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else if !model.trusted {
                    Button("Enable Accessibility", action: model.requestAccessibility)
                        .buttonStyle(.borderedProminent)
                    Text("Enable PickBrowser in System Settings, then return here. Detection starts automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(accessibilityNeedsRepair ? Color.orange.opacity(0.10) : Color(nsColor: .quaternaryLabelColor).opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if accessibilityNeedsRepair {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.65), lineWidth: 1)
                }
            }

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
                                        Text(destination.detectedTitle).lineLimit(1).help(destination.detectedTitle)
                                    }
                                }.toggleStyle(.checkbox)
                                Spacer(minLength: 0)
                                TextField("Nickname", text: nicknameBinding(for: destination.id))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 108)
                                    .focused($focusedNicknameID, equals: destination.id)
                                    .onSubmit { confirmNicknameSaved(destination.id) }
                                    .help("Optional name shown in the picker. Leave blank to use \(destination.detectedTitle).")
                                    .accessibilityLabel("Nickname for \(destination.detectedTitle)")
                                Group {
                                    if savedNicknameID == destination.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .help(model.nickname(for: destination.id).isEmpty ? "Default name restored" : "Nickname saved")
                                            .accessibilityLabel(model.nickname(for: destination.id).isEmpty ? "Default name restored" : "Nickname saved")
                                    }
                                }
                                .frame(width: 16)
                                Button { model.move(destination.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                    .disabled(index == 0).accessibilityLabel("Move \(destination.detectedTitle) up")
                                Button { model.move(destination.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                    .disabled(index == model.destinations.count - 1).accessibilityLabel("Move \(destination.detectedTitle) down")
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
                        Text("Widget size")
                        Spacer()
                        Text(model.pickerScale, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { model.pickerScale }, set: model.setPickerScale),
                           in: PickerSizing.scaleRange, step: 0.05)
                        .accessibilityLabel("Picker widget size")
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
                    Button("Reset appearance and size", action: model.resetPickerAppearance)
                }
                .padding(.top, 6)
            }
            Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLoginEnabled))
            if model.loginNeedsApproval {
                Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = model.settingsError { Text(error).foregroundStyle(.red).font(.caption) }
            Label("Screen-share shielding is always on", systemImage: "rectangle.slash")
                .font(.callout)
            Text("PickBrowser asks macOS not to capture its windows. Full-screen sharing apps may ignore this system hint; use Pause before sharing when the picker must never appear.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
        .onChange(of: focusedNicknameID) { previous, current in
            if let previous, previous != current {
                savedNicknameID = previous
            }
        }
    }

    private var accessibilityNeedsRepair: Bool {
        !model.trusted && model.permissionPreviouslyGranted
    }

    private var permissionTitle: String {
        if model.trusted { return "Accessibility enabled" }
        return accessibilityNeedsRepair ? "Accessibility needs renewal" : "Allow access to detect links"
    }

    private var permissionIcon: String {
        if model.trusted { return "checkmark.circle.fill" }
        return accessibilityNeedsRepair ? "exclamationmark.triangle.fill" : "hand.raised"
    }

    private func confirmNicknameSaved(_ id: String) {
        savedNicknameID = id
        focusedNicknameID = nil
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

    private func nicknameBinding(for id: String) -> Binding<String> {
        Binding(get: { model.nickname(for: id) },
                set: {
                    savedNicknameID = nil
                    model.setNickname($0, for: id)
                })
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
