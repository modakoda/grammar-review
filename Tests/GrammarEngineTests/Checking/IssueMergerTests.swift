import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct IssueMergerTests {
    @Test func aiIssueReplacesOverlappingLocalSpelling() {
        let local = [issue(6, "teh", replacements: ["the"])]
        let ai = [issue(2, "has teh", .grammar, source: .ai, replacements: ["have the"])]
        let merged = IssueMerger.merge(local: local, ai: ai, settings: AppSettings())
        #expect(merged.map(\.source) == [.ai])
        #expect(merged.map(\.originalText) == ["has teh"])
    }

    @Test func aiSpellingGetsLocalGuessesAppendedDeduplicated() {
        let local = [issue(6, "teh", replacements: ["the", "tea", "ten"])]
        let ai = [issue(6, "teh", .spelling, source: .ai, replacements: ["the"])]
        let merged = IssueMerger.merge(local: local, ai: ai, settings: AppSettings())
        #expect(merged.count == 1)
        #expect(merged[0].source == .ai)
        #expect(merged[0].replacements == ["the", "tea", "ten"])
    }

    @Test func keepsNonOverlappingLocalIssuesAndSorts() {
        let local = [issue(20, "wrod"), issue(0, "Ths")]
        let ai = [issue(4, "is", .grammar, source: .ai, replacements: ["are"])]
        let merged = IssueMerger.merge(local: local, ai: ai, settings: AppSettings())
        #expect(merged.map(\.range.location) == [0, 4, 20])
    }

    @Test func filtersDisabledCategories() {
        var settings = AppSettings()
        settings.enabledCategories = [.spelling, .grammar]
        let ai = [issue(0, "very unique", .style, source: .ai), issue(20, "has", .grammar, source: .ai)]
        let merged = IssueMerger.merge(local: [issue(30, "teh")], ai: ai, settings: settings)
        #expect(merged.map(\.category) == [.grammar, .spelling])
    }

    @Test func personalDictionaryDropsSpellingOnly() {
        var settings = AppSettings()
        settings.personalDictionary = ["Kazinauskas"]
        let local = [issue(0, "kazinauskas")]
        let ai = [issue(20, "Kazinauskas", .spelling, source: .ai), issue(40, "Kazinauskas", .grammar, source: .ai)]
        let merged = IssueMerger.merge(local: local, ai: ai, settings: settings)
        #expect(merged.map(\.range.location) == [40])
    }

    @Test func deduplicatesIdenticalRangesPreferringAI() {
        let ai = [issue(5, "teh", .grammar, source: .ai), issue(5, "teh", .spelling, source: .ai)]
        let merged = IssueMerger.merge(local: [], ai: ai, settings: AppSettings())
        #expect(merged.count == 1)
        #expect(merged[0].category == .grammar)
    }
}
