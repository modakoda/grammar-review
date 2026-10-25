import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

@Suite struct OpenAITests {
    private func openAI(_ server: MockServer) -> CloudService {
        let real = CloudService.openAI
        return CloudService(
            id: real.id, name: real.name, assistantName: real.assistantName,
            baseURL: server.baseURL.appending(path: "v1"), consoleURL: real.consoleURL,
            keyHint: real.keyHint, environmentVariable: real.environmentVariable,
            models: real.models, defaultModel: real.defaultModel, style: real.style,
            listsModels: real.listsModels, notes: real.notes
        )
    }

    private func backends(_ server: MockServer) -> AIBackends {
        AIBackends(claude: server.client(), local: server.localClient())
    }

    private func engine(_ server: MockServer) -> HybridGrammarEngine {
        HybridGrammarEngine(apiKeyProvider: { provider in provider == .claude ? nil : "sk-proj-test" }, backends: backends(server))
    }

    private static let reasoning = CloudService.RequestStyle(
        structuredOutput: .jsonSchema, outputLimit: .maxCompletionTokens, systemRole: "developer", reasoningEffort: "low"
    )

    @Test func theDescriptorMatchesTheDocs() {
        let service = CloudService.openAI
        #expect(service.id == "openai" && service.name == "OpenAI" && service.assistantName == "GPT")
        #expect(service.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(service.consoleURL.host() == "platform.openai.com")
        #expect(service.keyHint.hasPrefix("sk-"))
        #expect(service.environmentVariable == "OPENAI_API_KEY")
        #expect(service.listsModels, "GET /v1/models works with a key")
        #expect(service.models.map(\.id) == ["gpt-6-luna", "gpt-6.1-sol", "gpt-6-astra"])
        #expect(service.defaultModel == "gpt-6-luna" && service.option(for: service.defaultModel) != nil)
        #expect(service.models.allSatisfy { $0.pricing != nil })
        #expect(service.pricing(for: "gpt-6-luna") == ModelPricing(input: 0.10, output: 0.50, cacheWrite: 0.125, cacheRead: 0.01))
        #expect(service.pricing(for: "gpt-6.1-sol") == ModelPricing(input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.10))
        #expect(service.pricing(for: "gpt-6-astra") == ModelPricing(input: 10, output: 50, cacheWrite: 12.5, cacheRead: 1))
        #expect(service.pricing(for: "gpt-5-mini") == nil, "models due for shutdown aren't offered")
        #expect(CloudService.find("openai") == service)
    }

    @Test func lunaAnswersWithoutReasoningAndTheOthersThinkBriefly() {
        let service = CloudService.openAI
        #expect(service.style == Self.reasoning)
        var direct = Self.reasoning
        direct.reasoningEffort = "none"
        #expect(service.style(for: "gpt-6-luna") == direct)
        #expect(service.style(for: "gpt-6.1-sol") == Self.reasoning && service.style(for: "gpt-6-astra") == Self.reasoning, "Sol and Astra reject none and minimal")
        #expect(service.style(for: "gpt-5.4-mini") == Self.reasoning, "a model typed by hand gets the service's style")
    }

