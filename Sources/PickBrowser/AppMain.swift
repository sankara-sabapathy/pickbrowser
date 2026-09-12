import AppKit
import ApplicationServices
import SwiftUI
import PickBrowserCore

@main
enum PickBrowserMain {
    static func main() {
        let app = NSApplication.shared
        if Diagnostics.runIfRequested() { return }
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter({ !$0.isTerminated })
            .min(by: { $0.processIdentifier < $1.processIdentifier }),
           existing.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            existing.activate(options: [.activateAllWindows])
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let detector = MacLinkDetector()
    private let launcher = MacBrowserLauncher()
    private var coordinator = HoverCoordinator()
    private let picker = PickerPanel()
    private let updates = AppUpdater()
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var timer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var lastPermissionCheck: TimeInterval = 0
    private var launching = false
    private var sleeping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        updates.start()
        detector.onDiagnostic = { [weak self] status in self?.reportDetection(status) }
        reportDetection("Startup: Accessibility \(model.trusted ? "enabled" : "not granted")")
        configureMenu()
        installEventMonitors()
        model.refresh()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.handle(self.coordinator.reset())
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.sleeping = true
            self.handle(self.coordinator.reset())
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.sleeping = true
            self.handle(self.coordinator.reset())
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false
        })
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") || !model.trusted || CommandLine.arguments.contains("--trace-hover") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
        }
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.and.square.on.square.dashed", accessibilityDescription: "PickBrowser")
        statusItem.button?.toolTip = "PickBrowser — hover, choose, open"
        let menu = NSMenu()
        permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PickBrowser", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateMenu()
    }

    private func updateMenu() {
        permissionItem.title = model.trusted ? (model.paused ? "Hover detection paused" : "Hover detection enabled") : "Accessibility permission needed"
        pauseItem.title = model.paused ? "Resume" : "Pause"
        statusItem.button?.appearsDisabled = model.paused || !model.trusted
    }

    private func reportDetection(_ status: String) {
        guard model.troubleshootingEnabled || CommandLine.arguments.contains("--trace-hover") else { return }
        guard model.detectionStatus != status else { return }
        model.detectionStatus = status
        // Opt-in developer tracing contains only status/AX roles, never URLs or text.
        if CommandLine.arguments.contains("--trace-hover") {
            print("PickBrowser: \(status)")
            fflush(stdout)
        }
    }

    @objc private func togglePause() {
        model.paused.toggle()
        handle(coordinator.reset())
        updateMenu()
    }

    @objc private func showSettings() {
        handle(coordinator.reset())
        model.refresh()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "PickBrowser"
            window.contentView = NSHostingView(rootView: SettingsView(model: model, updates: updates))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func tick() {
        let time = ProcessInfo.processInfo.systemUptime
        if time - lastPermissionCheck >= 1 {
            lastPermissionCheck = time
            let trusted = AXIsProcessTrusted()
            if trusted != model.trusted {
                model.trusted = trusted
                reportDetection("Accessibility \(trusted ? "enabled" : "not granted")")
                handle(coordinator.reset())
                installEventMonitors()
                if trusted { model.refresh() }
            }
            updateMenu()
        }
        guard !launching else { return }
        if coordinator.dwell != model.hoverDelay {
            handle(coordinator.reset())
            coordinator = HoverCoordinator(dwell: model.hoverDelay)
        }
        let point = NSEvent.mouseLocation
        let front = NSWorkspace.shared.frontmostApplication
        let source = front.map(MacLinkDetector.sourceID) ?? ""
        let enabled = model.trusted && !model.paused && !sleeping &&
            front?.processIdentifier != ProcessInfo.processInfo.processIdentifier && !model.visibleDestinations.isEmpty
        let overPicker = picker.isVisible && picker.frame.contains(point)
        handle(coordinator.tick(point: point, sourceID: source, time: time, enabled: enabled,
                                mouseDown: NSEvent.pressedMouseButtons != 0 && !overPicker,
                                pickerBounds: picker.isVisible ? picker.frame : nil))
    }

    private func handle(_ actions: [HoverAction]) {
        for action in actions {
            switch action {
            case .dismiss:
                picker.orderOut(nil)
                picker.contentView = nil // Release the dismissed link and its selection closure.
            case .present(let link):
                reportDetection("Picker displayed")
                picker.present(link: link, destinations: model.visibleDestinations) { [weak self] destination in
                    self?.choose(destination, link: link)
                }
            case .detect(let request):
                detector.detect(at: request.point, sourceID: request.sourceID) { [weak self] candidate in
                    guard let self else { return }
                    // Recheck current pointer, permission and foreground state before accepting a result.
                    self.tick()
                    let actions = self.coordinator.resolve(candidate, for: request, time: ProcessInfo.processInfo.systemUptime)
                    self.handle(actions)
                }
            }
        }
    }

    private func choose(_ destination: BrowserDestination, link: LinkCandidate) {
        guard !launching, coordinator.activeLink == link, AXIsProcessTrusted(),
              NSWorkspace.shared.frontmostApplication.map(MacLinkDetector.sourceID) == link.sourceID else {
            handle(coordinator.reset())
            return
        }
        handle(coordinator.dismissAndSuppress(at: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime))
        launch(link.url, destination: destination)
    }

    private func launch(_ url: URL, destination: BrowserDestination) {
        launching = true
        launcher.open(url, in: destination) { [weak self] result in
            guard let self else { return }
            self.launching = false
            if case .failure(let error) = result {
                let alert = NSAlert()
                alert.messageText = "Couldn’t open in \(destination.title)"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "Retry")
                alert.addButton(withTitle: "Cancel")
                NSApp.activate(ignoringOtherApps: true)
                self.launching = true // Do not show hover UI behind the modal error.
                let response = alert.runModal()
                self.launching = false
                if response == .alertFirstButtonReturn { self.launch(url, destination: destination) }
            }
        }
    }

    private func installEventMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        let mask: NSEvent.EventTypeMask = [.scrollWheel, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in self?.observe(event) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if event.window !== self?.picker || event.type == .keyDown { self?.observe(event) }
            return event // Passive observation; source-app input is never swallowed.
        }
    }

    private func observe(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode != 53 { return }
        handle(coordinator.dismissAndSuppress(at: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime))
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
}
