import GrammarModels
import SwiftUI

struct PanelRowsView: View {
    let model: PanelModel
    let actions: OverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.issues.isEmpty {
                emptyState
            } else {
                ForEach(model.issues) { issue in
                    PanelRow(issue: issue, offersRewrite: model.offersRewrite, actions: actions)
                        .overlay(alignment: .bottom) {
                            if issue.id != model.issues.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                }
            }
            if !model.ignored.isEmpty {
                IgnoredList(issues: model.ignored, restore: actions.restore)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Divider() }
            }
        }
        .frame(width: model.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            if model.isChecking {
                Spinner(size: 16, lineWidth: 2)
                Text("Checking…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(nsColor: .systemGreen))
                Text("Looks good!")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

private struct PanelRow: View {
    let issue: TextIssue
    let offersRewrite: Bool
    let actions: OverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CategoryLabel(category: issue.category)
            if let first = issue.replacements.first {
                ReplacementLabel(original: issue.originalText, replacement: first)
            } else if !issue.originalText.isEmpty {
                Text(issue.originalText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !issue.message.isEmpty {
                Text(issue.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                if let first = issue.replacements.first {
                    Button("Accept") { actions.accept(first, issue) }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
                Button("Ignore") { actions.ignore(issue) }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Spacer(minLength: 0)
                if offersRewrite {
                    Button {
                        actions.rephraseSentence(issue)
                    } label: {
                        Label("Rephrase sentence", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(LinkButtonStyle())
                    .help("Say this sentence another way, in the style you pick")
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
