import Foundation
import GrammarModels

enum QuoteConsistency {
    private enum QuoteKind {
        case double
        case apostrophe
    }

    private struct QuoteMark {
        var range: NSRange
        var kind: QuoteKind
        var isCurly: Bool
        var opens: Bool
    }

    static func issues(in ns: NSString, protected: [NSRange]) -> [TextIssue] {
        var marks: [QuoteMark] = []
        for index in 0..<ns.length {
            let unit = ns.character(at: index)
            let range = NSRange(location: index, length: 1)
            guard [0x22, 0x27, 0x201C, 0x201D, 0x2019].contains(unit),
                  !protected.contains(where: { TextUnits.overlaps($0, range) }) else { continue }
            let before = index > 0 && TextUnits.isWordCharacter(ns, at: index - 1)
            let after = TextUnits.isWordCharacter(ns, at: index + 1)
            switch unit {
            case 0x22, 0x201C, 0x201D:
                let opens = index == 0 || isOpeningContext(ns.character(at: index - 1))
                marks.append(QuoteMark(range: range, kind: .double, isCurly: unit != 0x22, opens: opens))
            default:
                guard before, after else { continue }
                marks.append(QuoteMark(range: range, kind: .apostrophe, isCurly: unit == 0x2019, opens: false))
            }
        }

        var issues: [TextIssue] = []
        for kind in [QuoteKind.double, .apostrophe] {
            let group = marks.filter { $0.kind == kind }
            let curly = group.count(where: \.isCurly)
            let straight = group.count - curly
            guard curly > 0, straight > 0, curly != straight else { continue }
            let preferCurly = curly > straight
            for mark in group where mark.isCurly != preferCurly {
                let original = ns.substring(with: mark.range)
                let replacement = switch (kind, preferCurly) {
                case (.double, true): mark.opens ? "\u{201C}" : "\u{201D}"
                case (.double, false): "\""
                case (.apostrophe, true): "\u{2019}"
                case (.apostrophe, false): "'"
                }
                let message = switch (kind, preferCurly) {
                case (.double, true): "The rest of the text uses curly quotation marks."
                case (.double, false): "The rest of the text uses straight quotation marks."
                case (.apostrophe, true): "The rest of the text uses curly apostrophes."
                case (.apostrophe, false): "The rest of the text uses straight apostrophes."
                }
                issues.append(TextIssue(
                    range: mark.range, originalText: original, replacements: [replacement],
                    message: message, category: .punctuation, source: .local
                ))
            }
        }
        return issues
    }

    private static func isOpeningContext(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar) || "([{\u{2014}\u{2013}".unicodeScalars.contains(scalar)
    }
}
