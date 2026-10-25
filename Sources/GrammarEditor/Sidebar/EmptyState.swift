import GrammarModels
import GrammarOverlay
import SwiftUI

struct EmptyState: View {
    let model: EditorModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(symbol == "checkmark.seal" ? Color(nsColor: .systemGreen) : .secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var isEmptyText: Bool {
        model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var symbol: String {
        if isEmptyText { return "square.and.pencil" }
        if model.status == .checking { return "ellipsis" }
        return "checkmark.seal"
    }

    private var title: String {
        if isEmptyText { return "Start writing" }
        if model.status == .checking { return "Checking…" }
        if let filter = model.filter, model.count(of: nil) > 0 { return "No \(filter.title.lowercased()) suggestions" }
        return "No suggestions"
    }

    private var detail: String? {
        if isEmptyText { return "Type or paste text on the left. Suggestions appear here." }
        if model.status == .checking { return nil }
        if model.filter != nil, model.count(of: nil) > 0 { return "Choose All to see the others." }
        return "Your text looks good."
    }
}
