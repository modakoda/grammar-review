import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@Suite struct AppVersionTests {
    @Test func describesTheBundleVersion() {
        #expect(AppVersion.description(info: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1"]) == "Version 0.1.0 (1)")
        #expect(AppVersion.description(info: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "0.1.0"]) == "Version 0.1.0")
        #expect(AppVersion.description(info: ["CFBundleShortVersionString": "2.0"]) == "Version 2.0")
        #expect(AppVersion.description(info: [:]) == "Development build")
        #expect(AppVersion.description(info: nil) == "Development build")
    }
}
