import AppKit
import GrammarModels
import SwiftUI

package struct CategoryLabel: View {
    let category: IssueCategory

    package init(category: IssueCategory) {
        self.category = category
    }

    package var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.severity.color)
                .frame(width: 7, height: 7)
            Text(category.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

package struct ReplacementLabel: View {
    let original: String
    let replacement: String
    var fontSize: CGFloat = 13

    package init(original: String, replacement: String, fontSize: CGFloat = 13) {
        self.original = original
        self.replacement = replacement
        self.fontSize = fontSize
    }

    package var body: some View {
        HStack(spacing: 5) {
            if !original.isEmpty {
                Text(IssueSummary.visibleText(original))
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "arrow.right")
                    .font(.system(size: fontSize - 4, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            if replacement.isEmpty {
                Text("Remove")
                    .italic()
                    .fontWeight(.semibold)
            } else {
                Text(IssueSummary.visibleText(replacement))
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .layoutPriority(1)
            }
        }
        .font(.system(size: fontSize))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(replacement.isEmpty ? "Remove \(original)" : "Replace \(original) with \(replacement)")
    }
}
