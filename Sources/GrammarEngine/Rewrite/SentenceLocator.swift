import Foundation
import NaturalLanguage

public enum SentenceLocator {
    public static func sentence(around range: NSRange, in text: String) -> NSRange? {
        let ns = text as NSString
        guard range.location != NSNotFound, range.location >= 0, NSMaxRange(range) <= ns.length else { return nil }
        guard let first = sentence(at: range.location, in: text) else { return nil }
        let end = range.length > 0 ? NSMaxRange(range) - 1 : range.location
        guard end > NSMaxRange(first), let last = sentence(at: end, in: text) else { return first }
        return NSUnionRange(first, last)
    }

    public static func trimmed(_ range: NSRange, in text: String) -> NSRange? {
        let ns = text as NSString
        guard range.location != NSNotFound, range.location >= 0, NSMaxRange(range) <= ns.length else { return nil }
        let trimmed = trimmingWhitespace(range, in: ns)
        return trimmed.length > 0 ? trimmed : nil
    }

    private static func sentence(at location: Int, in text: String) -> NSRange? {
        let ns = text as NSString
        let paragraph = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0))
        guard paragraph.length > 0, let bounds = Range(paragraph, in: text) else { return nil }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [NSRange] = []
        tokenizer.enumerateTokens(in: bounds) { token, _ in
            let trimmed = trimmingWhitespace(NSRange(token, in: text), in: ns)
            if trimmed.length > 0 { sentences.append(trimmed) }
            return true
        }
        return sentences.first { location >= $0.location && location <= NSMaxRange($0) }
            ?? sentences.last { $0.location <= location }
            ?? sentences.first
    }

    private static func trimmingWhitespace(_ range: NSRange, in ns: NSString) -> NSRange {
        let content = CharacterSet.whitespacesAndNewlines.inverted
        let first = ns.rangeOfCharacter(from: content, options: [], range: range)
        guard first.location != NSNotFound else { return NSRange(location: range.location, length: 0) }
        let last = ns.rangeOfCharacter(from: content, options: .backwards, range: range)
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }
}
