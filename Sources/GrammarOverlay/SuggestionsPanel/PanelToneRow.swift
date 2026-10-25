import GrammarModels
import SwiftUI

struct PanelToneRow: View {
    let tone: ToneReport?
    let isDetecting: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Sounds")
                .foregroundStyle(.secondary)
            if let tone, !tone.tones.isEmpty {
                Text(IssueSummary.toneDescription(tone))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if tone.tones.contains(where: \.tone.mayLandBadly) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(nsColor: .systemOrange))
                        .accessibilityLabel("May land badly")
                }
            } else if tone == nil {
                Text("…")
                    .foregroundStyle(.tertiary)
            }
            if isDetecting {
                Spinner(size: 9, lineWidth: 1.1)
            }
        }
        .font(.system(size: 11))
        .help(tone?.summary ?? "Detecting how your text sounds")
        .accessibilityElement(children: .combine)
    }
}