    @Test func checksWithTheDefaultModelAreShapedForLuna() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
        let service = openAI(server)
        let ai = backends(server)
        let recorded = OSAllocatedUnfairLock<[UsageEvent]>(initialState: [])
        ai.usage.setHandler { event in recorded.withLock { $0.append(event) } }
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "sk-proj-test")
        let paragraph = "I has a cat."
        let result = await ai.send(CheckPrompt.request(paragraph: paragraph, language: "en", model: endpoint.model), to: endpoint)
        #expect(try result.get().text == #"{"edits":[]}"#)

        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.request.httpMethod == "POST")
        #expect(request.header("authorization") == "Bearer sk-proj-test")
        #expect(request.header("content-type") == "application/json")
        let json = request.json
        #expect(json["model"] as? String == "gpt-6-luna")
        #expect(json["max_completion_tokens"] as? Int == CheckPrompt.maxTokens(for: paragraph))
        #expect(json["max_tokens"] == nil, "deprecated, and rejected by reasoning models")
        #expect(json["reasoning_effort"] as? String == "none")
        #expect(json["temperature"] == nil && json["top_p"] == nil, "the model's defaults apply")
        #expect(json["stream"] as? Bool == false)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["developer", "user"])
        #expect(messages.first?["content"] as? String == CheckPrompt.system, "the schema is enforced, not pasted into the prompt")
        #expect((messages.last?["content"] as? String)?.contains(paragraph) == true)

        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["name"] as? String == "response")
        #expect(schema["strict"] as? Bool == true)
        let root = try #require(schema["schema"] as? [String: Any])
        #expect(root["type"] as? String == "object")
        #expect(root["additionalProperties"] as? Bool == false, "strict mode wants it on every object")
        #expect(root["required"] as? [String] == ["edits"])
        let item = try #require(((root["properties"] as? [String: Any])?["edits"] as? [String: Any])?["items"] as? [String: Any])
        #expect(item["additionalProperties"] as? Bool == false)
        #expect(Set(item["required"] as? [String] ?? []) == Set((item["properties"] as? [String: Any] ?? [:]).keys), "strict mode wants every property required")

        #expect(recorded.withLock { $0 } == [UsageEvent(provider: .cloud("openai"), model: "gpt-6-luna", purpose: .check, tokens: TokenUsage(input: 12, output: 34))])

        _ = await ai.send(RewritePrompt.request(text: "Some text.", tone: .formal, language: "en", model: endpoint.model), to: endpoint)
        let rewrite = try #require(server.requests.last).json
        #expect(rewrite["response_format"] == nil)
        #expect(rewrite["reasoning_effort"] as? String == "none")
        #expect(rewrite["max_completion_tokens"] != nil && rewrite["max_tokens"] == nil)
        #expect((rewrite["messages"] as? [[String: Any]])?.first?["role"] as? String == "developer")
    }

    @Test func solAndAstraThinkBriefly() async throws {
        for model in ["gpt-6.1-sol", "gpt-6-astra"] {
            let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
            let service = openAI(server)
            let endpoint = AIEndpoint.cloud(service: service, model: model, apiKey: "sk-proj-test")
            _ = await backends(server).send(CheckPrompt.request(paragraph: "x", language: "en", model: model), to: endpoint)
            let json = try #require(server.requests.first).json
            #expect(json["model"] as? String == model)
            #expect(json["reasoning_effort"] as? String == "low", "\(model) rejects none and minimal")
            #expect(json["max_completion_tokens"] != nil && json["max_tokens"] == nil)
            #expect(json["temperature"] == nil && json["top_p"] == nil)
            #expect((json["messages"] as? [[String: Any]])?.first?["role"] as? String == "developer")
            #expect((json["response_format"] as? [String: Any])?["type"] as? String == "json_schema")
        }
    }

    @Test func answersDecodeLikeTheReference() throws {
        let edits = [edit("has", "have", before: "I ")]
        let response = try ChatCompletionsClient.decodeCompletion(Data(openAIBody(content: editsJSON(edits)).utf8)).get()
        #expect(response.text == editsJSON(edits))
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "gpt-6-luna")
        #expect(response.usage == TokenUsage(input: 713, output: 41), "reasoning tokens are part of completion_tokens")
        #expect(try CheckPrompt.parse(response).get() == edits)
    }

    @Test func theSettingsTestProofreadsThroughOpenAI() async throws {
        let edits = [edit("go", "goes", before: "She "), edit("every days", "every day", before: "school ")]
        let server = MockServer { _, _ in .json(200, openAIBody(content: editsJSON(edits))) }
        let result = try await engine(server).testCloudModel("gpt-6-luna", service: openAI(server), apiKey: "sk-proj-test")
        #expect(result.suggestionCount == 2)
        #expect(server.requests.count == 1 && server.requests.first?.json["model"] as? String == "gpt-6-luna")
    }

    @Test func keysAreCheckedAgainstTheModelsList() async throws {
        let models = """
        {"object":"list","data":[\
        {"id":"gpt-6-luna","object":"model","created":1771200000,"owned_by":"system","shutdown_date":null},\
        {"id":"text-embedding-3-small","object":"model","created":1705948997,"owned_by":"system","shutdown_date":null},\
        {"id":"gpt-6-astra","object":"model","created":1771200000,"owned_by":"system","shutdown_date":null},\
        {"id":"text-embedding-3-large","object":"model","created":1705953180,"owned_by":"system","shutdown_date":null},\
        {"id":"gpt-5.4-mini","object":"model","created":1773705600,"owned_by":"system","shutdown_date":null}]}
        """
        let invalidKey = """
        {"error":{"message":"Incorrect API key provided: sk-proj-***. You can find your API key at \
        https://platform.openai.com/account/api-keys.","type":"invalid_request_error","param":null,"code":"invalid_api_key"}}
        """
        let server = MockServer { _, request in
            request.header("authorization") == "Bearer sk-proj-good" ? .json(200, models) : .json(401, invalidKey)
        }
        let engine = engine(server)
        let service = openAI(server)

        try await engine.validateAPIKey("sk-proj-good", service: service, model: service.defaultModel)
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/models")
        #expect(request.request.httpMethod == "GET")
        #expect(request.header("authorization") == "Bearer sk-proj-good")
        #expect(request.body.isEmpty)

        #expect(try await engine.cloudModels(for: service, apiKey: "sk-proj-good") == ["gpt-5.4-mini", "gpt-6-astra", "gpt-6-luna"], "sorted, without embedding models")

        await #expect(throws: RewriteError.failed("Invalid OpenAI API key")) {
            try await engine.validateAPIKey("sk-proj-bad", service: service, model: service.defaultModel)
        }
        await #expect(throws: RewriteError.failed("Invalid OpenAI API key")) {
            _ = try await engine.cloudModels(for: service, apiKey: "sk-proj-bad")
        }
        await #expect(throws: RewriteError.failed("Enter your OpenAI API key")) {
            try await engine.validateAPIKey(" ", service: service, model: service.defaultModel)
        }
    }

    @Test func aBadKeyStopsACheckWithTheServiceNamed() async {
        let server = MockServer { _, _ in
            .json(401, #"{"error":{"message":"Incorrect API key provided: sk-proj-***.","type":"invalid_request_error","param":null,"code":"invalid_api_key"}}"#)
        }
        let service = openAI(server)
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "sk-proj-bad")
        let result = await backends(server).send(CheckPrompt.request(paragraph: "x", language: "en", model: endpoint.model), to: endpoint)
        #expect(result == .failure(.invalidAPIKey))
        #expect(AIError.invalidAPIKey.userMessage(for: endpoint) == "Invalid OpenAI API key")
        #expect(AIError.invalidAPIKey.stopsBatch)
    }
}

private func openAIBody(content: String, finishReason: String = "stop") -> String {
    """
    {"id":"chatcmpl-abc123","object":"chat.completion","created":1738960610,"model":"gpt-6-luna",\
    "choices":[{"index":0,"message":{"role":"assistant","content":\(JSONValue.string(content).serialized),"refusal":null,"annotations":[]},\
    "logprobs":null,"finish_reason":"\(finishReason)"}],\
    "usage":{"prompt_tokens":713,"completion_tokens":41,"total_tokens":754,\
    "prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0},\
    "completion_tokens_details":{"reasoning_tokens":0,"audio_tokens":0,"accepted_prediction_tokens":0,"rejected_prediction_tokens":0}},\
    "service_tier":"default","system_fingerprint":null}
    """
}
