import GrammarModels
import GrammarOverlay
import SwiftUI

struct ComposeCard: View {
    static let scrollID = "compose"

    let session: ComposeSession
    let model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Write with AI", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.cancelCompose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            RequestField(session: session, model: model)
            if !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Toggle("Use my text as context", isOn: Binding(
                    get: { session.usesText },
                    set: { model.setComposeUsesText($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .help("Send the editor's text along, so the AI can answer it or continue it")
            }
            switch session.result {
            case nil:
                Text("Ask for anything: “a polite reply declining the meeting”, “an intro paragraph”, “three subject lines”.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .loading:
                HStack(spacing: 6) {
                    Spinner(size: 11)
                    Text("Writing…")
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
                Button(session.range.length > 0 ? "Replace Selection" : "Insert") { model.insertComposed() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                    .disabled(!isReady)
                Button("Cancel") { model.cancelCompose() }
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
