import Foundation
import Testing
@testable import GrammarEngine

@Suite struct SentenceLocatorTests {
    private func sentence(_ text: String, at location: Int, length: Int = 0) -> String? {
        SentenceLocator.sentence(around: NSRange(location: location, length: length), in: text)
            .map { (text as NSString).substring(with: $0) }
    }

    @Test func findsTheSentenceWithTheCaret() {
        let text = "Hello there. How are you today? I am fine."
        #expect(sentence(text, at: 0) == "Hello there.")
        #expect(sentence(text, at: 17) == "How are you today?")
        #expect(sentence(text, at: text.utf16.count) == "I am fine.")
    }

    @Test func aCaretRightAfterASentenceOrInTheGapPicksTheOneBefore() {
        let text = "One sentence.  Two sentences."
        #expect(sentence(text, at: 13) == "One sentence.")
        #expect(sentence(text, at: 14) == "One sentence.")
        #expect(sentence(text, at: 15) == "Two sentences.")
    }

    @Test func abbreviationsDoNotEndASentence() {
        #expect(sentence("Dr. Smith went to Washington. He liked it", at: 6) == "Dr. Smith went to Washington.")
    }

    @Test func staysOnTheCaretsLine() {
        let text = "First line without a stop\nSecond line here. And more"
        #expect(sentence(text, at: 5) == "First line without a stop")
        #expect(sentence(text, at: 30) == "Second line here.")
        #expect(sentence(text, at: 25) == "First line without a stop")
    }

    @Test func aRangeAcrossSentencesCoversThemAll() {
        let text = "One. Two is here. Three."
        #expect(sentence(text, at: 2, length: 8) == "One. Two is here.")
        #expect(sentence(text, at: 5, length: 3) == "Two is here.")
    }

    @Test func countsInUTF16() {
        let text = "Nice 🎉 party. See you 👋 soon."
        let soon = (text as NSString).range(of: "soon").location
        #expect(sentence(text, at: soon) == "See you 👋 soon.")
    }

    @Test func trimsWholeTextToItsContent() {
        let text = "  Dear Ann,\n\nThanks!\n"
        let all = SentenceLocator.trimmed(NSRange(location: 0, length: text.utf16.count), in: text)
        #expect(all.map { (text as NSString).substring(with: $0) } == "Dear Ann,\n\nThanks!")
        #expect(SentenceLocator.trimmed(NSRange(location: 0, length: 3), in: " \n ") == nil)
        #expect(SentenceLocator.trimmed(NSRange(location: 2, length: 9), in: "Short.") == nil)
    }

    @Test func nothingToFind() {
        #expect(sentence("", at: 0) == nil)
        #expect(sentence("Text.\n\n", at: 7) == nil)
        #expect(sentence("   ", at: 1) == nil)
        #expect(SentenceLocator.sentence(around: NSRange(location: 9, length: 0), in: "Short.") == nil)
        #expect(SentenceLocator.sentence(around: NSRange(location: NSNotFound, length: 0), in: "Short.") == nil)
    }
}
