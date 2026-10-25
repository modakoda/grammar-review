import GrammarModels
import SwiftUI

struct SuggestionTypesSection: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Section {
            ForEach(IssueCategory.allCases) { category in
                Toggle(isOn: categoryBinding(category)) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(SeverityColor.color(for: category.severity))
                            .frame(width: 8, height: 8)
                        Text(category.displayName)
                    }
                }
            }
        } header: {
            Text("Suggestion types")
        } footer: {
            Text("Underlines are red for correctness, blue for clarity and purple for style.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func categoryBinding(_ category: IssueCategory) -> Binding<Bool> {
        Binding(
            get: { store.settings.enabledCategories.contains(category) },
            set: { isOn in
                store.update {
                    if isOn {
                        $0.enabledCategories.insert(category)
                    } else {
                        $0.enabledCategories.remove(category)
                    }
                }
            }
        )
    }
}
