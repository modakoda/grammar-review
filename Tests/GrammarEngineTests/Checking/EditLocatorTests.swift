import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct EditLocatorTests {
    @Test func locatesASingleEdit() {
        let located = EditLocator.locate([edit("has", "have", before: "I ")], in: "I has a cat.")
        #expect(located.count == 1)
        #expect(located[0].range == NSRange(location: 2, length: 3))
        #expect(located[0].originalText == "has")
    }

    @Test func contextPicksTheRightRepeatedWord() {
        let paragraph = "the cat and the dog and the bird"
        let located = EditLocator.locate([edit("the", "a", before: "dog and ")], in: paragraph)
        #expect(located.map(\.range) == [NSRange(location: 24, length: 3)])
    }

    @Test func repeatedEditsWithoutContextTakeSuccessiveOccurrences() {
        let paragraph = "teh cat saw teh dog"
        let located = EditLocator.locate([edit("teh", "the", .spelling), edit("teh", "the", .spelling)], in: paragraph)
        #expect(located.map(\.range.location) == [0, 12])
    }

    @Test func prefersWholeWordsOverMatchesInsideWords() {
        let located = EditLocator.locate([edit("on", "in")], in: "only on Monday")
        #expect(located.map(\.range) == [NSRange(location: 5, length: 2)])
    }

    @Test func approximateContextStillHelps() {
        let paragraph = "I go there. Then I go home."
        let located = EditLocator.locate([edit("go", "went", before: "Thn I ")], in: paragraph)
        #expect(located.map(\.range.location) == [19])
    }

    @Test func emojiOffsetsAreUTF16() {
        let paragraph = "😀 I has a cat"
        let located = EditLocator.locate([edit("has", "have", before: "I ")], in: paragraph)
        #expect(located.map(\.range) == [NSRange(location: 5, length: 3)])
        #expect(substring(paragraph, located[0].range) == "has")
    }

    @Test func zwjSequencesAreSkippedCorrectly() {
        let paragraph = "👨‍👩‍👧 teh family"
        let located = EditLocator.locate([edit("teh", "the", .spelling)], in: paragraph)
        #expect(located.map(\.range) == [NSRange(location: 9, length: 3)])
    }

    @Test func neverSplitsAGraphemeCluster() {
        #expect(EditLocator.locate([edit("👍", "👌")], in: "👍🏽 ok").isEmpty)
        #expect(EditLocator.locate([edit("e", "a")], in: "cafe\u{301}").isEmpty)
    }

    @Test func findsCanonicallyEquivalentText() {
        let paragraph = "Le cafe\u{301} est bon."
        let located = EditLocator.locate([edit("café est", "café était")], in: paragraph)
        #expect(located.count == 1)
        #expect(located[0].originalText == "cafe\u{301} est")
        #expect(substring(paragraph, located[0].range) == located[0].originalText)
    }

    @Test func dropsNoOpsMissingAndEmptyEdits() {
        let located = EditLocator.locate([
            edit("cat", "cat"),
            edit("dog", "hound"),
            edit("", "x"),
        ], in: "I has a cat.")
        #expect(located.isEmpty)
    }

    @Test func dropsEditsOverlappingAnEarlierEdit() {
        let located = EditLocator.locate([edit("has a", "have a"), edit("a cat", "the cat")], in: "I has a cat.")
        #expect(located.map(\.edit.original) == ["has a"])
    }

    @Test func issuesAreOffsetByTheParagraphLocation() {
        let located = EditLocator.locate([edit("has", "have", before: "I ", .grammar, "Use “have” with “I”.")], in: "I has a cat.")
        let issues = EditLocator.issues(from: located, paragraphLocation: 10)
        #expect(issues.count == 1)
        #expect(issues[0].range == NSRange(location: 12, length: 3))
        #expect(issues[0].replacements == ["have"])
        #expect(issues[0].message == "Use “have” with “I”.")
        #expect(issues[0].category == .grammar)
        #expect(issues[0].source == .ai)
    }
}
