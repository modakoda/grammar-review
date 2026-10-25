import Foundation
import GrammarModels

struct AIBackends: Sendable {
    var claude: ClaudeClient
    var local: ChatCompletionsClient
    var cloud: ChatCompletionsClient
    let usage = UsageRecorder()

    init(claude: ClaudeClient, local: ChatCompletionsClient, cloud: ChatCompletionsClient? = nil) {
        self.claude = claude
        self.local = local
        self.cloud = cloud ?? ChatCompletionsClient(session: local.session, minimumTimeout: 0)
    }

    func send(_ request: MessageRequest, to endpoint: AIEndpoint) async -> Result<MessageResponse, AIError> {
        let result = switch endpoint {
        case .claude(_, let apiKey):
            await claude.createMessage(request, apiKey: apiKey)
        case .cloud(let service, let model, let apiKey):
            await cloud.createMessage(request, baseURL: service.baseURL, apiKey: apiKey, style: service.style(for: model))
        case .local(let baseURL, _):
            await local.createMessage(request, baseURL: baseURL)
        }
        if case .success(let response) = result, let tokens = response.usage {
            usage.record(UsageEvent(
                provider: endpoint.provider,
                model: endpoint.provider == .claude ? response.model ?? endpoint.model : endpoint.model,
                purpose: request.purpose,
                tokens: tokens
            ))
        }
        return result
    }
}
