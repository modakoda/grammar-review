import GrammarEngine
import GrammarModels
import GrammarOverlay
import SwiftUI

struct CountsSection: View {
    let statistics: TextStatistics

    var body: some View {
        InsightCard(title: "Counts", symbol: "number") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                row("Words", "\(statistics.words)")
                row("Characters", "\(statistics.characters)")
                row("Without spaces", "\(statistics.charactersWithoutSpaces)")
                row("Sentences", "\(statistics.sentences)")
                row("Paragraphs", "\(statistics.paragraphs)")
                Divider().gridCellColumns(2)
                row("Reading time", TextStatistics.formatDuration(minutes: statistics.readingMinutes))
                row("Speaking time", TextStatistics.formatDuration(minutes: statistics.speakingMinutes))
                Divider().gridCellColumns(2)
                row("Average sentence", statistics.sentences == 0 ? "–" : String(format: "%.1f words", statistics.averageSentenceLength))
                row("Average word", statistics.words == 0 ? "–" : String(format: "%.1f characters", statistics.averageWordLength))
                row("Vocabulary variety", statistics.words == 0 ? "–" : "\(Int((statistics.vocabularyVariety * 100).rounded()))%")
            }
            .font(.system(size: 12))
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
        }
    }
}
