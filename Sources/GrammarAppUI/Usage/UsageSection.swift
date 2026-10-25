import GrammarModels
import SwiftUI

struct UsageSection: View {
    let usage: UsageStore
    @ViewState private var confirmingReset = false

    var body: some View {
        let period = usage.ledger.current
        Section {
            if period.entries.isEmpty {
                Text("No AI requests yet this month.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Estimated cost") {
                    Text(UsageFormat.dollars(period.estimatedCost) + (period.hasUnpricedUsage ? "+" : ""))
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                LabeledContent("Requests") {
                    Text(period.requestsByPurpose.map { "\($0.requests) \($0.purpose.displayName.lowercased())" }.joined(separator: ", "))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Tokens") {
                    Text("\(UsageFormat.tokens(period.tokens.totalInput)) in, \(UsageFormat.tokens(period.tokens.output)) out")
                        .monospacedDigit()
                }
                ForEach(period.byModel, id: \.model) { row in
                    LabeledContent(row.provider == .local ? "\(row.model) (local)" : row.model) {
                        Text("\(row.requests) · \(UsageFormat.tokens(row.tokens.total)) tokens · \(row.estimatedCost.map(UsageFormat.dollars) ?? "price unknown")")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            if let previous = usage.ledger.previous {
                LabeledContent(UsageFormat.monthName(previous.month)) {
                    Text("\(previous.requests) requests · \(UsageFormat.dollars(previous.estimatedCost))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Usage in \(UsageFormat.monthName(period.month))")
                Spacer()
                if !period.entries.isEmpty || usage.ledger.previous != nil {
                    Button("Reset…") { confirmingReset = true }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        } footer: {
            Text("An estimate at Anthropic's list prices, counted on this Mac. Your bill in the Anthropic Console is what counts. Local models are free.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { usage.refresh() }
        .confirmationDialog("Reset the usage counts?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { usage.reset() }
        } message: {
            Text("This month's and last month's counts are cleared. Your Anthropic bill isn't affected.")
        }
    }
}
