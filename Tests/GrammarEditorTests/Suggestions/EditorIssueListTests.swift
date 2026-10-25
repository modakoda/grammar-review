import Foundation
import GrammarModels
import Testing
@testable import GrammarEditor

@MainActor
@Suite struct EditorIssueListTests {
    private func issue(_ location: Int, _ text: String, _ category: IssueCategory = .spelling) -> TextIssue {
        TextIssue(range: NSRange(location: location, length: (text as NSString).length), originalText: text, replacements: ["x"],
                  message: "m", category: category, source: category == .spelling ? .local : .ai)
    }

    private func result(_ text: String, _ issues: [TextIssue]) -> CheckResult {
        CheckResult(text: text, issues: issues, language: "en", aiStatus: .completed)
    }

    private func listing(_ text: String, _ issues: [TextIssue]) -> EditorIssueList {
        let list = EditorIssueList()
        list.update(with: result(text, issues), text: text)
        return list
    }

    @Test func aResultForOlderTextIsMovedOntoTheCurrentText() {
        let list = EditorIssueList()
        list.update(with: result("teh cat", [issue(0, "teh")]), text: "So teh cat")
        #expect(list.issues.map(\.range.location) == [3])
        #expect(list.issues.map(\.originalText) == ["teh"])
    }

    @Test func removingAnIssueChecksTheTextStillSaysIt() {
        let teh = issue(0, "teh")
        let list = listing("teh cat", [teh])
        #expect(list.remove(teh, matching: "the cat") == nil)
        #expect(list.issues.count == 1)

        list.select(teh.id)
        #expect(list.remove(teh, matching: "teh cat")?.id == teh.id)
        #expect(list.issues.isEmpty)
        #expect(list.selectedID == nil)
    }

    @Test func learningAWordDropsEverySpellingOfItShownOrIgnored() {
        let list = listing("Teh teh has teh", [issue(0, "Teh"), issue(4, "teh"), issue(8, "has", .grammar), issue(12, "teh")])
        list.ignore(list.issues[1])
        #expect(list.issues.map(\.originalText) == ["Teh", "has"])
        #expect(list.ignoredIssues.map(\.originalText) == ["teh"])

        list.removeSpelling(of: "TEH")
        #expect(list.issues.map(\.originalText) == ["has"])
        #expect(list.ignoredIssues.isEmpty)
    }

    @Test func clearingKeepsWhatWasIgnored() {
        let text = "teh has"
        let list = listing(text, [issue(0, "teh"), issue(4, "has", .grammar)])
        list.select(list.issues[1].id)
        list.ignore(list.issues[0])
        list.clear()
        #expect(list.issues.isEmpty && list.ignoredIssues.isEmpty && list.selectedID == nil)

        list.update(with: result(text, [issue(0, "teh"), issue(4, "has", .grammar)]), text: text)
        #expect(list.issues.map(\.originalText) == ["has"], "“teh” stays ignored")
        #expect(list.ignoredIssues.map(\.originalText) == ["teh"])
    }
}
