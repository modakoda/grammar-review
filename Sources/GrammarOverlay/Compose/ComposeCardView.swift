import GrammarModels
import SwiftUI

struct ComposeCardView: View {
    let model: ComposeModel
    let actions: OverlayActions

    var body: some View {
        Group {
            if let state = model.state {
                ComposeCardContent(state: state, actions: actions)
            }
        }
        .frame(width: OverlayMetrics.rewriteWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ComposeCardContent: View {
    let state: ComposeState
    let actions: OverlayActions
    @ViewState private var request = ""
    @ViewState private var usesContext = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Write with AI")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                TextField("What should I write?", text: $request)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isFocused)
                    .onSubmit(send)
                    .onExitCommand(perform: actions.cancelCompose)
                Button(state.result == nil ? "Write" : "Again", action: send)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }

            if state.hasContext {
                Toggle("Use the field's text as context", isOn: $usesContext)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
            }

            result

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Cancel", action: actions.cancelCompose)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Button(state.replacesSelection ? "Replace" : "Insert") {
                    if case .ready(let text) = state.result { actions.acceptCompose(text) }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .disabled(!(state.result?.isReady ?? false))
            }
        }
        .padding(12)
        .onAppear {
            request = state.request
            isFocused = true
        }
    }

    @ViewBuilder
    private var result: some View {
        switch state.result {
        case nil:
            Text("For example “a polite reply declining the meeting” or “three subject lines”.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .loading:
            HStack(spacing: 8) {
                Spinner(size: 12)
                Text("Writing…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        case .ready(let text):
            ScrollView(.vertical) {
                Text(text)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: OverlayMetrics.rewriteMaxTextHeight)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        case .failed(let message):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .systemOrange))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private var trimmed: String {
        request.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        guard !trimmed.isEmpty else { return }
        actions.requestCompose(trimmed, state.hasContext && usesContext)
    }
}
