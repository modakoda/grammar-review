import GrammarEngine
import GrammarModels
import GrammarOverlay
import SwiftUI

struct ReadabilitySection: View {
    let model: EditorModel

    var body: some View {
        let statistics = model.statistics
        InsightCard(title: "Readability", symbol: "book") {
            if let score = statistics.readingEase {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(score.rounded()))")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(TextStatistics.readingEaseLabel(score))
                            .font(.system(size: 13, weight: .medium))
                        if let grade = statistics.gradeLevel {
                            Text("Grade level \(Int(grade.rounded()))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(TextStatistics.audience(forReadingEase: score))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(statistics.words < 10
                    ? "Write a little more to get a readability score."
                    : "Readability scores are available for English text.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !statistics.longSentences.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(nsColor: .systemYellow))
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(statistics.longSentences.count == 1
                        ? "1 long sentence"
                        : "\(statistics.longSentences.count) long sentences")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 4)
                    LongSentenceStepper(count: statistics.longSentences.count) { model.revealLongSentence(at: $0) }
                }
                Text("Sentences over \(TextStatistics.longSentenceWords) words are highlighted. Consider splitting them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LongSentenceStepper: View {
    let count: Int
    let reveal: (Int) -> Void
    @ViewState private var next = 0

    var body: some View {
        Button(count > 1 ? "Show next" : "Show") {
            let index = next % max(count, 1)
            reveal(index)
            next = index + 1
        }
        .buttonStyle(PillButtonStyle(kind: .secondary))
    }
}
