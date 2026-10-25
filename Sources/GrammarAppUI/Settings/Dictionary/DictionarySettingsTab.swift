import GrammarModels
import SwiftUI

struct DictionarySettingsTab: View {
    @Bindable var store: SettingsStore
    @ViewState private var newWord = ""
    @ViewState private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Words in your dictionary are never flagged as misspelled. Add names, product names and jargon.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("Add a word", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(trimmedNewWord.isEmpty)
            }

            List(selection: $selection) {
                ForEach(words, id: \.self) { word in
                    Text(word)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .onDeleteCommand(perform: removeSelected)
            .overlay {
                if words.isEmpty {
                    Text("No words yet")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Remove", action: removeSelected)
                    .disabled(selection.isEmpty)
                Spacer()
                Text(words.count == 1 ? "1 word" : "\(words.count) words")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(20)
    }

    private var trimmedNewWord: String {
        newWord.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var words: [String] {
        store.settings.personalDictionary.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func add() {
        guard !trimmedNewWord.isEmpty else { return }
        store.addToDictionary(trimmedNewWord)
        newWord = ""
    }

    private func removeSelected() {
        let removed = selection
        store.update { $0.personalDictionary.subtract(removed) }
        selection = []
    }
}
