import GrammarModels
import Observation
import SwiftUI

struct LocalServerSection: View {
    @Bindable var store: SettingsStore
    let server: LocalServerModel

    var body: some View {
        Section {
            LabeledContent("Server address") {
                HStack {
                    CommittingTextField(title: "Server address", text: $store.settings.localServerURL, prompt: LocalServerPreset.lmStudio.url)
                    Menu("Presets") {
                        ForEach(LocalServerPreset.all) { preset in
                            Button("\(preset.name): \(preset.url)") {
                                store.settings.localServerURL = preset.url
                            }
                        }
                    }
                    .fixedSize()
                }
            }
            LabeledContent("Model") {
                HStack {
                    if server.models.isEmpty {
                        CommittingTextField(title: "Model", text: $store.settings.localModel, prompt: "Model name, e.g. qwen3-30b-a3b")
                    } else {
                        Picker("Model", selection: $store.settings.localModel) {
                            if store.settings.localModel.isEmpty {
                                Text("Choose a model").tag("")
                            }
                            ForEach(modelChoices, id: \.self) { id in
                                Text(id).tag(id)
                            }
                        }
                        .labelsHidden()
                    }
                    Button {
                        server.refreshModels(address: store.settings.localServerURL)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reload the server's model list")
                    .disabled(server.listState == .loading)
                    Button("Test") {
                        server.test(address: store.settings.localServerURL, model: store.settings.localModel)
                    }
                    .disabled(store.settings.localModel.trimmingCharacters(in: .whitespaces).isEmpty || server.isTesting)
                }
            }
            listStatus
            APIKeyTestResultView(state: server.testState, testingText: "Testing the model (the first test may wait for it to load)…")
        } header: {
            Text("Local server")
        } footer: {
            Text("Uses a model running on your Mac, with no API key. Start the server in LM Studio (Developer tab) or Ollama, then choose a model. Models of about 20–30B parameters balance quality and speed; small models miss more mistakes, especially in languages other than English.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!store.settings.aiEnabled)
        .onAppear { server.refreshModels(address: store.settings.localServerURL) }
        .onChange(of: store.settings.localServerURL) { _, address in
            server.clearTestResult()
            server.refreshModels(address: address)
        }
        .onChange(of: store.settings.localModel) { _, _ in server.clearTestResult() }
    }

    private var modelChoices: [String] {
        let current = store.settings.localModel
        if current.isEmpty || server.models.contains(current) { return server.models }
        return server.models + [current]
    }

    @ViewBuilder
    private var listStatus: some View {
        switch server.listState {
        case .idle:
            EmptyView()
        case .loaded where !server.models.isEmpty:
            EmptyView()
        case .loaded:
            Label("The server has no models. Download one in LM Studio, or run `ollama pull` with a model name.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Looking for models…").foregroundStyle(.secondary)
            }
            .font(.callout)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        }
    }
}
