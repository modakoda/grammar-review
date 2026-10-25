import SwiftUI

struct CommittingTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    @ViewState private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $draft, prompt: Text(prompt))
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .autocorrectionDisabled()
            .focused($isFocused)
            .onSubmit(commit)
            .onAppear { draft = text }
            .onDisappear(perform: commit)
            .onChange(of: text) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != text { text = trimmed }
        draft = trimmed
    }
}
