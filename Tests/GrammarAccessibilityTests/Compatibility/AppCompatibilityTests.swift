import AppKit
import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("App compatibility")
struct AppCompatibilityTests {
    @Test(arguments: [
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta", "com.brave.Browser",
        "com.brave.Browser.nightly", "com.microsoft.edgemac", "com.microsoft.edgemac.Dev", "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser", "com.operasoftware.Opera", "com.operasoftware.OperaGX", "org.chromium.Chromium",
    ])
    func chromiumBrowsersAreRecognised(bundleID: String) {
        #expect(AppCompatibility.isChromiumBrowser(bundleID))
        #expect(AppCompatibility.family(bundleID: bundleID, isElectron: false) == .chromium)
    }

    @Test(arguments: ["com.apple.Safari", "com.apple.TextEdit", "com.google.Chromecast", "com.tinyspeck.slackmacgap"])
    func otherAppsAreNotChromium(bundleID: String) {
        #expect(!AppCompatibility.isChromiumBrowser(bundleID))
    }

    @Test func nilBundleIDIsNative() {
        #expect(!AppCompatibility.isChromiumBrowser(nil))
        #expect(AppCompatibility.family(bundleID: nil, isElectron: false) == .native)
    }

    @Test func families() {
        #expect(AppCompatibility.family(bundleID: "com.apple.Safari", isElectron: false) == .webKit)
        #expect(AppCompatibility.family(bundleID: "com.apple.TextEdit", isElectron: false) == .native)
        #expect(AppCompatibility.family(bundleID: "com.tinyspeck.slackmacgap", isElectron: true) == .electron)
    }

    @Test func enhancedUserInterfaceOnlyForChromiumWhenNeeded() {
        typealias C = AppCompatibility
        #expect(!C.needsEnhancedUserInterface(family: .native, manual: .unsupported, probe: nil))
        #expect(!C.needsEnhancedUserInterface(family: .electron, manual: .applied, probe: .empty))
        #expect(C.needsEnhancedUserInterface(family: .chromium, manual: .unsupported, probe: nil))
        #expect(C.needsEnhancedUserInterface(family: .chromium, manual: .failed, probe: nil))
        #expect(!C.needsEnhancedUserInterface(family: .chromium, manual: .applied, probe: nil))
        #expect(!C.needsEnhancedUserInterface(family: .chromium, manual: .applied, probe: .exposed))
        #expect(!C.needsEnhancedUserInterface(family: .chromium, manual: .applied, probe: .unknown))
        #expect(C.needsEnhancedUserInterface(family: .chromium, manual: .applied, probe: .empty))
    }

    @Test func electronAppsAreDetectedByTheirFramework() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GrammarAccessibilityTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let electron = root.appendingPathComponent("Chat.app")
        try FileManager.default.createDirectory(
            at: electron.appendingPathComponent("Contents/Frameworks/Electron Framework.framework"),
            withIntermediateDirectories: true
        )
        let native = root.appendingPathComponent("Notes.app")
        try FileManager.default.createDirectory(at: native.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)

        #expect(AppCompatibility.isElectronApp(at: electron))
        #expect(!AppCompatibility.isElectronApp(at: native))
        #expect(!AppCompatibility.isElectronApp(at: nil))
    }
}
