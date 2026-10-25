import Foundation
import GrammarModels

struct TextComposer: Sendable {
    let backends: AIBackends
    let endpoints: EndpointResolver

    func compose(_ request: String, context: String?, settings: AppSettings) async throws -> String {
        guard !request.trimmedWhitespace.isEmpty else { throw RewriteError.failed("Describe what to write") }
        let endpoint = try await endpoints.require(settings)
        let limit = min(ComposePrompt.maxContextCharacters, settings.maxAICharacters)
        let message = ComposePrompt.request(
            request: request,
            context: ComposePrompt.context(context, limit: limit),
            model: endpoint.model
        )
        Log.engine.debug("Compose (\(request.utf16.count, privacy: .public) units, context: \(context != nil, privacy: .public))")

        let name = endpoint.provider.assistantName
        switch await backends.send(message, to: endpoint) {
        case .success(let response):
            if response.stopReason == "refusal" { throw RewriteError.failed("\(name) declined to write this") }
            let text = ComposePrompt.clean(response.text)
            if response.stopReason == "max_tokens" { throw RewriteError.failed("The text was cut off — ask for something shorter") }
            guard !text.isEmpty else { throw RewriteError.failed("\(name) returned no text") }
            return text
        case .failure(let error):
            throw error.rewriteError(for: endpoint)
        }
    }
}
