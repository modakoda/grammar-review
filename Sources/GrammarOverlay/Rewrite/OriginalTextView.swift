import GrammarModels
import SwiftUI

struct OriginalTextView: View {
    let text: String

    var body: some View {
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 2)
            }
            .accessibilityLabel("Original: \(text)")
    }
}
