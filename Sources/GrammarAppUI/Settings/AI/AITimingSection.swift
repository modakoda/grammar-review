import GrammarModels
import SwiftUI

struct AITimingSection: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Section {
            LabeledContent("Wait after typing") {
                HStack {
                    Slider(value: delayBinding, in: 0.5...3, step: 0.25)
                        .frame(minWidth: 160)
                    Text("\(delayBinding.wrappedValue.formatted(.number.precision(.fractionLength(1...2)))) s")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
            LabeledContent("Longest text sent") {
                HStack {
                    Text("\(store.settings.maxAICharacters.formatted()) characters")
                        .monospacedDigit()
                    Stepper("Longest text sent", value: $store.settings.maxAICharacters, in: 1000...20000, step: 1000)
                        .labelsHidden()
                }
            }
        } header: {
            Text("Timing and limits")
        } footer: {
            Text("Longer texts get local spelling checks only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!store.settings.aiEnabled)
    }

    private var delayBinding: Binding<Double> {
        Binding(
            get: { min(max(store.settings.aiDelay, 0.5), 3) },
            set: { store.settings.aiDelay = $0 }
        )
    }
}
