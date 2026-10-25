import Foundation
import GrammarModels

enum APIKeyMessages {
    static func message(for error: any Error) -> String {
        switch error as? RewriteError {
        case .missingAPIKey:
            return "Enter an API key first."
        case .invalidAPIKey:
            return "Anthropic rejected this key. Check that you copied all of it."
        case .textTooLong:
            return "The test request was too long."
        case let .failed(reason):
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "The test failed." : trimmed
        case nil:
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    static func success(model: String) -> String {
        let name = AIModelOption.all.first { $0.id == model }?.name ?? model
        return "The key works with \(name)."
    }

    static func sourceDescription(_ source: APIKeySource) -> String {
        switch source {
        case .keychain: "A key is saved in your Keychain."
        case .environment: "Using the ANTHROPIC_API_KEY environment variable."
        case .none: "No key saved. Only local spelling checks run."
        }
    }
}
