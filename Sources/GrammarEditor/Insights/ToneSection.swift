import GrammarEngine
import GrammarModels
import GrammarOverlay
import SwiftUI

struct ToneSection: View {
    let model: EditorModel

    var body: some View {
        InsightCard(title: "Tone", symbol: "theatermasks") {
            switch model.tone {
            case .unavailable(let message):
                HStack(spacing: 6) {
                    if model.isDetectingTone { Spinner(size: 11) }
                    Text(model.isDetectingTone ? "Detecting tone…" : message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .failed(let message, let offersSettings):
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if offersSettings {
                        Button("Settings") { model.openSettings() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }
            case .ready(let report):
                if !report.tones.isEmpty {
                    ToneList(report: report)
                }
                HStack(spacing: 6) {
                    Text("Overall: \(report.sentiment.displayName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if model.isDetectingTone { Spinner(size: 10) }
                }
                if !report.summary.isEmpty {
                    Text(report.summary)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ToneList: View {
    let report: ToneReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(report.tones) { score in
                HStack(spacing: 8) {
                    Text(score.tone.emoji)
                        .font(.system(size: 18))
                        .accessibilityHidden(true)
                    Text(score.tone.displayName)
                        .font(.system(size: 13, weight: .medium))
                    if score.tone.mayLandBadly {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(nsColor: .systemOrange))
                            .help("Readers may take this tone badly")
                            .accessibilityLabel("May land badly")
                    }
                    Spacer(minLength: 4)
                    IntensityDots(intensity: score.intensity)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct IntensityDots: View {
    let intensity: ToneIntensity

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ToneIntensity.allCases, id: \.self) { level in
                Circle()
                    .fill(level <= intensity ? Color.accentColor : Color.primary.opacity(0.12))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(intensity.rawValue.capitalized)
    }
}
