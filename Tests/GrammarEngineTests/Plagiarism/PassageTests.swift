import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct PassageTests {
    @Test func sentencesOfEightWordsOrMoreAreSearchedWithTheirOffsets() {
        let text = "Short one. 😀 The quick brown fox jumps over the lazy dog today.\n\nAnother line with only six words.\r\nWe hold these truths to be self-evident, that all men are created equal."
        let passages = PassageSampler.passages(in: text)
        #expect(passages.map(\.text) == [
            "😀 The quick brown fox jumps over the lazy dog today.",
            "We hold these truths to be self-evident, that all men are created equal.",
        ])
        for passage in passages {
            #expect(substring(text, passage.range) == passage.text)
        }
        #expect(passages[1].words.prefix(7) == ["we", "hold", "these", "truths", "to", "be", "self"])
        #expect(PassageSampler.query(for: passages[0]) == "\"The quick brown fox jumps over the lazy dog today.\"")
    }

    @Test func longTextsAreSampledEvenly() {
        let passages = (0..<50).map { Passage(range: NSRange(location: $0, length: 1), text: "\($0)", words: []) }
        let sample = PassageSampler.sample(passages, limit: 10)
        #expect(sample.map(\.text) == ["0", "5", "10", "15", "20", "25", "30", "35", "40", "45"])
        #expect(PassageSampler.sample(Array(passages.prefix(3)), limit: 10).count == 3)
    }

    @Test func queriesAreExactPhrasesWithoutInnerQuotes() {
        let passage = Passage(range: NSRange(), text: "He said \u{201C}to be or not to be\u{201D} \"is\" the question.", words: [])
        #expect(PassageSampler.query(for: passage) == "\"He said to be or not to be is the question.\"")
        let long = Passage(range: NSRange(), text: (1...60).map { "word\($0)" }.joined(separator: " "), words: [])
        let query = PassageSampler.query(for: long)
        #expect(query.split(separator: " ").count == PassageSampler.maxQueryWords)
        #expect(query.hasSuffix("word32\""))
    }

    @Test func wordsIgnoreCaseAccentsAndPunctuation() {
        #expect(PassageMatcher.words(in: "Café, CAFÉ — naïve “quotes” don't!") == ["cafe", "cafe", "naive", "quotes", "don", "t"])
    }

    @Test func coverageCountsWordsInSharedRuns() {
        let passage = PassageMatcher.words(in: "the quick brown fox jumps over the lazy dog")
        #expect(PassageMatcher.coverage(of: passage, in: ["… The quick brown fox jumps over the lazy dog …"]).share == 1)
        let half = PassageMatcher.coverage(of: passage, in: ["A quick brown fox jumps", "something else entirely here"])
        #expect(half.words == 4)
        #expect(PassageMatcher.coverage(of: passage, in: ["the dog was lazy and the fox was quick"]).words == 0)
        #expect(PassageMatcher.coverage(of: passage, in: []).share == 0)
    }

    @Test func aResultMatchesWhenMostOfThePassageIsInIt() {
        let passage = Passage(range: NSRange(), text: "", words: PassageMatcher.words(in: "the quick brown fox jumps over the lazy dog"))
        func result(_ description: String, snippets: [String] = []) -> WebSearchResult {
            WebSearchResult(url: URL(string: "https://example.com")!, title: "Example", description: description, snippets: snippets, siteName: "Example")
        }
        #expect(PassageMatcher.matches(passage, result("The quick brown fox jumps over the lazy dog.")) == 1)
        #expect(PassageMatcher.matches(passage, result("The quick brown fox jumps", snippets: ["fox jumps over the lazy dog"])) == 1)
        #expect(PassageMatcher.matches(passage, result("The quick brown fox jumps away.")) == nil)
    }
}
