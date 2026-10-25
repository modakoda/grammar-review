import GrammarModels
import SwiftUI

struct AISettingsTab: View {
    @Bindable var store: SettingsStore
    let keyModel: APIKeyEditorModel
    let localServer: LocalServerModel
    let cloudServices: CloudServiceModels
    let usage: UsageStore

    var body: some View {
        Form {
            Section {
                Toggle("Use AI for grammar, clarity and style suggestions", isOn: $store.settings.aiEnabled)
                Picker("AI", selection: $store.settings.aiProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .disabled(!store.settings.aiEnabled)
            } footer: {
                Text("With AI off, Grammar Review checks spelling only, entirely on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch store.settings.aiProvider {
            case .claude:
                ClaudeSection(store: store, keyModel: keyModel)
            case .cloud(let id):
                if let service = CloudService.find(id) {
                    CloudServiceSection(store: store, model: cloudServices.model(for: service))
                }
            case .local:
                LocalServerSection(store: store, server: localServer)
            }

            AITimingSection(store: store)

            UsageSection(usage: usage)

            Section("Privacy") {
                Text(PrivacyText.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            keyModel.cancelTest()
            localServer.cancelAll()
            cloudServices.cancelAll()
        }
    }
}
