import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct GeminiTests {
    private func gemini(_ server: MockServer) -> CloudService {
        let real = CloudService.gemini
        return CloudService(
            id: real.id, name: real.name, assistantName: real.assistantName,
            baseURL: server.baseURL.appending(path: "v1beta/openai"), consoleURL: real.consoleURL,
            keyHint: real.keyHint, environmentVariable: real.environmentVariable,
            models: real.models, defaultModel: real.defaultModel, style: real.style,
            listsModels: real.listsModels, notes: real.notes
        )
    }

    private func backends(_ server: MockServer) -> AIBackends {
        AIBackends(claude: server.client(), local: server.localClient())
    }

    @Test func descriptorMatchesTheVerifiedCatalogue() throws {
        let service = CloudService.gemini
        #expect(service.id == "gemini")
        #expect(service.baseURL.absoluteString == "https://generativelanguage.googleapis.com/v1beta/openai")
        #expect(service.environmentVariable == "GEMINI_API_KEY")
        #expect(service.models.map(\.id) == ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-3.8-flash", "gemini-4-argon"])
        #expect(service.defaultModel == "gemini-3.5-flash-lite")
        #expect(!service.models.contains { $0.id.contains("2.5") || $0.id.contains("preview") }, "no retired or preview models")
        let lite = try #require(service.pricing(for: "gemini-3.5-flash-lite"))
        #expect(lite.input == 0.30 && lite.output == 2.50 && lite.cacheRead == 0.03)
        let flash = try #require(service.pricing(for: "gemini-3.8-flash"))
        #expect(flash.input == 0.75 && flash.output == 3.75 && flash.cacheRead == 0.075)
        let argon = try #require(service.pricing(for: "gemini-4-argon"))
        #expect(argon.input == 2.00 && argon.output == 10.00 && argon.cacheRead == 0.10)
        #expect(service.style.reasoningEffort == "low" && service.style.outputLimit == .maxTokens)
        #expect(AIProvider.cloud("gemini").displayName == "Google Gemini (API key)")
        #expect(service.assistantName == "Gemini")
    }

    @Test func checksGoToTheCompatibleEndpoint() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
        let service = gemini(server)
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "AIzaTest")
        _ = try await backends(server).send(CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: "gemini-3.5-flash-lite"), to: endpoint).get()

        let request = try #require(server.requests.first)
        #expect(request.path == "/v1beta/openai/chat/completions")
        #expect(request.header("authorization") == "Bearer AIzaTest")
        #expect(request.header("x-goog-api-key") == nil)
        let json = request.json
        #expect(json["model"] as? String == "gemini-3.5-flash-lite")
        #expect(json["max_tokens"] != nil && json["max_completion_tokens"] == nil)
        #expect(json["reasoning_effort"] as? String == "low", "the lowest thinking level; Gemini 3 can't stop thinking")
        #expect(json["temperature"] == nil)
        #expect((json["messages"] as? [[String: Any]])?.first?["role"] as? String == "system")
        #expect(((json["response_format"] as? [String: Any])?["json_schema"] as? [String: Any])?["strict"] as? Bool == true)
        #expect(endpoint.cacheID == "gemini#gemini-3.5-flash-lite")
    }

    @Test func modelIDsLoseTheirResourcePrefix() async throws {
        let list = #"{"object":"list","data":[{"id":"models/gemini-3.8-flash","object":"model","owned_by":"google"},"# +
            #"{"id":"gemini-3.5-flash-lite","object":"model","owned_by":"google"},{"id":"models/gemini-embedding-001","object":"model","owned_by":"google"}]}"#
        let server = MockServer { _, _ in .json(200, list) }
        let engine = HybridGrammarEngine(apiKeyProvider: { _ in "AIzaTest" }, backends: backends(server))
        #expect(try await engine.cloudModels(for: gemini(server), apiKey: "AIzaTest") == ["gemini-3.5-flash-lite", "gemini-3.8-flash"])
        #expect(server.requests.first?.path == "/v1beta/openai/models")
    }

    @Test func aRejectedKeyIsReportedAsSuch() async {
        let body = #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#
        let server = MockServer { _, _ in .json(400, body) }
        let engine = HybridGrammarEngine(apiKeyProvider: { _ in "AIzaBad" }, backends: backends(server))
        await #expect(throws: RewriteError.failed("Invalid Google Gemini API key")) {
            try await engine.validateAPIKey("AIzaBad", service: gemini(server), model: "gemini-3.5-flash-lite")
        }
        let noKey = #"{"error":{"code":403,"message":"Method doesn't allow unregistered callers (callers without established identity). "# +
            #"Please use API Key or other form of API consumer identity to call this API.","status":"PERMISSION_DENIED"}}"#
        let forbidden = MockServer { _, _ in .json(403, noKey) }
        let request = CheckPrompt.request(paragraph: "x", language: "en", model: "gemini-3.5-flash-lite")
        let result = await backends(forbidden).send(request, to: .cloud(service: gemini(forbidden), model: "gemini-3.5-flash-lite", apiKey: ""))
        #expect(result == .failure(.invalidAPIKey))
    }

    @Test func anExhaustedQuotaIsNotMistakenForARateLimit() async {
        let message = "You exceeded your current quota, please check your plan and billing details."
        let exhausted = MockServer { _, _ in .json(429, #"{"error":{"code":429,"message":"\#(message)","status":"RESOURCE_EXHAUSTED"}}"#) }
        let request = CheckPrompt.request(paragraph: "x", language: "en", model: "gemini-3.5-flash-lite")
        let result = await backends(exhausted).send(request, to: .cloud(service: gemini(exhausted), model: "gemini-3.5-flash-lite", apiKey: "AIzaTest"))
        #expect(result == .failure(.http(status: 429, message: message)))
    }
}
