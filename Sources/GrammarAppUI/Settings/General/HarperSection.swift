import AppKit
import GrammarModels
import SwiftUI

struct HarperSection: View {
    @Bindable var store: SettingsStore
    let harper: HarperModel

    var body: some View {
        Section {
            Toggle("Check grammar offline with Harper", isOn: $store.settings.harperEnabled)
            status
                .font(.callout)
            HStack {
                Button("Choose harper-ls…") { choose() }
                if !store.settings.harperPath.isEmpty {
                    Button("Find Automatically") { store.settings.harperPath = "" }
                }
                Spacer()
                Button("Check Again") { harper.refresh(customPath: store.settings.harperPath) }
                    .disabled(harper.state == .checking)
            }
        } header: {
            Text("Offline grammar")
        } footer: {
            Text("[Harper](https://writewithharper.com) is an open-source grammar checker that runs on this Mac, without AI or a network. It checks English grammar, punctuation and word choice as you type; macOS still checks spelling. Where AI suggests a fix for the same words, the AI suggestion is shown.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { harper.refresh(customPath: store.settings.harperPath) }
        .onDisappear { harper.cancel() }
        .onChange(of: store.settings.harperPath) { _, path in harper.refresh(customPath: path) }
    }

    @ViewBuilder
    private var status: some View {
        switch harper.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Looking for Harper…").foregroundStyle(.secondary)
            }
        case .checked(.found(let path, let version)):
            VStack(alignment: .leading, spacing: 2) {
                Label("Harper \(version) is ready.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(path)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        case .checked(.notFound):
            VStack(alignment: .leading, spacing: 6) {
                Label("Harper isn't installed. Install it with Homebrew, then click Check Again:", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                HStack {
                    Text(HarperModel.installCommand)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(HarperModel.installCommand, forType: .string)
                    }
                    .buttonStyle(.link)
                }
            }
        case .checked(.unusable(let path, let reason)):
            VStack(alignment: .leading, spacing: 2) {
                Label(reason, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(path)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        panel.message = "Choose the harper-ls program"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.settings.harperPath = url.path
    }
}
