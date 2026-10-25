import Foundation
import GrammarModels

enum AISetupProblem: Error, Equatable {
    case missingAPIKey
    case notConfigured(String)

    var status: AIStatus {
        switch self {
        case .missingAPIKey: .missingAPIKey
        case .notConfigured(let message): .failed(message)
        }
    }

    var rewriteError: RewriteError {
        switch self {
        case .missingAPIKey: .missingAPIKey
        case .notConfigured(let message): .failed(message)
        }
    }
}

struct EndpointResolver: Sendable {
    static let invalidAddressMessage = "Enter the local server's address, like http://localhost:1234/v1, in Settings → AI"

    let apiKeys: @Sendable (AIProvider) -> String?

    func resolve(_ settings: AppSettings) async -> Result<AIEndpoint, AISetupProblem> {
        switch settings.aiProvider {
        case .claude:
            guard let apiKey = await fetchAPIKey(for: .claude) else { return .failure(.missingAPIKey) }
            return .success(.claude(model: settings.aiModel, apiKey: apiKey))
        case .cloud(let id):
            guard let service = CloudService.find(id) else {
                return .failure(.notConfigured("Choose an AI service in Settings → AI"))
            }
            guard let apiKey = await fetchAPIKey(for: .cloud(id)) else {
                return .failure(.notConfigured("Add your \(service.name) API key in Settings → AI"))
            }
            return .success(.cloud(service: service, model: settings.cloudModel(for: service), apiKey: apiKey))
        case .local:
            return Self.localEndpoint(address: settings.localServerURL, model: settings.localModel)
        }
    }

    func require(_ settings: AppSettings) async throws -> AIEndpoint {
        guard settings.aiEnabled else { throw RewriteError.failed("AI is turned off in Settings") }
        let endpoint: AIEndpoint
        switch await resolve(settings) {
        case .success(let resolved): endpoint = resolved
        case .failure(let problem): throw problem.rewriteError
        }
        try Task.checkCancellation()
        return endpoint
    }

    static func localEndpoint(address: String, model: String) -> Result<AIEndpoint, AISetupProblem> {
        guard let baseURL = LocalServerAddress.baseURL(from: address) else {
            return .failure(.notConfigured(invalidAddressMessage))
        }
        let model = model.trimmedWhitespace
        guard !model.isEmpty else { return .failure(.notConfigured("Choose a local model in Settings → AI")) }
        return .success(.local(baseURL: baseURL, model: model))
    }

    private func fetchAPIKey(for provider: AIProvider) async -> String? {
        let apiKeys = apiKeys
        let key = await Task.detached(priority: .userInitiated) { apiKeys(provider) }.value
        guard let key = key?.trimmedWhitespace, !key.isEmpty else { return nil }
        return key
    }
}
