import AppKit
import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct LocalSpellCheckerSmokeTests {
    @Test func flagsObviousMisspellings() async {
        let hasEnglish = await MainActor.run {
            NSSpellChecker.shared.availableLanguages.contains { $0.hasPrefix("en") }
        }
        guard hasEnglish else { return }
        let text = "Ths is a tset"
        let issues = await LocalSpellChecker().misspellings(in: text, language: "en", resolver: LanguageResolver(mode: .fixed("en")), settings: testSettings())
        let flagged = Set(issues.map(\.originalText))
        #expect(!flagged.isDisjoint(with: ["Ths", "tset"]), "flagged: \(flagged)")
        #expect(!flagged.contains("is"))
        for issue in issues {
            #expect(substring(text, issue.range) == issue.originalText)
            #expect(issue.source == .local && issue.category == .spelling)
            #expect(issue.replacements.count <= 3)
        }
    }

    @Test func ignoresCodeAndURLs() async {
        let hasEnglish = await MainActor.run {
            NSSpellChecker.shared.availableLanguages.contains { $0.hasPrefix("en") }
        }
        guard hasEnglish else { return }
        let text = "Open https://exmaple.com/qwzx and run `fooBarBaz --frobnicate` for myVarrName"
        let issues = await LocalSpellChecker().misspellings(in: text, language: "en", resolver: LanguageResolver(mode: .fixed("en")), settings: testSettings())
        #expect(issues.isEmpty, "unexpected: \(issues.map(\.originalText))")
    }
}
