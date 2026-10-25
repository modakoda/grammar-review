import Foundation

public struct TextStatistics: Sendable, Equatable {
    public static let readingWordsPerMinute = 238.0
    public static let speakingWordsPerMinute = 130.0
    public static let longSentenceWords = 30

    public var words: Int
    public var characters: Int
    public var charactersWithoutSpaces: Int
    public var sentences: Int
    public var paragraphs: Int
    public var vocabularyVariety: Double
    public var averageWordLength: Double
    public var averageSentenceLength: Double
    public var longSentences: [NSRange]
    public var readingEase: Double?
    public var gradeLevel: Double?

    public init(text: String, language: String?) {
        characters = text.count
        charactersWithoutSpaces = text.count { !$0.isWhitespace }
        paragraphs = text.split(whereSeparator: \.isNewline)
            .count { !$0.allSatisfy(\.isWhitespace) }

        var wordList: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { wordList.append(word) }
        }
        words = wordList.count
        averageWordLength = wordList.isEmpty ? 0 : Double(wordList.reduce(0) { $0 + $1.count }) / Double(wordList.count)
        vocabularyVariety = wordList.isEmpty ? 0 : Double(Set(wordList.map { $0.lowercased() }).count) / Double(wordList.count)

        var sentenceCount = 0
        var long: [NSRange] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, range, _, _ in
            guard let sentence else { return }
            let count = Self.wordCount(sentence)
            guard count > 0 else { return }
            sentenceCount += 1
            if count > Self.longSentenceWords {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                let full = NSRange(range, in: text)
                let offset = (sentence as NSString).range(of: trimmed).location
                long.append(NSRange(location: full.location + max(0, offset), length: (trimmed as NSString).length))
            }
        }
        sentences = sentenceCount
        longSentences = long
        averageSentenceLength = sentenceCount == 0 ? 0 : Double(words) / Double(sentenceCount)

        if Self.isEnglish(language), words >= 10, sentenceCount > 0 {
            let syllables = Double(wordList.reduce(0) { $0 + Self.syllables(in: $1) })
            let wordsPerSentence = Double(words) / Double(sentenceCount)
            let syllablesPerWord = syllables / Double(words)
            readingEase = min(100, max(0, 206.835 - 1.015 * wordsPerSentence - 84.6 * syllablesPerWord))
            gradeLevel = max(0, 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59)
        } else {
            readingEase = nil
            gradeLevel = nil
        }
    }

    public var readingMinutes: Double { Double(words) / Self.readingWordsPerMinute }
    public var speakingMinutes: Double { Double(words) / Self.speakingWordsPerMinute }

    public static func formatDuration(minutes: Double) -> String {
        let seconds = Int((minutes * 60).rounded())
        if seconds == 0 { return "0 sec" }
        if seconds < 60 { return "\(seconds) sec" }
        let wholeMinutes = Int((Double(seconds) / 60).rounded())
        if wholeMinutes < 60 { return "\(wholeMinutes) min" }
        let hours = wholeMinutes / 60
        let rest = wholeMinutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    public static func readingEaseLabel(_ score: Double) -> String {
        switch score {
        case 90...: "Very easy"
        case 80..<90: "Easy"
        case 70..<80: "Fairly easy"
        case 60..<70: "Plain English"
        case 50..<60: "Fairly difficult"
        case 30..<50: "Difficult"
        default: "Very difficult"
        }
    }

    public static func audience(forReadingEase score: Double) -> String {
        switch score {
        case 80...: "Easily understood by most readers, including 11- to 12-year-olds."
        case 60..<80: "Easily understood by readers aged 13 to 15."
        case 50..<60: "Best for readers with a high-school education."
        case 30..<50: "Best for readers with a college education."
        default: "Best for readers with a university degree; most people will find it hard."
        }
    }

    static func wordCount(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    static func syllables(in word: String) -> Int {
        let letters = word.lowercased().filter(\.isLetter)
        guard !letters.isEmpty else { return 0 }
        if letters.count <= 3 { return 1 }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previousWasVowel = false
        for character in letters {
            let isVowel = vowels.contains(character)
            if isVowel, !previousWasVowel { count += 1 }
            previousWasVowel = isVowel
        }
        if letters.hasSuffix("e"), !letters.hasSuffix("le"), !letters.hasSuffix("ee"), count > 1 {
            count -= 1
        }
        if letters.hasSuffix("ed"), !letters.hasSuffix("ted"), !letters.hasSuffix("ded"), count > 1 {
            count -= 1
        }
        if letters.hasSuffix("es"), count > 1,
           !["ses", "xes", "zes", "ches", "shes", "ces", "ges"].contains(where: letters.hasSuffix) {
            count -= 1
        }
        return max(1, count)
    }

    private static func isEnglish(_ language: String?) -> Bool {
        guard let language else { return false }
        return language == "en" || language.hasPrefix("en-") || language.hasPrefix("en_")
    }
}
