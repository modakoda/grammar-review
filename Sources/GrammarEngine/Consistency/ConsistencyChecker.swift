import Foundation
import GrammarModels

enum ConsistencyChecker {
    static func issues(in text: String, language: String?) -> [TextIssue] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let protected = SpellingFilter.protectedRanges(in: text)
        let words = words(in: ns).filter { word in
            !protected.contains { TextUnits.overlaps($0, word.range) } && !SpellingFilter.looksLikeCode(word.text)
        }
        var issues = HyphenationConsistency.issues(in: words)
        if language.map(SpellingVariantConsistency.isEnglish) ?? true {
            issues += SpellingVariantConsistency.issues(in: words, language: language)
        }
        issues += QuoteConsistency.issues(in: ns, protected: protected)
        return issues.sorted { $0.range.location < $1.range.location }
    }

    struct Word {
        var text: String
        var range: NSRange
    }

    private static let wordPattern = try? NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:[-‐][\p{L}\p{N}]+)*"#)

    static func words(in ns: NSString) -> [Word] {
        guard let wordPattern else { return [] }
        return wordPattern.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).map { match in
            Word(text: ns.substring(with: match.range), range: match.range)
        }
    }

    static func strictMajority(_ values: [String]) -> String? {
        var counts: [String: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        let sorted = counts.sorted { $0.value > $1.value }
        guard let first = sorted.first, sorted.count > 1, first.value > sorted[1].value else { return nil }
        return first.key
    }

    static func matchingCase(of original: String, _ replacement: String) -> String {
        let letters = original.filter(\.isLetter)
        if letters.count > 1, letters.allSatisfy(\.isUppercase) { return replacement.uppercased() }
        if let first = original.first, first.isUppercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    static func issue(_ word: Word, replacement: String, message: String, category: IssueCategory) -> TextIssue {
        TextIssue(
            range: word.range, originalText: word.text, replacements: [replacement],
            message: message, category: category, source: .local
        )
    }
}
