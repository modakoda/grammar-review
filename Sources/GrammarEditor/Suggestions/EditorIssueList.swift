import Foundation
import GrammarEngine
import GrammarModels
import Observation

@Observable
final class EditorIssueList {
    private(set) var issues: [TextIssue] = []
    private(set) var selectedID: UUID?
    private var ignored = IgnoredIssues()

    var ignoredIssues: [TextIssue] { ignored.list }

    var selected: TextIssue? {
        selectedID.flatMap { id in issues.first { $0.id == id } }
    }

    func current(_ issue: TextIssue) -> TextIssue? {
        issues.first { $0.id == issue.id }
    }

    func select(_ id: UUID?) {
        selectedID = id
    }

    func rebase(from oldText: String, to newText: String) {
        issues = IssueRebaser.rebase(issues, from: oldText, to: newText)
        if !ignored.hidden.isEmpty { ignored.rebase(from: oldText, to: newText) }
        dropStaleSelection()
    }

    func update(with result: CheckResult, text: String) {
        var fresh = ignored.filter(
            result.text == text ? result.issues : IssueRebaser.rebase(result.issues, from: result.text, to: text)
        )
        for index in fresh.indices {
            if let previous = issues.first(where: { $0.range == fresh[index].range && $0.fingerprint == fresh[index].fingerprint }) {
                fresh[index].id = previous.id
            }
        }
        issues = fresh
        dropStaleSelection()
    }

    func clear() {
        issues = []
        ignored.clearHidden()
        selectedID = nil
    }

    func remove(_ issue: TextIssue, matching text: String) -> TextIssue? {
        let ns = text as NSString
        guard let current = current(issue),
              NSMaxRange(current.range) <= ns.length,
              ns.substring(with: current.range) == current.originalText
        else { return nil }
        issues.removeAll { $0.id == current.id }
        if selectedID == current.id { selectedID = nil }
        return current
    }

    func ignore(_ issue: TextIssue) {
        ignored.ignore(issue, in: &issues)
        dropStaleSelection()
    }

    func restore(_ issue: TextIssue) {
        ignored.restore(issue, into: &issues)
    }

    func removeSpelling(of word: String) {
        let isWord = { (other: TextIssue) in
            other.category == .spelling && other.originalText.caseInsensitiveCompare(word) == .orderedSame
        }
        issues.removeAll(where: isWord)
        ignored.removeHidden(where: isWord)
        dropStaleSelection()
    }

    private func dropStaleSelection() {
        if let id = selectedID, !issues.contains(where: { $0.id == id }) { selectedID = nil }
    }
}
