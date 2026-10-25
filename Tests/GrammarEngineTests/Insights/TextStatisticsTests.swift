import Foundation
import Testing
@testable import GrammarEngine

@Suite struct TextStatisticsTests {
    @Test func countsWordsSentencesAndParagraphs() {
        let stats = TextStatistics(text: "One two three. Four five!\n\nSix seven eight nine?", language: "en")
        #expect(stats.words == 9)
        #expect(stats.sentences == 3)
        #expect(stats.paragraphs == 2)
        #expect(stats.characters == 48)
        #expect(stats.charactersWithoutSpaces == 39)
        #expect(stats.averageSentenceLength == 3)
    }

    @Test func emptyTextHasNoStatistics() {
        let stats = TextStatistics(text: "  \n ", language: "en")
        #expect(stats.words == 0 && stats.sentences == 0 && stats.paragraphs == 0)
        #expect(stats.readingEase == nil && stats.gradeLevel == nil)
        #expect(stats.vocabularyVariety == 0 && stats.averageWordLength == 0)
    }

    @Test func vocabularyVarietyIgnoresCase() {
        let stats = TextStatistics(text: "The cat saw the Cat.", language: "en")
        #expect(stats.vocabularyVariety == 3.0 / 5.0)
    }

    @Test func simpleTextReadsEasierThanDenseText() throws {
        let simple = TextStatistics(text: "The cat sat on the mat. It was a big cat. The dog ran to it. They had fun.", language: "en")
        let dense = TextStatistics(
            text: "Notwithstanding considerable organizational complexity, interdisciplinary collaboration "
                + "necessitates comprehensive institutional accountability mechanisms and continuous evaluation.",
            language: "en"
        )
        let easy = try #require(simple.readingEase)
        let hard = try #require(dense.readingEase)
        #expect(easy > 90)
        #expect(hard < 10)
        #expect(try #require(dense.gradeLevel) > #require(simple.gradeLevel))
        #expect(TextStatistics.readingEaseLabel(easy) == "Very easy")
        #expect(TextStatistics.readingEaseLabel(hard) == "Very difficult")
    }

    @Test func readabilityIsEnglishOnlyAndNeedsEnoughWords() {
        let lithuanian = TextStatistics(text: "Labas rytas, kaip sekasi šiandien? Viskas gerai, ačiū labai.", language: "lt")
        #expect(lithuanian.readingEase == nil)
        #expect(TextStatistics(text: "Too short.", language: "en").readingEase == nil)
        #expect(TextStatistics(text: String(repeating: "word ", count: 12), language: "en-GB").readingEase != nil)
    }

    @Test func longSentencesAreFoundWithTheirRanges() {
        let long = (["Every"] + Array(repeating: "word", count: 30)).joined(separator: " ") + "."
        let text = "Short one. " + long + " Another short one."
        let stats = TextStatistics(text: text, language: "en")
        #expect(stats.longSentences.count == 1)
        #expect(substring(text, stats.longSentences[0]) == long)
    }

    @Test(arguments: [
        ("cat", 1), ("table", 2), ("make", 1), ("makes", 1), ("jumped", 1), ("wanted", 2),
        ("boxes", 2), ("agree", 2), ("beautiful", 3), ("readability", 5), ("every", 3), ("I", 1),
    ])
    func syllableEstimate(word: String, expected: Int) {
        #expect(TextStatistics.syllables(in: word) == expected)
    }

    @Test func timesAndDurations() {
        let stats = TextStatistics(text: String(repeating: "word ", count: 476), language: "en")
        #expect(stats.readingMinutes == 2)
        #expect(TextStatistics.formatDuration(minutes: 0) == "0 sec")
        #expect(TextStatistics.formatDuration(minutes: 0.5) == "30 sec")
        #expect(TextStatistics.formatDuration(minutes: 2.4) == "2 min")
        #expect(TextStatistics.formatDuration(minutes: 60) == "1 hr")
        #expect(TextStatistics.formatDuration(minutes: 65) == "1 hr 5 min")
    }
}
