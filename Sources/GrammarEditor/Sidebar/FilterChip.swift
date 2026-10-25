import GrammarModels
import GrammarOverlay
import SwiftUI

struct FilterChip: View {
    let title: String
    let count: Int
    let color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color {
                    Circle().fill(color).frame(width: 6, height: 6)
                }
                Text(title)
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            }
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.12))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
