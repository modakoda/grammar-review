import Foundation
import GrammarModels

public enum IssueRebaser {
    public static func rebase(_ issues: [TextIssue], from oldText: String, to newText: String) -> [TextIssue] {
        guard !issues.isEmpty else { return [] }
        let newNS = newText as NSString
        guard oldText != newText else {
            return issues.filter { isValid($0, in: newNS) }
        }
        let oldNS = oldText as NSString
        let diff = TextDiff(old: Array(oldText.utf16), new: Array(newText.utf16))
        return issues.compactMap { issue in
            guard let range = rebasedRange(issue.range, diff: diff, old: oldNS, new: newNS) else { return nil }
            var moved = issue
            moved.range = range
            return isValid(moved, in: newNS) ? moved : nil
        }
    }

    struct TextDiff: Equatable {
        var prefix: Int
        var oldEnd: Int
        var newEnd: Int
        var delta: Int { newEnd - oldEnd }

        init(prefix: Int, oldEnd: Int, newEnd: Int) {
            self.prefix = prefix
            self.oldEnd = oldEnd
            self.newEnd = newEnd
        }

        init(old: [UInt16], new: [UInt16]) {
            let shorter = min(old.count, new.count)
            var prefix = 0
            while prefix < shorter, old[prefix] == new[prefix] { prefix += 1 }
            if prefix > 0, TextUnits.isHighSurrogate(old[prefix - 1]) { prefix -= 1 }
            var suffix = 0
            while suffix < shorter - prefix, old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
            if suffix > 0, TextUnits.isLowSurrogate(old[old.count - suffix]) { suffix -= 1 }
            self.init(prefix: prefix, oldEnd: old.count - suffix, newEnd: new.count - suffix)
        }
    }

    static func rebasedRange(_ range: NSRange, diff: TextDiff, old: NSString, new: NSString) -> NSRange? {
        let start = range.location
        let end = NSMaxRange(range)
        guard range.location != NSNotFound, range.length > 0, end <= old.length else { return nil }

        if end < diff.prefix { return range }
        if start > diff.oldEnd { return NSRange(location: start + diff.delta, length: range.length) }
        if start < diff.oldEnd, end > diff.prefix { return nil }

        if end == diff.prefix {
            let extendsWord = TextUnits.isWordCharacter(old, at: end - 1) && TextUnits.isWordCharacter(new, at: diff.prefix)
            return extendsWord ? nil : range
        }
        let newStart = start + diff.delta
        let extendsWord = TextUnits.isWordCharacter(old, at: start) && TextUnits.isWordCharacter(new, at: newStart - 1)
        return extendsWord ? nil : NSRange(location: newStart, length: range.length)
    }

    static func isValid(_ issue: TextIssue, in text: NSString) -> Bool {
        guard TextUnits.isAligned(issue.range, in: text), issue.range.length > 0 else { return false }
        return text.substring(with: issue.range) == issue.originalText
    }
}
