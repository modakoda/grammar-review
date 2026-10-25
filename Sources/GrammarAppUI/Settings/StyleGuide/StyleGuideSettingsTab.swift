import AppKit
import GrammarModels
import SwiftUI
import UniformTypeIdentifiers

struct StyleGuideSettingsTab: View {
    @Bindable var store: SettingsStore
    @ViewState private var draft = StyleRule(term: "")
    @ViewState private var editing: StyleRule.ID?
    @ViewState private var selection: StyleRule.ID?
    @ViewState private var message: String?
    @ViewState private var messageIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terms your team writes a particular way: brand names, banned words, preferred spellings. They're flagged everywhere, offline, and win over AI suggestions.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            form

            List(selection: $selection) {
                ForEach(store.settings.styleGuide) { rule in
                    RuleRow(rule: rule)
                        .tag(rule.id)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .onDeleteCommand(perform: removeSelected)
            .onChange(of: selection) { _, id in
                guard let rule = store.settings.styleGuide.first(where: { $0.id == id }) else { return }
                draft = rule
                editing = rule.id
            }
            .overlay {
                if store.settings.styleGuide.isEmpty {
                    Text("No rules yet")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button("Remove", action: removeSelected)
                    .disabled(selection == nil)
                Spacer()
                Button("Import…", action: importFile)
                Menu("Export") {
                    Button("JSON…") { exportFile(.json) }
                    Button("CSV (for spreadsheets)…") { exportFile(.csv) }
                }
                .fixedSize()
                .disabled(store.settings.styleGuide.isEmpty)
            }
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(messageIsError ? .red : .secondary)
            }
        }
        .padding(20)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Term, e.g. utilize", text: $draft.term)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField("Write instead (optional)", text: $draft.replacement)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                TextField("Why (optional), shown on the suggestion", text: $draft.note)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Toggle("Match case", isOn: $draft.matchCase)
                    .help("Flag only this exact capitalisation of the term")
                if editing != nil {
                    Button("Cancel", action: resetForm)
                }
                Button(editing == nil ? "Add" : "Update", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isUsable)
            }
        }
    }

    private func save() {
        guard draft.isUsable else { return }
        var rule = draft
        rule.term = rule.term.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.replacement = rule.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.note = rule.note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.update { settings in
            if let id = editing, let index = settings.styleGuide.firstIndex(where: { $0.id == id }) {
                settings.styleGuide[index] = rule
            } else {
                settings.styleGuide = StyleGuideFile.merge([rule], into: settings.styleGuide)
            }
        }
        message = nil
        resetForm()
    }

    private func resetForm() {
        draft = StyleRule(term: "")
        editing = nil
        selection = nil
    }

    private func removeSelected() {
        guard let id = selection else { return }
        store.update { $0.styleGuide.removeAll { $0.id == id } }
        resetForm()
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a style guide (JSON, or CSV with term, replacement and note columns)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let rules = try StyleGuideFile.decode(Data(contentsOf: url))
            store.update { $0.styleGuide = StyleGuideFile.merge(rules, into: $0.styleGuide) }
            show(rules.count == 1 ? "Imported 1 rule." : "Imported \(rules.count) rules.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func exportFile(_ format: StyleGuideFile.Format) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .json ? .json : .commaSeparatedText]
        panel.nameFieldStringValue = "Style Guide.\(format.rawValue)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try StyleGuideFile.encode(store.settings.styleGuide, as: format).write(to: url, options: .atomic)
            show("Exported to \(url.lastPathComponent).", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

private struct RuleRow: View {
    let rule: StyleRule

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(rule.term)
                    .strikethrough(rule.replacement.isEmpty)
                if !rule.replacement.isEmpty {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rule.replacement)
                        .fontWeight(.medium)
                } else {
                    Text("avoid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if rule.matchCase {
                    Text("Aa")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        .help("Matches this capitalisation only")
                }
            }
            if !rule.note.isEmpty {
                Text(rule.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
