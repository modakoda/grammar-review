import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct IssueRebaserTests {
    let base = "I has teh cat"
    var issues: [TextIssue] { [issue(2, "has", .grammar, source: .ai), issue(6, "teh")] }

    private func rebase(_ newText: String, _ issues: [TextIssue]? = nil, from oldText: String? = nil) -> [TextIssue] {
        let result = IssueRebaser.rebase(issues ?? self.issues, from: oldText ?? base, to: newText)
        for issue in result {
            #expect(substring(newText, issue.range) == issue.originalText, "invariant newText[range] == originalText")
        }
        return result
    }

    @Test func insertBeforeShiftsIssues() {
        let result = rebase("Well, I has teh cat")
        #expect(result.map(\.range.location) == [8, 12])
    }

    @Test func insertAfterKeepsIssues() {
        let result = rebase("I has teh cat today.")
        #expect(result.map(\.range.location) == [2, 6])
    }

    @Test func insertInsideAnIssueDropsIt() {
        let result = rebase("I has tXeh cat")
        #expect(result.map(\.originalText) == ["has"])
    }

    @Test func insertBetweenIssuesShiftsOnlyLaterOnes() {
        let result = rebase("I has big teh cat")
        #expect(result.map(\.range.location) == [2, 10])
    }

    @Test func deletionBeforeShiftsLeft() {
        let result = rebase("has teh cat", from: "I has teh cat")
        #expect(result.map(\.range.location) == [0, 4])
    }

    @Test func deletingPartOfAnIssueDropsIt() {
        let result = rebase("I has th cat")
        #expect(result.map(\.originalText) == ["has"])
    }

    @Test func deletingTheSpaceBetweenWordsDropsBoth() {
        let result = rebase("I hasteh cat")
        #expect(result.isEmpty)
    }

    @Test func extendingTheWordDropsTheIssue() {
        #expect(rebase("tehe", [issue(0, "teh")], from: "teh").isEmpty)
        #expect(rebase("I has tehe cat").map(\.originalText) == ["has"])
    }

    @Test func prependingToTheWordDropsTheIssue() {
        #expect(rebase("xteh", [issue(0, "teh")], from: "teh").isEmpty)
    }

    @Test func typingASpaceAfterTheWordKeepsTheIssue() {
        #expect(rebase("teh ", [issue(0, "teh")], from: "teh").map(\.range.location) == [0])
        #expect(rebase("teh, and", [issue(0, "teh")], from: "teh").map(\.range.location) == [0])
    }

    @Test func typingASpaceBeforeTheWordShiftsTheIssue() {
        #expect(rebase(" teh", [issue(0, "teh")], from: "teh").map(\.range.location) == [1])
    }

    @Test func emojiInsertionShiftsByUTF16Length() {
        let result = rebase("😀 I has teh cat")
        #expect(result.map(\.range.location) == [5, 9])
    }

    @Test func replacingAnAdjacentEmojiDoesNotSplitSurrogates() {
        let old = "😀teh"
        let result = IssueRebaser.rebase([issue(0, "😀", .style), issue(2, "teh")], from: old, to: "😁teh")
        #expect(result.map(\.originalText) == ["teh"])
        #expect(result.first?.range == NSRange(location: 2, length: 3))
    }

    @Test func addingACombiningAccentExtendsTheWord() {
        #expect(rebase("cafe\u{301} ok", [issue(0, "cafe")], from: "cafe ok").isEmpty)
    }

    @Test func multipleIssuesAcrossSeveralEdits() {
        let old = "I has teh cat and teh dog"
        let issues = [issue(2, "has", .grammar, source: .ai), issue(6, "teh"), issue(18, "teh")]
        let result = rebase("I have teh cat and teh dog", issues, from: old)
        #expect(result.map(\.range.location) == [7, 19])
    }

    @Test func unchangedTextKeepsValidIssuesAndDropsStaleOnes() {
        let stale = issue(0, "nope")
        let result = rebase(base, issues + [stale], from: base)
        #expect(result.map(\.originalText) == ["has", "teh"])
    }

    @Test func replacingEverythingDropsEverything() {
        #expect(rebase("Something else entirely").isEmpty)
    }

    @Test func diffFindsTheSingleEditedRegion() {
        let diff = IssueRebaser.TextDiff(old: Array("abcdef".utf16), new: Array("abXYef".utf16))
        #expect(diff == IssueRebaser.TextDiff(prefix: 2, oldEnd: 4, newEnd: 4))
        let insertion = IssueRebaser.TextDiff(old: Array("aa".utf16), new: Array("aaa".utf16))
        #expect(insertion == IssueRebaser.TextDiff(prefix: 2, oldEnd: 2, newEnd: 3))
        #expect(insertion.delta == 1)
    }
}
