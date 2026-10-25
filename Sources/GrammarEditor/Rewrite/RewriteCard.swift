import GrammarModels
import GrammarOverlay
import SwiftUI

struct RewriteCard: View {
    static let scrollID = "rewrite"

    let session: RewriteSession
    let model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(session.scope == .sentence ? "Rephrase sentence" : "Rewrite", systemImage: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.cancelRewrite()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            RewriteTonePicker(selected: session.goal.tone) { model.changeRewriteTone($0) }
            RewriteInstructionField(
                current: session.goal.instruction,
                focusOnAppear: session.goal == .instruction(""),
                submit: { model.rewrite(withInstruction: $0) },
                cancel: { model.cancelRewrite() }
            )
            .id(session.id)
            switch session.result {
            case nil:
                Text("Describe the change you want, like “make it sound excited” or “turn it into a bulleted list”.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .loading:
                HStack(spacing: 6) {
                    Spinner(size: 11)
                    Text("Rewriting…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            case .ready(let text):
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Replace") { model.applyRewrite() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .disabled(!isReady)
                Button("Cancel") { model.cancelRewrite() }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.14), radius: 6, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1.5)
        }
    }

    private var isReady: Bool {
        if case .ready = session.result { true } else { false }
    }
}
