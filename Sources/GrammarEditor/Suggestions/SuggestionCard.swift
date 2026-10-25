import GrammarModels
import GrammarOverlay
import SwiftUI

struct SuggestionCard: View {
    let issue: TextIssue
    let isExpanded: Bool
    let model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CategoryLabel(category: issue.category)
            if isExpanded {
                expanded
            } else if let first = issue.replacements.first {
                ReplacementLabel(original: issue.originalText, replacement: first, fontSize: 12)
            } else {
                Text(issue.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isExpanded ? 0.14 : 0.05), radius: isExpanded ? 6 : 1.5, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isExpanded ? issue.category.severity.color.opacity(0.55) : Color.primary.opacity(0.08),
                    lineWidth: isExpanded ? 1.5 : 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            if !isExpanded { model.select(issue) }
        }
        .accessibilityAddTraits(isExpanded ? [] : .isButton)
    }

    @ViewBuilder
    private var expanded: some View {
        if !issue.message.isEmpty {
            Text(issue.message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        let replacements = Array(issue.replacements.prefix(3))
        if !replacements.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(replacements.enumerated()), id: \.offset) { index, replacement in
                    Button {
                        model.accept(replacement, for: issue)
                    } label: {
                        ReplacementLabel(original: issue.originalText, replacement: replacement)
                    }
                    .buttonStyle(ReplacementButtonStyle(prominent: index == 0, tint: issue.category.severity.color))
                }
            }
        }
        HStack(spacing: 14) {
            Button("Ignore") { model.ignore(issue) }
            if issue.category == .spelling {
                Button("Add to dictionary") { model.addToDictionary(issue) }
            }
            Spacer(minLength: 0)
            if model.offersRephrase {
                Button {
                    model.rephraseSentence(of: issue)
                } label: {
                    Label("Rephrase sentence", systemImage: "wand.and.stars")
                }
                .help("Say this sentence another way, in the style you pick")
            }
        }
        .buttonStyle(GrammarOverlay.LinkButtonStyle())
    }
}
