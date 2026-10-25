import GrammarModels
import SwiftUI

struct PlagiarismSettingsTab: View {
    let keyModel: APIKeyEditorModel

    static let dashboardURL = URL(string: "https://api-dashboard.search.brave.com/app/keys")!

    var body: some View {
        Form {
            Section {
                APIKeyEditor(
                    model: keyModel,
                    modelID: "",
                    keyHint: "BSA…",
                    environmentVariable: KeychainStore.webSearchEnvironmentVariable,
                    missingKeyText: "No key saved. The editor can't check for plagiarism without one."
                )
                Link("Get an API key in the Brave Search API dashboard", destination: Self.dashboardURL)
                    .font(.callout)
            } header: {
                Text("Brave Search API key")
            } footer: {
                Text("Subscribe to the Search plan in the dashboard, then create a key. Brave charges per search; each check makes up to 20.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("How it works") {
                Text("In the editor, open the Plagiarism tab and click Check for Plagiarism. Grammar Review picks up to 20 sentences of eight words or more, spread through the text, and searches the web for each one as an exact phrase. Pages whose text contains most of a sentence are listed as sources, the matching sentences are highlighted, and each source has an APA, MLA or Chicago citation to copy.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Privacy") {
                Text("Sentences go to Brave Search only when you click Check, never as you type. Don't check text you wouldn't type into a search engine.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onDisappear { keyModel.cancelTest() }
    }
}
