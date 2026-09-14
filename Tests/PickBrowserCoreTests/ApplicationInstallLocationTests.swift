import Foundation
import Testing
@testable import PickBrowserCore

@Suite struct ApplicationInstallLocationTests {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    @Test func systemAndUserApplicationsAreStableLocations() {
        #expect(!requiresInstall("/Applications/PickBrowser.app"))
        #expect(!requiresInstall("/Applications/Utilities/PickBrowser.app"))
        #expect(!requiresInstall("/Users/example/Applications/PickBrowser.app"))
    }

    @Test func diskImageDownloadsAndTranslocationRequireInstallation() {
        #expect(requiresInstall("/Volumes/PickBrowser/PickBrowser.app"))
        #expect(requiresInstall("/Users/example/Downloads/PickBrowser.app"))
        #expect(requiresInstall("/private/var/folders/xx/AppTranslocation/ABC/d/PickBrowser.app"))
        #expect(requiresInstall("/Applications Backup/PickBrowser.app"))
    }

    @Test func commandLineDevelopmentBuildsRemainRunnable() {
        #expect(!requiresInstall("/Users/example/code/pickbrowser/.build/debug/PickBrowser"))
    }

    private func requiresInstall(_ path: String) -> Bool {
        ApplicationInstallLocation.requiresInstallation(
            bundleURL: URL(fileURLWithPath: path), homeDirectory: home
        )
    }
}
