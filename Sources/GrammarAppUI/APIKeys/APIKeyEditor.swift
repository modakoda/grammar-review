import SwiftUI

struct APIKeyEditor: View {
    @Bindable var model: APIKeyEditorModel
    var modelID: String
    var keyHint = "sk-ant-…"
    var showsRemove = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("API key", text: $model.draft, prompt: Text(model.source == .none ? keyHint : "Enter a new key to replace the saved one"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit { model.save() }
                Button("Save") { model.save() }
                    .disabled(!model.canSave)
                Button("Test") { model.test(model: modelID) }
                    .disabled(!model.canTest || model.isTesting)
            }
            HStack(spacing: 6) {
                Text(APIKeyMessages.sourceDescription(model.source))
                    .foregroundStyle(.secondary)
                if showsRemove, model.source == .keychain {
                    Button("Remove Key", role: .destructive) { model.remove() }
                        .buttonStyle(.link)
                }
            }
            .font(.callout)
            if let error = model.saveError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            APIKeyTestResultView(state: model.testState)
        }
    }
}

struct APIKeyTestResultView: View {
    var state: APIKeyTestState
    var testingText = "Testing the key…"

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(testingText).foregroundStyle(.secondary)
            }
            .font(.callout)
        case let .succeeded(message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case let .failed(message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }
}
