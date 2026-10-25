import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct XAITests {
    private func xai(_ server: MockServer) -> CloudService {
        let real = CloudService.xai
        return CloudService(
            id: real.id, name: real.name, assistantName: real.assistantName,
            baseURL: server.baseURL.appending(path: "v1"), consoleURL: real.consoleURL,
            keyHint: real.keyHint, environmentVariable: real.environmentVariable,
            models: real.models, defaultModel: real.defaultModel, style: real.style,
            listsModels: real.listsModels, notes: real.notes
        )
    }

    private func engine(_ server: MockServer) -> HybridGrammarEngine {
        HybridGrammarEngine(apiKeyProvider: { _ in "xai-test" }, backends: AIBackends(claude: server.client(), local: server.localClient()))
    }

    static func grokBody(content: String, finishReason: String = "stop") -> String {
        let escaped = JSONValue.string(content).serialized
        return """
        {"id":"8d2e5d27-7c2b-4d3b-9b4c-2a9f1d0f5e6a","object":"chat.completion","created":1792491200,"model":"grok-4.3",\
        "choices":[{"index":0,"message":{"role":"assistant","content":\(escaped),"reasoning_content":"The verb should agree with the subject.","refusal":null},\
        "finish_reason":"\(finishReason)"}],\
        "usage":{"prompt_tokens":412,"completion_tokens":58,"total_tokens":470,\
        "prompt_tokens_details":{"cached_tokens":380},"completion_tokens_details":{"reasoning_tokens":21}},\
        "system_fingerprint":"fp_abc123"}
        """
    }

    @Test func descriptorMatchesTheVerifiedCatalogue() throws {
        let service = CloudService.xai
        #expect(service.id == "xai")
        #expect(service.baseURL.absoluteString == "https://api.x.ai/v1")
        #expect(service.environmentVariable == "XAI_API_KEY")
        #expect(service.models.map(\.id) == ["grok-4.3", "grok-4.5", "grok-4.7"])
        #expect(service.defaultModel == "grok-4.3")
        let cheap = try #require(service.pricing(for: "grok-4.3"))
        #expect(cheap.input == 1.25 && cheap.output == 2.50 && cheap.cacheRead == 0.20)
        let best = try #require(service.pricing(for: "grok-4.7"))
        #expect(best.input == 2.00 && best.output == 6.00 && best.cacheRead == 0.50)
        #expect(service.style.outputLimit == .maxCompletionTokens)
        #expect(service.style.reasoningEffort == "low")
        #expect(service.style.structuredOutput == .jsonSchema)
        #expect(AIProvider(rawValue: "xai") == .cloud("xai"))
        #expect(AIProvider.cloud("xai").assistantName == "Grok")
    }

    @Test func checksAreSentAsGrokExpects() async throws {
        let server = MockServer { _, _ in .json(200, Self.grokBody(content: #"{"edits":[]}"#)) }
        let service = xai(server)
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "xai-test")
        let backends = AIBackends(claude: server.client(), local: server.localClient())
        let response = try await backends.send(CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: "grok-4.3"), to: endpoint).get()

        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.header("authorization") == "Bearer xai-test")
        let json = request.json
        #expect(json["model"] as? String == "grok-4.3")
        #expect(json["max_completion_tokens"] != nil && json["max_tokens"] == nil, "max_tokens is deprecated at xAI")
        #expect(json["reasoning_effort"] as? String == "low")
        #expect(json["temperature"] == nil && json["top_p"] == nil && json["presence_penalty"] == nil && json["stop"] == nil, "reasoning models reject these")
        #expect((json["messages"] as? [[String: Any]])?.map { $0["role"] as? String } == ["system", "user"])
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["strict"] as? Bool == true && schema["name"] as? String == "response")
        #expect(((schema["schema"] as? [String: Any])?["additionalProperties"] as? Bool) == false, "xAI defaults additionalProperties to false; the schema says so explicitly")

        #expect(response.text == #"{"edits":[]}"#, "the answer, not the reasoning")
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "grok-4.3")
        #expect(response.usage == TokenUsage(input: 32, output: 58, cacheRead: 380), "cache hits are counted apart")
    }

    @Test func keysAreValidatedAgainstTheModelList() async throws {
        let models = """
        {"object":"list","data":[
          {"id":"grok-4.7","object":"model","created":1778000000,"owned_by":"xai","aliases":["grok-4.7-latest"],"context_length":500000,\
           "prompt_text_token_price":20000,"cached_prompt_text_token_price":5000,"completion_text_token_price":60000,\
           "capabilities":{"reasoning_effort":["low","medium","high","xhigh"],"default_reasoning_effort":"high"}},
          {"id":"grok-4.3","object":"model","created":1775000000,"owned_by":"xai","aliases":["grok-4.3-latest"],"context_length":1000000},
          {"id":"grok-embedding-1","object":"model","created":1775000000,"owned_by":"xai","aliases":[]}
        ]}
        """
        let server = MockServer { _, request in
            guard request.header("authorization") == "Bearer xai-test" else {
                return .json(401, #"{"code":"The API key you provided is invalid","error":"Incorrect API key provided: xai-bad. You can obtain an API key from https://console.x.ai."}"#)
            }
            return .json(200, models)
        }
        let service = xai(server)
        let engine = engine(server)
        try await engine.validateAPIKey("xai-test", service: service, model: "grok-4.3")
        #expect(server.requests.first?.path == "/v1/models")
        #expect(try await engine.cloudModels(for: service, apiKey: "xai-test") == ["grok-4.3", "grok-4.7"], "sorted, without the embedding model")

        let bad = HybridGrammarEngine(apiKeyProvider: { _ in "xai-bad" }, backends: AIBackends(claude: server.client(), local: server.localClient()))
        await #expect(throws: RewriteError.failed("Invalid xAI (Grok) API key")) {
            try await bad.validateAPIKey("xai-bad", service: service, model: "grok-4.3")
        }
    }

    @Test func aRateLimitWithAPlainErrorStringIsBusy() async {
        let busy = MockServer { _, _ in .json(429, #"{"error":"Rate limit reached","code":"rate_limit"}"#) }
        let service = xai(busy)
        let result = await AIBackends(claude: busy.client(), local: busy.localClient())
            .send(CheckPrompt.request(paragraph: "x", language: "en", model: "grok-4.3"), to: .cloud(service: service, model: "grok-4.3", apiKey: "xai-test"))
        #expect(result == .failure(.busy))
    }
}
