import Foundation
import GrammarModels

nonisolated extension IssueSeverity {
    package var priority: Int {
        switch self {
        case .correctness: 3
        case .clarity: 2
        case .style: 1
        }
    }
}

package nonisolated enum IssueSummary {
    package static func fixAllCount(_ issues: [TextIssue]) -> Int {
        issues.count { $0.category.severity == .correctness && !$0.replacements.isEmpty }
    }

    static func mostSevere(_ issues: [TextIssue]) -> IssueSeverity? {
        issues.map(\.category.severity).max { $0.priority < $1.priority }
    }

    static func countLabel(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    package static func toneDescription(_ report: ToneReport) -> String {
        report.tones.map { "\($0.tone.emoji) \($0.tone.displayName)" }.joined(separator: " · ")
    }

    package static func title(forCount count: Int) -> String {
        switch count {
        case 0: "No suggestions"
        case 1: "1 suggestion"
        default: "\(count) suggestions"
        }
    }

    static func disableTitle(appName: String?) -> String {
        let name = appName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Disable in this app" : "Disable in \(name)"
    }

    package static func visibleText(_ text: String) -> String {
        guard !text.isEmpty, text.allSatisfy(\.isWhitespace) else { return text }
        return String(text.map { character -> Character in
            switch character {
            case "\n", "\r\n", "\r": "↵"
            case "\t": "⇥"
            default: "␣"
            }
        })
    }
}
