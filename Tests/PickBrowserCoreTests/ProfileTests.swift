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

    @Test func orderPreservesMissingDestinationsAndAppendsNewOnes() {
        #expect(DestinationOrder.reconcile(saved: ["brave", "chrome", "brave"], discovered: ["chrome", "safari"]) ==
                ["brave", "chrome", "safari"])
    }

    @Test func launchKeepsURLAndProfileAsSeparateArguments() throws {
        try withBrowser { root, destination in
            let url = URL(string: "https://example.com/?q=$(touch%20bad)&x=%22quoted%22")!
            let command = try LaunchCommand.chromium(url: url, destination: destination)
            #expect(command.arguments == ["--user-data-dir=\(root.path)", "--profile-directory=Profile 1", url.absoluteString])
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

    private func withBrowser(_ body: (URL, BrowserDestination) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PickBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Profile 1"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try fixture().write(to: root.appendingPathComponent("Local State"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("Profile 1/Preferences"))
        let destination = BrowserDestination(id: "test:Profile 1", browserName: "Test", profileName: "Work",
            applicationURL: root, executableURL: URL(fileURLWithPath: "/usr/bin/true"), userDataURL: root, profileDirectory: "Profile 1")
        try body(root, destination)
    }
}
