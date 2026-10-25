import GrammarModels
import SwiftUI

struct PanelRewriteRow: View {
    static let quickStyles: [RewriteTone] = [.rephrase, .formal, .friendly, .diplomatic]

    let model: PanelModel
    let rewrite: (RewriteScope, RewriteTone) -> Void
    @ViewState private var scope = RewriteScope.sentence

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Rewrite")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    segment("Sentence", .sentence, help: "Rewrite the sentence with the cursor")
                    segment("All text", .wholeText, help: "Rewrite all the text in the field")
                }
                .padding(2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("What to rewrite")
                Spacer(minLength: 0)
            }
            if model.showsAllRewriteStyles {
                RewriteTonePicker(selected: nil) { rewrite(scope, $0) }
                Button("Fewer styles") { model.toggleRewriteStyles() }
                    .buttonStyle(LinkButtonStyle())
            } else {
                WrappingRow(spacing: 4) {
                    ForEach(Self.quickStyles) { tone in
                        Button(tone.displayName) { rewrite(scope, tone) }
                            .buttonStyle(ToneChipStyle(isSelected: false))
                            .help(tone.detail)
                            .accessibilityHint(tone.detail)
                    }
                    Button("⋯") { model.toggleRewriteStyles() }
                        .buttonStyle(ToneChipStyle(isSelected: false))
                        .help("More styles: improve, shorten, professional, confident…")
                        .accessibilityLabel("More styles")
                }
            }
        }
        .padding(.trailing, PanelHeaderView.textTrailingPadding)
    }

    private func segment(_ title: String, _ value: RewriteScope, help: String) -> some View {
        Button(title) { scope = value }
            .buttonStyle(ScopeSegmentStyle(isSelected: scope == value))
            .help(help)
            .accessibilityAddTraits(scope == value ? .isSelected : [])
    }
}

private struct ScopeSegmentStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}
