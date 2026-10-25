import Foundation
import GrammarModels
import Testing
@testable import GrammarEditor

@MainActor
@Suite struct RewriteTargetTests {
    private func target(_ text: String, _ selection: NSRange) -> RewriteTarget? {
        RewriteTarget.selectionOrParagraph(selection, in: text)
    }

    @Test func aSelectionIsRewrittenWithoutItsOuterSpaces() {
        #expect(target("Hello there, friend.", NSRange(location: 5, length: 8)) == RewriteTarget(range: NSRange(location: 6, length: 6), scope: .selection))
    }

    @Test func aSelectionOfSpacesIsNotWidened() {
        #expect(target("  text", NSRange(location: 0, length: 2)) == nil)
    }

    @Test func aCaretOnABlankLineRewritesAllTheText() {
        let text = "Dear Ann,\n\n\nThanks!"
        #expect(target(text, NSRange(location: 10, length: 0)) == RewriteTarget(range: NSRange(location: 0, length: 19), scope: .paragraph))
    }

    @Test func aSelectionPastTheEndFallsBackToTheCaretsParagraph() {
        #expect(target("One.\nTwo.", NSRange(location: 5, length: 20)) == RewriteTarget(range: NSRange(location: 5, length: 4), scope: .paragraph))
    }

    @Test func blankTextHasNothingToRewrite() {
        #expect(target("", NSRange(location: 0, length: 0)) == nil)
        #expect(target(" \n ", NSRange(location: 1, length: 0)) == nil)
    }
}
