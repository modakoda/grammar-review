import GrammarModels
import GrammarOverlay
import SwiftUI

struct RequestField: View {
    let session: ComposeSession
    let model: EditorModel
    @ViewState private var request = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("What should I write?", text: $request, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...4)
                .focused($isFocused)
                .onSubmit { model.compose(request) }
            Button(session.result == nil ? "Write" : "Again") { model.compose(request) }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .disabled(request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .onAppear {
            request = session.request
            isFocused = true
        }
    }
}
