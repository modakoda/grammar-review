import Foundation
import GrammarModels

enum EditorStatus: Equatable {
    case idle
    case checking
    case notice(String, offersSettings: Bool)

    init(text: String, isChecking: Bool, aiStatus: AIStatus) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self = .idle
            return
        }
        if isChecking {
            self = .checking
            return
        }
        switch aiStatus {
        case .completed, .pending:
            self = .idle
        case .disabled:
            self = .notice("AI suggestions are off, so only spelling is checked.", offersSettings: true)
        case .missingAPIKey:
            self = .notice("Add an Anthropic API key in Settings to get grammar and style suggestions.", offersSettings: true)
        case .textTooLong:
            self = .notice("This text is too long for AI checks, so only spelling is checked.", offersSettings: false)
        case .failed(let message):
            self = .notice(message, offersSettings: true)
        }
    }
}
