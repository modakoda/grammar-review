import Foundation
import GrammarModels

struct AIEdit: Sendable, Equatable {
    var original: String
    var replacement: String
    var contextBefore: String
    var explanation: String
    var category: IssueCategory
}

struct LocatedEdit: Sendable, Equatable {
    var range: NSRange
    var originalText: String
    var edit: AIEdit
}

enum EditLocator {
    static let maxOccurrences = 2000

    static func locate(_ edits: [AIEdit], in paragraph: String) -> [LocatedEdit] {
        let ns = paragraph as NSString
        var located: [LocatedEdit] = []
        for edit in edits {
            guard !edit.original.isEmpty, edit.original != edit.replacement else { continue }
            var candidates = occurrences(of: edit.original, in: ns, options: .literal)
            if candidates.isEmpty {
                candidates = occurrences(of: edit.original, in: ns, options: [])
            }
            candidates.removeAll { candidate in located.contains { TextUnits.overlaps($0.range, candidate) } }
            guard let best = bestCandidate(candidates, for: edit, in: ns) else { continue }
            let originalText = ns.substring(with: best)
            guard originalText != edit.replacement else { continue }
            located.append(LocatedEdit(range: best, originalText: originalText, edit: edit))
        }
        return located
    }

    static func issues(from located: [LocatedEdit], paragraphLocation: Int) -> [TextIssue] {
        located.map { item in
            TextIssue(
                range: NSRange(location: item.range.location + paragraphLocation, length: item.range.length),
                originalText: item.originalText,
                replacements: [item.edit.replacement],
                message: item.edit.explanation.isEmpty ? defaultMessage(for: item.edit.category) : item.edit.explanation,
                category: item.edit.category,
                source: .ai
            )
        }
    }

    static func defaultMessage(for category: IssueCategory) -> String {
        switch category {
        case .spelling: "Possible spelling mistake."
        case .grammar: "Possible grammar mistake."
        case .punctuation: "Check the punctuation here."
        case .wordChoice: "Consider a different word."
        case .clarity: "This could be clearer."
        case .style: "Consider rephrasing."
        }
    }

    private static func occurrences(of needle: String, in haystack: NSString, options: NSString.CompareOptions) -> [NSRange] {
        var result: [NSRange] = []
        var start = 0
        while start < haystack.length, result.count < maxOccurrences {
            let found = haystack.range(of: needle, options: options, range: NSRange(location: start, length: haystack.length - start))
            guard found.location != NSNotFound, found.length > 0 else { break }
            if TextUnits.isAligned(found, in: haystack) { result.append(found) }
            start = found.location + haystack.rangeOfComposedCharacterSequence(at: found.location).length
        }
        return result
    }

    private static func bestCandidate(_ candidates: [NSRange], for edit: AIEdit, in ns: NSString) -> NSRange? {
        guard !candidates.isEmpty else { return nil }
        let context = edit.contextBefore as NSString
        var best: NSRange?
        var bestScore = (0, 0, 0)
        for candidate in candidates {
            let preceding = precedingText(before: candidate.location, maxLength: context.length, in: ns)
            let exact = context.length > 0 && preceding == edit.contextBefore ? 1 : 0
            let boundary = isOnWordBoundaries(candidate, in: ns) ? 1 : 0
            let partial = commonSuffixLength(preceding as NSString, context)
            let score = (exact, boundary, partial)
            if best == nil || score > bestScore {
                best = candidate
                bestScore = score
            }
        }
        return best
    }

    private static func precedingText(before location: Int, maxLength: Int, in ns: NSString) -> String {
        guard maxLength > 0, location > 0 else { return "" }
        var start = max(0, location - maxLength)
        if start > 0, TextUnits.isLowSurrogate(ns.character(at: start)) { start += 1 }
        guard start < location else { return "" }
        return ns.substring(with: NSRange(location: start, length: location - start))
    }

    private static func commonSuffixLength(_ a: NSString, _ b: NSString) -> Int {
        var count = 0
        while count < a.length, count < b.length,
              a.character(at: a.length - 1 - count) == b.character(at: b.length - 1 - count) {
            count += 1
        }
        return count
    }

    private static func isOnWordBoundaries(_ range: NSRange, in ns: NSString) -> Bool {
        let end = NSMaxRange(range)
        if TextUnits.isWordCharacter(ns, at: range.location), range.location > 0,
           TextUnits.isWordCharacter(ns, at: range.location - 1) {
            return false
        }
        if end > range.location, TextUnits.isWordCharacter(ns, at: end - 1), TextUnits.isWordCharacter(ns, at: end) {
            return false
        }
        return true
    }
}
