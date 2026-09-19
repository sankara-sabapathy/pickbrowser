import Testing
import Foundation
@testable import PickBrowserCore

struct ProfileTests {
    private func fixture() throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "LocalState", withExtension: "json", subdirectory: "Fixtures")))
    }

    @Test func profilesExcludeUnsafeEphemeralAndGuestEntries() throws {
        let profiles = ProfileMetadata.parse(try fixture())
        #expect(profiles.map(\.directory) == ["Default", "Profile 1"])
        #expect(profiles.map(\.name) == ["Personal", "Work"])
    }

    @Test func malformedMetadataIsSilent() {
        for text in ["not json", "{}", "{\"profile\":[]}", "{\"profile\":{\"info_cache\":{}}}"] {
            #expect(ProfileMetadata.parse(Data(text.utf8)).isEmpty)
        }
    }

    @Test func urlValidation() {
        for value in ["https://example.com/a?q=hello%20world#part", "http://localhost:8080/path", "HTTPS://example.com"] {
            #expect(WebURL.validated(value) != nil, "\(value)")
        }
        for value in ["javascript:alert(1)", "file:///tmp/test", "mailto:a@example.com", "example.com", "https:///", "https://example.com/\n", "--profile-directory=Other"] {
            #expect(WebURL.validated(value) == nil, "\(value)")
        }
    }

    @Test func verifiedLinkValuesCanNormalizeMissingHTTPS() {
        #expect(WebURL.fromExplicitLinkValue("conduktor.io/blog/kafka")?.absoluteString == "https://conduktor.io/blog/kafka")
        #expect(WebURL.fromExplicitLinkValue("localhost:3000/docs")?.absoluteString == "https://localhost:3000/docs")
        #expect(WebURL.fromExplicitLinkValue("https://example.com/docs")?.absoluteString == "https://example.com/docs")
        for value in ["Home", "Learn more", "/relative", "//example.com", "javascript:alert(1)", "example.com@evil.test"] {
            #expect(WebURL.fromExplicitLinkValue(value) == nil, "\(value)")
        }
    }

    @Test func orderPreservesMissingDestinationsAndAppendsNewOnes() {
        #expect(DestinationOrder.reconcile(saved: ["brave", "chrome", "brave"], discovered: ["chrome", "safari"]) ==
                ["brave", "chrome", "safari"])
    }

    @Test func destinationNicknameOverridesOnlyItsDisplayTitle() {
        let application = URL(fileURLWithPath: "/Applications/Test.app")
        let destination = BrowserDestination(id: "test:work", browserName: "Test", profileName: "Work",
                                             applicationURL: application)
        let renamed = destination.withNickname("  Client browsing  ")

        #expect(destination.title == "Test · Work")
        #expect(renamed.title == "Client browsing")
        #expect(renamed.detectedTitle == destination.detectedTitle)
        #expect(renamed.id == destination.id)
        #expect(renamed.applicationURL == application)
        #expect(destination.withNickname("  ").nickname == nil)
    }

    @Test func destinationNicknamesAreSingleLineAndBounded() {
        #expect(DestinationNickname.normalized("Work\nProfile") == "Work Profile")
        #expect(DestinationNickname.normalized(String(repeating: "x", count: 50))?.count == 40)
        #expect(DestinationNickname.normalized(nil) == nil)
    }

    @Test func privateActionIsOnlyAvailableForKnownChromiumDestinations() {
        let application = URL(fileURLWithPath: "/Applications/Browser.app")
        for id in ["com.google.Chrome:Default", "com.microsoft.edgemac:Profile 1", "com.brave.Browser:Default"] {
            let destination = BrowserDestination(id: id, browserName: "Browser", applicationURL: application,
                                                 profileDirectory: "Default")
            #expect(destination.supportsPrivateBrowsing)
        }
        #expect(!BrowserDestination(id: "com.apple.Safari", browserName: "Safari",
                                    applicationURL: application).supportsPrivateBrowsing)
        #expect(!BrowserDestination(id: "unknown:Default", browserName: "Unknown",
                                    applicationURL: application, profileDirectory: "Default").supportsPrivateBrowsing)
    }

    @Test func launchKeepsURLAndProfileAsSeparateArguments() throws {
        try withBrowser { root, destination in
            let url = URL(string: "https://example.com/?q=$(touch%20bad)&x=%22quoted%22")!
            let command = try LaunchCommand.chromium(url: url, destination: destination)
            #expect(command.arguments == ["--user-data-dir=\(root.path)", "--profile-directory=Profile 1", url.absoluteString])
        }
    }

    @Test func privateLaunchUsesBrowserSpecificSwitchAfterProfileAndBeforeURL() throws {
        let url = URL(string: "https://example.com/private?q=one%20two")!
        for (id, flag) in [("com.google.Chrome:Profile 1", "--incognito"),
                           ("com.microsoft.edgemac:Profile 1", "--inprivate"),
                           ("com.brave.Browser:Profile 1", "--incognito")] {
            try withBrowser(id: id) { root, destination in
                let command = try LaunchCommand.chromium(url: url, destination: destination, mode: .privateWindow)
                #expect(command.arguments == ["--user-data-dir=\(root.path)",
                                              "--profile-directory=Profile 1", flag, url.absoluteString])
            }
        }
    }

    @Test func privateLaunchCannotFallBackToUnrecognizedDestination() throws {
        try withBrowser { _, destination in
            do {
                _ = try LaunchCommand.chromium(url: URL(string: "https://example.com")!,
                                               destination: destination, mode: .privateWindow)
                Issue.record("Unknown browser should not receive a private launch command")
            } catch {
                #expect(error as? LaunchError == .privateModeUnavailable)
            }
        }
    }

    @Test func privateLaunchStillRejectsRemovedProfile() throws {
        try withBrowser(id: "com.google.Chrome:Profile 1") { root, destination in
            try FileManager.default.removeItem(at: root.appendingPathComponent("Profile 1/Preferences"))
            do {
                _ = try LaunchCommand.chromium(url: URL(string: "https://example.com")!,
                                               destination: destination, mode: .privateWindow)
                Issue.record("Removed profile should not be recreated for a private launch")
            } catch {
                #expect(error as? LaunchError == .missingProfile)
            }
        }
    }

    @Test func deletedProfileDoesNotCreateReplacement() throws {
        try withBrowser { root, destination in
            try FileManager.default.removeItem(at: root.appendingPathComponent("Profile 1/Preferences"))
            #expect(throws: LaunchError.self) {
                try LaunchCommand.chromium(url: URL(string: "https://example.com")!, destination: destination)
            }
        }
    }

    @Test func removedMetadataEntryRejectsLaunch() throws {
        try withBrowser { root, destination in
            try Data("{}".utf8).write(to: root.appendingPathComponent("Local State"))
            #expect(throws: LaunchError.self) {
                try LaunchCommand.chromium(url: URL(string: "https://example.com")!, destination: destination)
            }
        }
    }

    @Test func redirectedProfileSymlinkIsRejected() throws {
        try withBrowser { root, destination in
            let profile = root.appendingPathComponent("Profile 1")
            let other = root.appendingPathComponent("Elsewhere")
            try FileManager.default.moveItem(at: profile, to: other)
            try FileManager.default.createSymbolicLink(at: profile, withDestinationURL: other)
            #expect(throws: LaunchError.self) {
                try LaunchCommand.chromium(url: URL(string: "https://example.com")!, destination: destination)
            }
        }
    }

    private func withBrowser(id: String = "test:Profile 1", _ body: (URL, BrowserDestination) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PickBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Profile 1"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try fixture().write(to: root.appendingPathComponent("Local State"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("Profile 1/Preferences"))
        let destination = BrowserDestination(id: id, browserName: "Test", profileName: "Work",
            applicationURL: root, executableURL: URL(fileURLWithPath: "/usr/bin/true"), userDataURL: root, profileDirectory: "Profile 1")
        try body(root, destination)
    }
}
