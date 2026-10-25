import Foundation
import Testing
@testable import GrammarAppUI

@Suite struct UpdaterConfigurationTests {
    static let feed = "https://modakoda.github.io/grammar-review/appcast.xml"
    static let key = Data(repeating: 7, count: 32).base64EncodedString()

    private func configuration(feed: Any? = Self.feed, key: Any? = Self.key) -> UpdaterConfiguration {
        var info: [String: Any] = ["CFBundleIdentifier": "com.grammarreview.app"]
        info["SUFeedURL"] = feed
        info["SUPublicEDKey"] = key
        return UpdaterConfiguration(info: info)
    }

    @Test func enabledWithAnHTTPSFeedAndAPublicKey() {
        let configuration = configuration()
        #expect(configuration.isEnabled)
        #expect(configuration.feedURL == URL(string: Self.feed))
        #expect(UpdaterConfiguration(info: ["SUFeedURL": "HTTPS://example.com/appcast.xml", "SUPublicEDKey": Self.key]).isEnabled)
    }

    @Test func developmentBuildsHaveNoKey() {
        #expect(!configuration(key: nil).isEnabled)
        #expect(!configuration(key: "").isEnabled)
        #expect(configuration(key: nil).feedURL == nil)
    }

    @Test func keyMustBeAnEdDSAPublicKey() {
        #expect(!configuration(key: "not base64!").isEnabled)
        #expect(!configuration(key: Data(repeating: 1, count: 16).base64EncodedString()).isEnabled, "wrong length")
        #expect(!configuration(key: " \(Self.key)").isEnabled, "Sparkle doesn't trim it either")
        #expect(!configuration(key: 42).isEnabled)
    }

    @Test func feedMustBeHTTPS() {
        #expect(!configuration(feed: nil).isEnabled)
        #expect(!configuration(feed: "").isEnabled)
        #expect(!configuration(feed: "http://modakoda.github.io/grammar-review/appcast.xml").isEnabled)
        #expect(!configuration(feed: "file:///tmp/appcast.xml").isEnabled)
        #expect(!configuration(feed: "https://").isEnabled)
        #expect(!configuration(feed: "appcast.xml").isEnabled)
    }

    @Test func noInfoPlist() {
        #expect(!UpdaterConfiguration(info: nil).isEnabled)
        #expect(!UpdaterConfiguration(info: [:]).isEnabled)
    }

    @Test func bundledInfoPlistNeedsOnlyTheKey() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Info.plist")
        var info = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        #expect(info["SUFeedURL"] as? String == Self.feed)
        #expect(info["SUPublicEDKey"] == nil, "scripts/build-app.sh adds it from SPARKLE_PUBLIC_KEY")
        #expect(!UpdaterConfiguration(info: info).isEnabled)
        info["SUPublicEDKey"] = Self.key
        #expect(UpdaterConfiguration(info: info).isEnabled)
    }
}

@MainActor
@Suite struct UpdateMenuStateTests {
    final class FakeUpdater: AppUpdater {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = true
        var pendingUpdateVersion: String?

        func checkForUpdates() {}
    }

    @Test func followsTheUpdater() {
        #expect(UpdateMenuState(updater: nil) == .unavailable)
        let updater = FakeUpdater()
        #expect(UpdateMenuState(updater: updater) == .ready)
        updater.canCheckForUpdates = false
        #expect(UpdateMenuState(updater: updater) == .checking)
        updater.pendingUpdateVersion = "0.2.0"
        #expect(UpdateMenuState(updater: updater) == .updateAvailable("0.2.0"))
    }
}
