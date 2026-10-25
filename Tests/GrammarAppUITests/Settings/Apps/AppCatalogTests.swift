import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct AppCatalogTests {
    @Test func resolvesNamesSortsAndFallsBackToTheBundleID() {
        var lookups: [String] = []
        let installed: [String: URL] = [
            "com.apple.Safari": URL(fileURLWithPath: "/Applications/Safari.app"),
            "com.apple.Notes": URL(fileURLWithPath: "/System/Applications/Notes.app"),
        ]
        let catalog = AppCatalog(
            locate: { id in
                lookups.append(id)
                return installed[id]
            },
            nameForURL: { $0.deletingPathExtension().lastPathComponent }
        )

        let entries = catalog.entries(for: ["com.apple.Safari", "com.example.gone", "com.apple.Notes", "com.apple.dt.Xcode"])
        #expect(entries.map(\.name) == ["Notes", "Safari", "com.example.gone", "Xcode"])
        #expect(entries.map { $0.url != nil } == [true, true, false, false])

        _ = catalog.entries(for: ["com.apple.Safari"])
        #expect(lookups.filter { $0 == "com.apple.Safari" }.count == 1)
    }

    @Test func bundleNameDropsTheExtension() {
        #expect(AppCatalog.bundleName(URL(fileURLWithPath: "/nonexistent/Some Tool.app")) == "Some Tool")
    }

    @Test func everyDefaultDisabledAppHasAKnownName() {
        for id in AppSettings.defaultDisabledBundleIDs {
            #expect(AppCatalog.knownNames[id] != nil, "missing name for \(id)")
        }
    }
}
