import GrammarEngine
import GrammarModels
import GrammarOverlay
import SwiftUI

struct PlagiarismView: View {
    let model: EditorModel

    var body: some View {
        let session = model.plagiarism
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                PlagiarismSummary(model: model, session: session)
                if case .ready(let report) = session.state {
                    ForEach(report.sources) { source in
                        PlagiarismSourceCard(source: source, isSelected: session.selectedSourceID == source.id, model: model)
                    }
                }
                Text("Nothing is sent until you click Check. Then up to \(PlagiarismChecker.maxSearches) of your sentences go to Brave Search, one search each, with your API key.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(12)
        }
    }
}

private struct PlagiarismSummary: View {
    let model: EditorModel
    let session: PlagiarismSession

    var body: some View {
        InsightCard(title: "Plagiarism", symbol: "doc.on.doc") {
            switch session.state {
            case .idle:
                Text("Compare your sentences with pages on the web. Each sentence is searched as an exact phrase, and the pages that contain it are listed with a citation.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                checkButton("Check for Plagiarism")
            case .checking(let progress):
                HStack(spacing: 6) {
                    Spinner(size: 11)
                    Text(progress.total == 0 ? "Choosing sentences…" : "Searching the web: \(progress.searched) of \(progress.total) sentences")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("Cancel") { model.plagiarism.cancel() }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                }
            case .ready(let report):
                result(report)
            case .failed(let message, let offersSettings):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    checkButton("Try Again")
                    if offersSettings {
                        Button("Settings") { model.openPlagiarismSettings() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func result(_ report: PlagiarismReport) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if report.sources.isEmpty {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(nsColor: .systemGreen))
                Text("No matches found")
                    .font(.system(size: 13, weight: .medium))
            } else {
                Text(PlagiarismSummary.percent(report.matchedShare))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(report.sources.count == 1 ? "of the checked text matches 1 web page" : "of the checked text matches \(report.sources.count) web pages")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        Text(PlagiarismSummary.coverage(report))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        if session.isStale {
            Label("The text changed since this check.", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: .systemOrange))
        }
        checkButton("Check Again")
    }

    private func checkButton(_ title: String) -> some View {
        Button(title) { model.checkPlagiarism() }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    static func coverage(_ report: PlagiarismReport) -> String {
        let checked = report.checkedPassages.count
        let sentences = checked == 1 ? "1 sentence" : "\(checked) sentences"
        guard report.skippedPassages > 0 else { return "Checked \(sentences). Matching sentences are highlighted." }
        return "Checked \(sentences) spread through the text; \(report.skippedPassages) more weren't searched. Matching sentences are highlighted."
    }
}

private struct PlagiarismSourceCard: View {
    let source: PlagiarismSource
    let isSelected: Bool
    let model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Text(source.url.host() == nil || source.siteName == source.url.host() ? source.siteName : "\(source.siteName) · \(source.url.host() ?? "")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(source.passages.count == 1 ? "1 matching sentence" : "\(source.passages.count) matching sentences")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: .systemTeal))
            if !source.snippet.isEmpty {
                Text(source.snippet)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack(spacing: 6) {
                Button("Show in Text") { model.revealPlagiarism(source) }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Menu("Cite") {
                    ForEach(CitationStyle.allCases) { style in
                        Button("Copy \(style.edition) Citation") { PlagiarismSession.copy(source, style: style) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer(minLength: 4)
                Link(destination: source.url) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color(nsColor: .systemTeal) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
    }
}
