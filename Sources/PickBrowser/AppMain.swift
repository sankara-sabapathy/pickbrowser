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
            handle(coordinator.updateDwell(model.hoverDelay))
        }
        if detector.includeNavigationLinks != model.includeNavigationLinks {
            handle(coordinator.reset())
            detector.includeNavigationLinks = model.includeNavigationLinks
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
                let sourceBrowser = SourceBrowser.forWebpage(link)
                picker.present(link: link, destinations: model.visibleDestinations,
                    appearance: model.pickerAppearance,
                    quickOpenTitle: sourceBrowser?.name,
                    choose: { [weak self] destination in self?.choose(destination, link: link) },
                    copy: { [weak self] in self?.copyLink(link) ?? false },
                    quickOpen: { [weak self] in self?.openInSourceBrowser(link) })
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
        guard canAct(on: link) else { return }
        handle(coordinator.dismissAndSuppress(at: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime))
        launch(link.url, destination: destination)
    }

    private func canAct(on link: LinkCandidate) -> Bool {
        guard !launching, coordinator.activeLink == link, AXIsProcessTrusted(), !model.paused,
              NSWorkspace.shared.frontmostApplication.map(MacLinkDetector.sourceID) == link.sourceID else {
            handle(coordinator.reset())
            return false
        }
        return true
    }

    private func copyLink(_ link: LinkCandidate) -> Bool {
        guard canAct(on: link) else { return false }
        // Explicit Copy is the only clipboard operation. Never inspect existing contents.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(link.url.absoluteString, forType: .string) {
            handle(coordinator.reset())
            let alert = NSAlert()
            alert.messageText = "Couldn’t copy the link"
            alert.informativeText = "The clipboard is unavailable. Please try again."
            launching = true
            alert.runModal()
            launching = false
            return false
        }
        return true
    }

    private func openInSourceBrowser(_ link: LinkCandidate) {
        guard canAct(on: link), let browser = SourceBrowser.forWebpage(link),
              let source = NSWorkspace.shared.frontmostApplication,
              source.bundleIdentifier == browser.rawValue, let applicationURL = source.bundleURL else { return }
        handle(coordinator.dismissAndSuppress(at: NSEvent.mouseLocation, time: ProcessInfo.processInfo.systemUptime))
        launchInSourceBrowser(link.url, applicationURL: applicationURL, browser: browser)
    }

    private func launchInSourceBrowser(_ url: URL, applicationURL: URL, browser: SourceBrowser) {
        guard WebURL.validated(url.absoluteString) != nil,
              Bundle(url: applicationURL)?.bundleIdentifier == browser.rawValue else {
            reportSourceBrowserFailure(url, applicationURL: applicationURL, browser: browser,
                message: "The source browser is no longer available at its original location.")
            return
        }
        launching = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Deliver one URL to the exact source browser. No Apple Events, synthesized
        // keyboard input, or default-browser fallback. Its tab/profile policy applies.
        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.launching = false
                guard let error else { return }
                self.reportSourceBrowserFailure(url, applicationURL: applicationURL,
                    browser: browser, message: error.localizedDescription)
            }
        }
    }

    private func reportSourceBrowserFailure(_ url: URL, applicationURL: URL, browser: SourceBrowser, message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t open in \(browser.name)"
        alert.informativeText = message
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        launching = true
        let response = alert.runModal()
        launching = false
        if response == .alertFirstButtonReturn {
            DispatchQueue.main.async { [weak self] in
                self?.launchInSourceBrowser(url, applicationURL: applicationURL, browser: browser)
            }
        }
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
