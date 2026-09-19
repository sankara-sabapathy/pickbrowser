import AppKit
import ApplicationServices
import SwiftUI
import PickBrowserCore

/// Explicit developer commands; never invoked during ordinary startup.
enum Diagnostics {
    static func runIfRequested() -> Bool {
        if CommandLine.arguments.contains("--diagnose") {
            let catalog = MacBrowserCatalog().discover()
            let counts = Dictionary(grouping: catalog, by: \.browserName).mapValues(\.count)
            let report: [String: Any] = [
                "accessibilityGranted": AXIsProcessTrusted(),
                "destinationCounts": counts,
                "macOS": ProcessInfo.processInfo.operatingSystemVersionString
            ]
            if let json = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: json, encoding: .utf8) { print(text) }
            return true
        }
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview") {
            guard CommandLine.arguments.indices.contains(index + 1) else {
                fputs("Usage: PickBrowser --render-preview OUTPUT_DIRECTORY\n", stderr)
                exit(2)
            }
            do { try renderPreviews(to: URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)) }
            catch { fputs("Preview failed: \(error)\n", stderr); exit(1) }
            return true
        }
        #endif
        return false
    }

    #if DEBUG
    private static func renderPreviews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destinations = [
            BrowserDestination(id: "com.google.Chrome:Profile 1", browserName: "Chrome", profileName: "Work",
                               applicationURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"), profileDirectory: "Profile 1"),
            BrowserDestination(id: "com.google.Chrome:Default", browserName: "Chrome", profileName: "Personal",
                               applicationURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"), profileDirectory: "Default"),
            BrowserDestination(id: "com.brave.Browser:Default", browserName: "Brave", profileName: "Personal",
                               applicationURL: URL(fileURLWithPath: "/Applications/Brave Browser.app"), profileDirectory: "Default"),
            BrowserDestination(id: "com.apple.Safari", browserName: "Safari", applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"))
        ]
        let model = AppModel(defaults: UserDefaults(suiteName: "app.pickbrowser.preview.\(UUID().uuidString)")!, destinations: destinations)
        model.trusted = false
        model.loginEnabled = false
        model.loginNeedsApproval = false
        let link = LinkCandidate(url: URL(string: "https://example.com")!, sourceID: "preview", bounds: .zero)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            try snapshot(SettingsView(model: model), size: CGSize(width: 480, height: 660),
                         appearance: appearance, to: directory.appendingPathComponent("settings-\(name).png"))
            try snapshot(PickerView(link: link, destinations: destinations, quickOpenTitle: "Chrome"), size: CGSize(width: 320, height: 238),
                         appearance: appearance, to: directory.appendingPathComponent("picker-\(name).png"))
            try snapshot(PickerView(link: link, destinations: destinations), size: CGSize(width: 320, height: 238),
                         appearance: appearance, to: directory.appendingPathComponent("picker-app-\(name).png"))
            for (tintName, tint) in [("dark", 0.0), ("light", 1.0)] {
                let style = PickerAppearance(usesCustomColor: true, red: tint, green: tint, blue: tint, opacity: 0.35)
                try snapshot(PickerView(link: link, destinations: destinations, appearance: style, quickOpenTitle: "Chrome"),
                             size: CGSize(width: 320, height: 238), appearance: appearance,
                             to: directory.appendingPathComponent("picker-\(name)-tint-\(tintName).png"))
            }
        }
        print("Rendered synthetic-data previews in \(directory.path)")
    }

    private static func snapshot<Content: View>(_ content: Content, size: CGSize,
                                               appearance: NSAppearance.Name, to url: URL) throws {
        let view = NSHostingView(rootView: content)
        view.appearance = NSAppearance(named: appearance)
        view.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = view.appearance
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw PreviewError.renderFailed }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw PreviewError.renderFailed }
        try data.write(to: url)
        window.orderOut(nil)
    }

    private enum PreviewError: Error { case renderFailed }
    #endif
}
