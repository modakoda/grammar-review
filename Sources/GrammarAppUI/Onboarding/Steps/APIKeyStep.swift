import SwiftUI

struct APIKeyStep: View {
    let keyModel: APIKeyEditorModel
    let modelID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(symbol: "key.fill", title: "Add an Anthropic API key (optional)")
            Text("Claude finds grammar, clarity and style problems that a spellchecker can't. Grammar Review uses your own Anthropic API key and keeps it in your Keychain.")
                .fixedSize(horizontal: false, vertical: true)
            APIKeyEditor(model: keyModel, modelID: modelID, showsRemove: false)
            Link("Get an API key in the Claude Console", destination: ClaudeSection.consoleURL)
            Spacer(minLength: 0)
            Text("No key? Skip this step: spelling checks work without one. In Settings → AI you can add a key later, use another AI service (OpenAI, xAI, Google Gemini, Mistral, DeepSeek) with its key, or a local model from LM Studio or Ollama.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
