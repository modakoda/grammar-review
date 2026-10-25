import GrammarModels
import SwiftUI

struct ClaudeSection: View {
    @Bindable var store: SettingsStore
    let keyModel: APIKeyEditorModel

    static let consoleURL = URL(string: "https://platform.claude.com/settings/keys")!

    var body: some View {
        Section("Anthropic API key") {
            APIKeyEditor(model: keyModel, modelID: store.settings.aiModel)
            Link("Get an API key in the Claude Console", destination: Self.consoleURL)
                .font(.callout)
        }

        Section("Model") {
            Picker("Model", selection: $store.settings.aiModel) {
                ForEach(modelOptions) { option in
                    Text(option.name).tag(option.id)
                }
            }
            Text(selectedModelDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!store.settings.aiEnabled)
    }

    private var modelOptions: [ModelChoice] {
        ModelChoice.options(including: store.settings.aiModel)
    }

    private var selectedModelDetail: String {
        modelOptions.first { $0.id == store.settings.aiModel }?.detail ?? ""
    }
}
