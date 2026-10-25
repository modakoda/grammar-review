import Foundation
import GrammarModels

enum StyleGuideChecker {
    static func issues(in text: String, rules: [StyleRule]) -> [TextIssue] {
        let usable = rules.filter(\.isUsable)
        guard !usable.isEmpty, !text.isEmpty else { return [] }
        let ns = text as NSString
        let everything = NSRange(location: 0, length: ns.length)
        let protected = SpellingFilter.protectedRanges(in: text)
        var issues: [TextIssue] = []
        var taken: [NSRange] = []
        for rule in usable.sorted(by: { $0.term.count > $1.term.count }) {
            guard let pattern = regex(for: rule) else { continue }
            for match in pattern.matches(in: text, range: everything) {
                let range = match.range
                guard !protected.contains(where: { TextUnits.overlaps($0, range) }),
                      !taken.contains(where: { TextUnits.overlaps($0, range) }) else { continue }
                let found = ns.substring(with: range)
                let replacement = replacement(for: rule, found: found)
                if let replacement, replacement == found { continue }
                taken.append(range)
                issues.append(TextIssue(
                    range: range,
                    originalText: found,
                    replacements: replacement.map { [$0] } ?? [],
                    message: message(for: rule),
                    category: .wordChoice,
                    source: .styleGuide
                ))
            }
        }
        return issues.sorted { $0.range.location < $1.range.location }
    }

    static func regex(for rule: StyleRule) -> NSRegularExpression? {
        let words = rule.term.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !words.isEmpty else { return nil }
        let pattern = #"(?<![\p{L}\p{N}_])"# + words.joined(separator: #"\s+"#) + #"(?![\p{L}\p{N}_])"#
        return try? NSRegularExpression(pattern: pattern, options: rule.matchCase ? [] : [.caseInsensitive])
    }

    static func replacement(for rule: StyleRule, found: String) -> String? {
        let replacement = rule.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else { return nil }
        if rule.matchCase || replacement.lowercased() == rule.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return replacement
        }
        return ConsistencyChecker.matchingCase(of: found, replacement)
    }

    static func message(for rule: StyleRule) -> String {
        let note = rule.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { return note }
        let replacement = rule.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        let term = rule.term.trimmingCharacters(in: .whitespacesAndNewlines)
        return replacement.isEmpty
            ? "Your style guide says to avoid “\(term)”."
            : "Your style guide says to write “\(replacement)”."
    }
}
