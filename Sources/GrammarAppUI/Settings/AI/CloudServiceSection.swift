import GrammarModels
import Observation
import SwiftUI

struct CloudServiceSection: View {
    @Bindable var store: SettingsStore
    let model: CloudServiceModel

    private var service: CloudService { model.service }

    var body: some View {
        Section("\(service.name) API key") {
            APIKeyEditor(model: model.keyModel, modelID: store.settings.cloudModel(for: service), keyHint: service.keyHint)
            Link("Get an API key at \(service.consoleURL.host() ?? service.consoleURL.absoluteString)", destination: service.consoleURL)
                .font(.callout)
        }

        Section {
            Picker("Model", selection: modelBinding) {
                ForEach(choices) { choice in
                    Text(choice.name).tag(choice.id)
                }
                Divider()
                Text("Other…").tag(Self.otherTag)
            }
            if isOther {
                LabeledContent("Model ID") {
                    HStack {
                        CommittingTextField(title: "Model ID", text: customModelBinding, prompt: "As the service names it")
                        if service.listsModels, model.hasKey {
                            Menu {
                                if model.liveModels.isEmpty {
                                    Button("Load the list") { model.refreshModels() }
                                } else {
                                    ForEach(model.liveModels, id: \.self) { id in
                                        Button(id) { store.update { $0.cloudModels[service.id] = id } }
                                    }
                                }
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                            .fixedSize()
                            .help("The models your key can use")
                        }
                    }
                }
                listStatus
            }
            if let detail = service.option(for: store.settings.cloudModel(for: service))?.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Test") { model.test(model: store.settings.cloudModel(for: service)) }
                    .disabled(!model.hasKey || model.isTesting)
                APIKeyTestResultView(state: model.testState, testingText: "Checking a test sentence with \(service.assistantName)…")
            }
        } header: {
            Text("Model")
        } footer: {
            Text(service.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!store.settings.aiEnabled)
        .onChange(of: store.settings.cloudModels[service.id]) { _, _ in model.clearTestResult() }
    }

    private static let otherTag = "\u{0}other"

    private var choices: [AIModelOption] {
        let current = store.settings.cloudModel(for: service)
        if service.option(for: current) != nil || isOther { return service.models }
        return service.models + [AIModelOption(id: current, name: current, detail: "A model that isn't in the built-in list.")]
    }

    private var isOther: Bool {
        let saved = store.settings.cloudModels[service.id] ?? ""
        return saved == Self.otherTag || (!saved.isEmpty && service.option(for: saved) == nil && saved != service.defaultModel)
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { isOther ? Self.otherTag : store.settings.cloudModel(for: service) },
            set: { choice in
                store.update { $0.cloudModels[service.id] = choice == Self.otherTag ? Self.otherTag : choice }
            }
        )
    }

    private var customModelBinding: Binding<String> {
        Binding(
            get: {
                let saved = store.settings.cloudModels[service.id] ?? ""
                return saved == Self.otherTag ? "" : saved
            },
            set: { id in
                let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
                store.update { $0.cloudModels[service.id] = trimmed.isEmpty ? Self.otherTag : trimmed }
            }
        )
    }

    @ViewBuilder
    private var listStatus: some View {
        switch model.listState {
        case .idle, .loaded:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading the model list…").foregroundStyle(.secondary)
            }
            .font(.callout)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        }
    }
}
