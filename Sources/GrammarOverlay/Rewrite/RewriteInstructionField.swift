import GrammarModels
import SwiftUI

package struct RewriteInstructionField: View {
    let current: String?
    let focusOnAppear: Bool
    let submit: (String) -> Void
    let cancel: () -> Void
    @ViewState private var instruction = ""
    @FocusState private var isFocused: Bool

    package init(current: String?, focusOnAppear: Bool = false, submit: @escaping (String) -> Void, cancel: @escaping () -> Void) {
        self.current = current
        self.focusOnAppear = focusOnAppear
        self.submit = submit
        self.cancel = cancel
    }

    package var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.bubble")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Describe a change…", text: $instruction)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit(send)
                .onExitCommand(perform: cancel)
            Button("Rewrite", action: send)
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .disabled(trimmed.isEmpty)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(current != nil ? Color.accentColor.opacity(0.6) : Color.clear)
        }
        .onAppear {
            instruction = current ?? ""
            if focusOnAppear { isFocused = true }
        }
    }

    private var trimmed: String {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        guard !trimmed.isEmpty else { return }
        submit(trimmed)
    }
}
