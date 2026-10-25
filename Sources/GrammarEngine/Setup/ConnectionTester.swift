import Foundation
import GrammarModels

struct ConnectionTester: Sendable {
    static let testSentence = "She go to school every days."

    let backends: AIBackends

    func validateClaudeKey(_ key: String, model: String) async throws {
        let key = key.trimmedWhitespace
        guard !key.isEmpty else { throw RewriteError.missingAPIKey }
        switch await backends.claude.countTokens(model: model, apiKey: key) {
        case .success:
            return
        case .failure(.cancelled):
            throw CancellationError()
        case .failure(.invalidAPIKey):
            throw RewriteError.invalidAPIKey
        case .failure(let error):
            throw RewriteError.failed(error.userMessage(for: .claude))
        }
    }

    func validateKey(_ key: String, service: CloudService, model: String) async throws {
        let key = key.trimmedWhitespace
        guard !key.isEmpty else { throw RewriteError.failed("Enter your \(service.name) API key") }
        let result: Result<Void, AIError>
        if service.listsModels {
            result = await backends.cloud.listModels(baseURL: service.baseURL, apiKey: key).map { _ in () }
        } else {
            let request = Self.keyTestRequest(model: model)
            result = await backends.cloud.createMessage(request, baseURL: service.baseURL, apiKey: key, style: service.style(for: model)).map { _ in () }
        }
        switch result {
        case .success: return
        case .failure(.cancelled): throw CancellationError()
        case .failure(let error): throw RewriteError.failed(error.userMessage(forService: service))
        }
    }

    func cloudModels(for service: CloudService, apiKey: String) async throws -> [String] {
        switch await backends.cloud.listModels(baseURL: service.baseURL, apiKey: apiKey.trimmedWhitespace) {
        case .success(let models): return models
        case .failure(.cancelled): throw CancellationError()
        case .failure(let error): throw RewriteError.failed(error.userMessage(forService: service))
        }
    }

    func testCloudModel(_ model: String, service: CloudService, apiKey: String) async throws -> LocalModelTestResult {
        let endpoint = AIEndpoint.cloud(service: service, model: model.trimmedWhitespace, apiKey: apiKey.trimmedWhitespace)
        let request = CheckPrompt.request(paragraph: Self.testSentence, language: "en", model: endpoint.model)
        return try await proofreadTestSentence(request, endpoint: endpoint)
    }

    func localModels(at address: String) async throws -> [String] {
        guard let baseURL = LocalServerAddress.baseURL(from: address) else {
            throw RewriteError.failed(EndpointResolver.invalidAddressMessage)
        }
        switch await backends.local.listModels(baseURL: baseURL) {
        case .success(let models):
            return models
        case .failure(.cancelled):
            throw CancellationError()
        case .failure(let error):
            throw RewriteError.failed(error.userMessage(for: .local))
        }
    }

    func testLocalModel(at address: String, model: String) async throws -> LocalModelTestResult {
        let endpoint: AIEndpoint
        switch EndpointResolver.localEndpoint(address: address, model: model) {
        case .success(let resolved): endpoint = resolved
        case .failure(let problem): throw problem.rewriteError
        }
        var request = CheckPrompt.request(paragraph: Self.testSentence, language: "en", model: endpoint.model)
        request.timeout = ChatCompletionsClient.testTimeout
        return try await proofreadTestSentence(request, endpoint: endpoint)
    }

    static func keyTestRequest(model: String) -> MessageRequest {
        MessageRequest(model: model, maxTokens: 16, system: "Reply with the single word OK.", userText: "OK?", effort: "low", outputSchema: nil, timeout: ClaudeClient.defaultTimeout)
    }

    private func proofreadTestSentence(_ request: MessageRequest, endpoint: AIEndpoint) async throws -> LocalModelTestResult {
        let clock = ContinuousClock()
        let start = clock.now
        switch await backends.send(request, to: endpoint).flatMap(CheckPrompt.parse) {
        case .success(let edits):
            return LocalModelTestResult(duration: clock.now - start, suggestionCount: edits.count)
        case .failure(.cancelled):
            throw CancellationError()
        case .failure(let error):
            throw RewriteError.failed(error.userMessage(for: endpoint))
        }
    }
}
