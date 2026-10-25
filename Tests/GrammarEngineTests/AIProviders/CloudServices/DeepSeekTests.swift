import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct DeepSeekTests {
    private func deepseek(_ server: MockServer) -> CloudService {
        let real = CloudService.deepseek
        return CloudService(
            id: real.id, name: real.name, assistantName: real.assistantName,
            baseURL: server.baseURL, consoleURL: real.consoleURL,
            keyHint: real.keyHint, environmentVariable: real.environmentVariable,
            models: real.models, defaultModel: real.defaultModel, style: real.style,
            listsModels: real.listsModels, notes: real.notes
        )
    }

    private func backends(_ server: MockServer) -> AIBackends {
        AIBackends(claude: server.client(), local: server.localClient())
    }

    static func deepseekBody(content: String, finishReason: String = "stop", reasoning: String? = nil) -> String {
        let escaped = JSONValue.string(content).serialized
        let reasoningField = reasoning.map { ",\"reasoning_content\":\(JSONValue.string($0).serialized)" } ?? ""
        return """
        {"id":"5b2c7e8a-3f1d-4c9b-9e2a-7d1f0c4b8e21","object":"chat.completion","created":1792491200,"model":"deepseek-flash",\
        "choices":[{"index":0,"message":{"role":"assistant","content":\(escaped)\(reasoningField)},"logprobs":null,"finish_reason":"\(finishReason)"}],\
        "usage":{"prompt_tokens":420,"completion_tokens":44,"total_tokens":464,"prompt_cache_hit_tokens":384,"prompt_cache_miss_tokens":36,\
        "prompt_tokens_details":{"cached_tokens":384},"completion_tokens_details":{"reasoning_tokens":0}},"system_fingerprint":"fp_7f3c"}
        """
    }

    @Test func descriptorMatchesTheVerifiedCatalogue() throws {
        let service = CloudService.deepseek
        #expect(service.id == "deepseek" && service.name == "DeepSeek" && service.assistantName == "DeepSeek")
        #expect(service.baseURL.absoluteString == "https://api.deepseek.com")
        #expect(service.environmentVariable == "DEEPSEEK_API_KEY")
        #expect(service.models.map(\.id) == ["deepseek-flash", "deepseek-v4-pro"])
        #expect(service.defaultModel == "deepseek-flash")
        let flash = try #require(service.pricing(for: "deepseek-flash"))
        #expect(flash.input == 0.30 && flash.output == 1.20 && flash.cacheRead == 0.006)
        let pro = try #require(service.pricing(for: "deepseek-v4-pro"))
        #expect(pro.input == 1.32 && pro.output == 3.96 && pro.cacheRead == 0.044)
        #expect(service.style.structuredOutput == .jsonObject)
        #expect(service.style.reasoningEffort == "none")
        #expect(service.style.outputLimit == .maxTokens)
    }

    @Test func checksUseJSONModeWithTheSchemaInThePrompt() async throws {
        let server = MockServer { _, _ in .json(200, Self.deepseekBody(content: editsJSON([edit("has", "have", before: "I ")]))) }
        let service = deepseek(server)
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "sk-deepseek")
        let request = CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: "deepseek-flash")
        let edits = try await backends(server).send(request, to: endpoint).flatMap(CheckPrompt.parse).get()
        #expect(EditLocator.locate(edits, in: "I has a cat.").map(\.range) == [NSRange(location: 2, length: 3)])

        let sent = try #require(server.requests.first)
        #expect(sent.path == "/chat/completions")
        #expect(sent.header("authorization") == "Bearer sk-deepseek")
        let json = sent.json
        #expect(json["model"] as? String == "deepseek-flash")
        #expect((json["response_format"] as? [String: Any])?["type"] as? String == "json_object")
        #expect(json["reasoning_effort"] as? String == "none", "thinking off for a quick check")
        #expect(json["max_tokens"] != nil && json["thinking"] == nil && json["temperature"] == nil)
        let system = (json["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(system.hasPrefix(CheckPrompt.system))
        #expect(system.lowercased().contains("json"), "DeepSeek's JSON mode needs the word in the prompt")
        #expect(system.contains("\"edits\"") && system.contains("context_before"), "the schema is in the prompt")
    }

    @Test func theReasoningStaysOutOfTheAnswerAndCacheHitsAreCounted() throws {
        let body = Self.deepseekBody(content: #"{"edits":[]}"#, reasoning: "The sentence looks fine.")
        let response = try ChatCompletionsClient.decodeCompletion(Data(body.utf8)).get()
        #expect(response.text == #"{"edits":[]}"#)
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "deepseek-flash")
        #expect(response.usage == TokenUsage(input: 36, output: 44, cacheRead: 384))
    }

    @Test func keysAreValidatedAgainstTheModelList() async throws {
        let models = """
        {"object":"list","data":[
          {"id":"deepseek-flash","object":"model","owned_by":"deepseek","name":"DeepSeek-V4.1-Flash","context_window":1048576,"max_output_tokens":393216,\
           "effort":{"supported_levels":["low","high","max"],"default_level":"high"}},
          {"id":"deepseek-v4-pro","object":"model","owned_by":"deepseek","name":"DeepSeek-V4-Pro","context_window":1048576,"max_output_tokens":393216}
        ]}
        """
        let server = MockServer { _, request in
            guard request.header("authorization") == "Bearer sk-deepseek" else {
                return .json(401, #"{"error":{"message":"Authentication Fails, Your api key: ****bad is invalid","type":"authentication_error","param":null,"code":"invalid_request_error"}}"#)
            }
            return .json(200, models)
        }
        let service = deepseek(server)
        let engine = HybridGrammarEngine(apiKeyProvider: { _ in "sk-deepseek" }, backends: backends(server))
        try await engine.validateAPIKey("sk-deepseek", service: service, model: "deepseek-flash")
        #expect(server.requests.first?.path == "/models")
        #expect(try await engine.cloudModels(for: service, apiKey: "sk-deepseek") == ["deepseek-flash", "deepseek-v4-pro"])

        let bad = HybridGrammarEngine(apiKeyProvider: { _ in "sk-bad" }, backends: backends(server))
        await #expect(throws: RewriteError.failed("Invalid DeepSeek API key")) {
            try await bad.validateAPIKey("sk-bad", service: service, model: "deepseek-flash")
        }
    }

    @Test func balanceAndOverloadErrorsAreRecognised() async {
        let broke = MockServer { _, _ in .json(402, #"{"error":{"message":"Insufficient Balance","type":"unknown_error","param":null,"code":"invalid_request_error"}}"#) }
        let service = deepseek(broke)
        let request = CheckPrompt.request(paragraph: "x", language: "en", model: "deepseek-flash")
        let result = await backends(broke).send(request, to: .cloud(service: service, model: "deepseek-flash", apiKey: "sk-deepseek"))
        #expect(result == .failure(.http(status: 402, message: "Insufficient Balance")))
        let overloaded = MockServer { _, _ in .json(503, #"{"error":{"message":"Server Overloaded"}}"#) }
        let busy = await backends(overloaded).send(request, to: .cloud(service: deepseek(overloaded), model: "deepseek-flash", apiKey: "sk-deepseek"))
        #expect(busy == .failure(.busy))
    }
}
