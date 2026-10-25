import GrammarModels
import SwiftUI

package struct IgnoredList: View {
    let issues: [TextIssue]
    let restore: (TextIssue) -> Void

    package init(issues: [TextIssue], restore: @escaping (TextIssue) -> Void) {
        self.issues = issues
        self.restore = restore
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Ignored")
                Text("\(issues.count)")
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)

            ForEach(issues, id: \.fingerprint) { issue in
                HStack(spacing: 8) {
                    Circle()
                        .fill(issue.category.severity.color)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    label(for: issue)
                    Spacer(minLength: 4)
                    Button("Restore") { restore(issue) }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                        .accessibilityLabel("Restore \(issue.category.displayName.lowercased()) suggestion for \(issue.originalText)")
                }
                .help(issue.message)
            }
        }
    }

    @ViewBuilder
    private func label(for issue: TextIssue) -> some View {
        if let first = issue.replacements.first {
            ReplacementLabel(original: issue.originalText, replacement: first, fontSize: 12)
        } else {
            Text(issue.originalText.isEmpty ? issue.message : IssueSummary.visibleText(issue.originalText))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
