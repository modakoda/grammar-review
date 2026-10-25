import GrammarModels
import SwiftUI

package struct RewriteTonePicker: View {
    let selected: RewriteTone?
    let onSelect: (RewriteTone) -> Void

    package init(selected: RewriteTone?, onSelect: @escaping (RewriteTone) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(RewriteTone.Group.allCases) { group in
                WrappingRow(spacing: 4) {
                    ForEach(group.tones) { tone in
                        Button(tone.displayName) { onSelect(tone) }
                            .buttonStyle(ToneChipStyle(isSelected: tone == selected))
                            .help(tone.detail)
                            .accessibilityHint(tone.detail)
                            .accessibilityAddTraits(tone == selected ? .isSelected : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(group.displayName)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToneChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background {
                Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07))
            }
            .contentShape(Capsule())
    }
}
