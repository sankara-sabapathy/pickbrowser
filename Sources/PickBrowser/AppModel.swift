import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import PickBrowserCore

final class AppModel: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published var paused = false
    @Published private(set) var hoverDelay: TimeInterval
    @Published private(set) var includeNavigationLinks: Bool
    @Published private(set) var pickerAppearance: PickerAppearance
    @Published var troubleshootingEnabled = false {
        didSet {
            if !troubleshootingEnabled { detectionStatus = "Troubleshooting is off." }
        }
    }
    @Published var detectionStatus = "Hover over a link in another app, then return here to see the latest check."
    @Published private(set) var destinations: [BrowserDestination] = []
    @Published private(set) var hiddenIDs: Set<String>
    @Published private(set) var order: [String]
    @Published private(set) var refreshing = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var settingsError: String?
    @Published var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, destinations: [BrowserDestination] = []) {
        self.defaults = defaults
        hoverDelay = HoverTiming.validated(defaults.object(forKey: "hoverDelay") as? Double ?? HoverTiming.defaultDelay)
        includeNavigationLinks = defaults.bool(forKey: "includeNavigationLinks")
        if let data = defaults.data(forKey: "pickerAppearance"),
           let savedAppearance = try? JSONDecoder().decode(PickerAppearance.self, from: data) {
            pickerAppearance = Self.normalized(savedAppearance)
        } else {
            pickerAppearance = PickerAppearance()
        }
        hiddenIDs = Set(defaults.stringArray(forKey: "hiddenDestinations") ?? [])
        order = defaults.stringArray(forKey: "destinationOrder") ?? []
        self.destinations = destinations
    }

    func setHoverDelay(_ delay: TimeInterval) {
        hoverDelay = HoverTiming.validated(delay)
        defaults.set(hoverDelay, forKey: "hoverDelay")
    }

    func setIncludeNavigationLinks(_ include: Bool) {
        includeNavigationLinks = include
        defaults.set(include, forKey: "includeNavigationLinks")
    }

    func setPickerAppearance(_ appearance: PickerAppearance) {
        let normalizedAppearance = Self.normalized(appearance)
        pickerAppearance = normalizedAppearance
        guard let data = try? JSONEncoder().encode(normalizedAppearance) else { return }
        defaults.set(data, forKey: "pickerAppearance")
    }

    func resetPickerAppearance() {
        setPickerAppearance(PickerAppearance())
    }

    private static func normalized(_ appearance: PickerAppearance) -> PickerAppearance {
        PickerAppearance(
            usesCustomColor: appearance.usesCustomColor,
            red: appearance.red,
            green: appearance.green,
            blue: appearance.blue,
            opacity: appearance.opacity
        )
    }

    var orderedDestinations: [BrowserDestination] {
        let indices = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return destinations.sorted { (indices[$0.id] ?? Int.max) < (indices[$1.id] ?? Int.max) }
    }

    var visibleDestinations: [BrowserDestination] {
        orderedDestinations.filter { !hiddenIDs.contains($0.id) }
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        DispatchQueue.global(qos: .utility).async {
            let discovered = MacBrowserCatalog().discover()
            DispatchQueue.main.async {
                self.order = DestinationOrder.reconcile(saved: self.order, discovered: discovered.map(\.id))
                self.destinations = discovered
                self.defaults.set(self.order, forKey: "destinationOrder")
                self.refreshing = false
            }
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setVisible(_ visible: Bool, id: String) {
        if visible { hiddenIDs.remove(id) } else { hiddenIDs.insert(id) }
        defaults.set(hiddenIDs.sorted(), forKey: "hiddenDestinations")
    }

    func move(_ id: String, by offset: Int) {
        let available = orderedDestinations.map(\.id)
        guard let current = available.firstIndex(of: id), available.indices.contains(current + offset),
              let first = order.firstIndex(of: id),
              let second = order.firstIndex(of: available[current + offset]) else { return }
        order.swapAt(first, second)
        defaults.set(order, forKey: "destinationOrder")
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
            settingsError = nil
        } catch {
            loginEnabled = SMAppService.mainApp.status == .enabled
            settingsError = "Could not update launch at login: \(error.localizedDescription)"
        }
    }
}
