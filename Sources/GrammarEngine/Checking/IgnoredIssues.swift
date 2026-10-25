import Foundation
import GrammarModels

public struct IgnoredIssues: Sendable, Equatable {
    public private(set) var fingerprints: Set<String> = []
    public private(set) var hidden: [TextIssue] = []

    public init() {}

    public var list: [TextIssue] {
        var seen = Set<String>()
        return hidden.filter { seen.insert($0.fingerprint).inserted }
    }

    public mutating func filter(_ issues: [TextIssue]) -> [TextIssue] {
        hidden = issues.filter { fingerprints.contains($0.fingerprint) }
        return issues.filter { !fingerprints.contains($0.fingerprint) }
    }

    public mutating func ignore(_ issue: TextIssue, in issues: inout [TextIssue]) {
        fingerprints.insert(issue.fingerprint)
        hidden += issues.filter { $0.fingerprint == issue.fingerprint }
        hidden.sort(by: Self.inTextOrder)
        issues.removeAll { $0.fingerprint == issue.fingerprint }
    }

    public mutating func restore(_ issue: TextIssue, into issues: inout [TextIssue]) {
        fingerprints.remove(issue.fingerprint)
        issues += hidden.filter { $0.fingerprint == issue.fingerprint }
        issues.sort(by: Self.inTextOrder)
        hidden.removeAll { $0.fingerprint == issue.fingerprint }
    }

    public mutating func rebase(from oldText: String, to newText: String) {
        hidden = IssueRebaser.rebase(hidden, from: oldText, to: newText)
    }

    public mutating func removeHidden(where shouldRemove: (TextIssue) -> Bool) {
        hidden.removeAll(where: shouldRemove)
    }

    public mutating func clearHidden() {
        hidden = []
    }

    private static func inTextOrder(_ lhs: TextIssue, _ rhs: TextIssue) -> Bool {
        lhs.range.location < rhs.range.location
    }
}
