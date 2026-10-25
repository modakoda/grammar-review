import Foundation
import GrammarModels
import os
import Security

nonisolated public enum KeychainStore {
    public static let service = "com.grammarreview.app"
    public static let account = "anthropic-api-key"
    public static let environmentVariable = "ANTHROPIC_API_KEY"
    public static let webSearchAccount = "brave-search-api-key"
    public static let webSearchEnvironmentVariable = "BRAVE_SEARCH_API_KEY"

    public static func account(for provider: AIProvider) -> String {
        switch provider {
        case .claude: account
        case .cloud(let id): "\(id)-api-key"
        case .local: "local-api-key"
        }
    }

    public static func apiKey() -> String? {
        APIKeyStore.shared.apiKey()
    }

    public static func apiKey(for provider: AIProvider) -> String? {
        APIKeyStore.store(for: provider).apiKey()
    }

    public static func webSearchAPIKey() -> String? {
        APIKeyStore.webSearch.apiKey()
    }

    public static func setAPIKey(_ key: String?) throws {
        try APIKeyStore.shared.setAPIKey(key)
    }

    public static func apiKeySource() -> APIKeySource {
        APIKeyStore.shared.source()
    }

    public static func invalidateCache() {
        APIKeyStore.invalidateAllCaches()
    }
}

nonisolated public enum APIKeySource: Sendable, Equatable {
    case keychain
    case environment
    case none
}

nonisolated public struct KeychainError: LocalizedError, Sendable, Equatable {
    public var status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }

    public var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return "Keychain: \(detail)"
    }
}
