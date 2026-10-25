import GrammarModels
import SwiftUI

struct SuggestionCardView: View {
    let model: CardModel
    let actions: OverlayActions

    var body: some View {
        Group {
            if let issue = model.issue {
                content(issue)
            }
        }
        .frame(width: OverlayMetrics.cardWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func content(_ issue: TextIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CategoryLabel(category: issue.category)

            if !issue.message.isEmpty {
                Text(issue.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let replacements = Array(issue.replacements.prefix(3))
            if !replacements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(replacements.enumerated()), id: \.offset) { index, replacement in
                        Button {
                            actions.accept(replacement, issue)
                        } label: {
                            ReplacementLabel(original: issue.originalText, replacement: replacement)
                        }
                        .buttonStyle(ReplacementButtonStyle(prominent: index == 0, tint: issue.category.severity.color))
                    }
                }
            }

            HStack(spacing: 14) {
                Button("Ignore") { actions.ignore(issue) }
                if issue.category == .spelling {
                    Button("Add to dictionary") { actions.addToDictionary(issue) }
                }
                Spacer(minLength: 0)
                if model.offersRewrite {
                    Button {
                        actions.rephraseSentence(issue)
                    } label: {
                        Label("Rephrase sentence", systemImage: "wand.and.stars")
                    }
                    .help("Say this sentence another way, in the style you pick")
                }
            }
            .buttonStyle(LinkButtonStyle())
        }
        .padding(12)
    }
}
