import GrammarModels
import SwiftUI

struct RewriteCardView: View {
    let model: RewriteModel
    let actions: OverlayActions

    var body: some View {
        Group {
            if let state = model.state {
                content(state)
            }
        }
        .frame(width: OverlayMetrics.rewriteWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func content(_ state: RewriteState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(state.scope == .sentence ? "Rephrase sentence" : "Rewrite")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }

            if state.scope == .sentence {
                OriginalTextView(text: state.original)
            }

            RewriteTonePicker(selected: state.tone) { tone in
                if tone != state.tone { actions.requestRewrite(tone) }
            }

            RewriteInstructionField(current: state.instruction, submit: actions.requestInstructionRewrite, cancel: actions.cancelRewrite)

            resultView(state.result)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Cancel") { actions.cancelRewrite() }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Button("Replace") {
                    if case .ready(let text) = state.result { actions.acceptRewrite(text) }
                }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .disabled(!state.result.isReady)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func resultView(_ result: RewriteResult) -> some View {
        switch result {
        case .loading:
            HStack(spacing: 8) {
                Spinner(size: 12)
                Text("Rewriting…")
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
}

extension RewriteResult {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}
