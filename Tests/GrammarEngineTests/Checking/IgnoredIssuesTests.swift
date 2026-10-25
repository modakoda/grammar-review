import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct IgnoredIssuesTests {
    let text = "teh has teh cat"
    var issues: [TextIssue] {
        [
            issue(0, "teh", replacements: ["the"]),
            issue(4, "has", .grammar, source: .ai, replacements: ["have"]),
            issue(8, "teh", replacements: ["the"]),
        ]
    }

    @Test func ignoringHidesEveryOccurrenceAndListsItOnce() {
        var ignored = IgnoredIssues()
        var shown = issues
        ignored.ignore(shown[0], in: &shown)

        #expect(shown.map(\.originalText) == ["has"])
        #expect(ignored.hidden.map(\.range.location) == [0, 8])
        #expect(ignored.list.map(\.originalText) == ["teh"])
    }

    @Test func laterResultsStayFiltered() {
        var ignored = IgnoredIssues()
        var shown = issues
        ignored.ignore(shown[1], in: &shown)

        shown = ignored.filter(issues)
        #expect(shown.map(\.originalText) == ["teh", "teh"])
        #expect(ignored.list.map(\.originalText) == ["has"])

        #expect(ignored.filter([issues[0]]).count == 1)
        #expect(ignored.list.isEmpty)
        #expect(ignored.filter(issues).count == 2)
    }

    @Test func restoringPutsEveryOccurrenceBackInTextOrder() {
        var ignored = IgnoredIssues()
        var shown = issues
        ignored.ignore(shown[0], in: &shown)

        ignored.restore(ignored.list[0], into: &shown)
        #expect(shown.map(\.range.location) == [0, 4, 8])
        #expect(ignored.hidden.isEmpty)
        #expect(ignored.fingerprints.isEmpty)
        #expect(ignored.filter(issues).count == 3)
    }

    @Test func hiddenIssuesFollowEdits() {
        var ignored = IgnoredIssues()
        var shown = issues
        ignored.ignore(shown[1], in: &shown)

        ignored.rebase(from: text, to: "So teh has teh cat")
        #expect(ignored.hidden.map(\.range.location) == [7])

        ignored.rebase(from: "So teh has teh cat", to: "So teh have teh cat")
        #expect(ignored.list.isEmpty)
        #expect(ignored.fingerprints.count == 1)
    }

    @Test func clearingHiddenKeepsTheIgnores() {
        var ignored = IgnoredIssues()
        var shown = issues
        ignored.ignore(shown[0], in: &shown)

        ignored.clearHidden()
        #expect(ignored.list.isEmpty)
        #expect(ignored.filter(issues).map(\.originalText) == ["has"])
    }
}
