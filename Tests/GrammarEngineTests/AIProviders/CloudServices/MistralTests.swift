import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct MistralTests {
    private func mistral(_ server: MockServer) -> CloudService {
        let real = CloudService.mistral
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

    static func mistralBody(content: String, finishReason: String = "stop") -> String {
        let escaped = JSONValue.string(content).serialized
        return """
        {"id":"cmpl-e5cc70bb28c444948073e77776eb30ef","object":"chat.completion","created":1792491200,"model":"mistral-small-2603",\
        "choices":[{"index":0,"message":{"role":"assistant","content":\(escaped),"tool_calls":null},"finish_reason":"\(finishReason)"}],\
        "usage":{"prompt_tokens":402,"total_tokens":453,"completion_tokens":51}}
        """
    }

    @Test func descriptorMatchesTheVerifiedCatalogue() throws {
        let service = CloudService.mistral
        #expect(service.id == "mistral")
        #expect(service.baseURL.absoluteString == "https://api.mistral.ai/v1")
        #expect(service.environmentVariable == "MISTRAL_API_KEY")
        #expect(service.models.map(\.id) == ["mistral-small-latest", "ministral-8b-latest", "mistral-medium-latest", "mistral-large-latest"])
        #expect(service.defaultModel == "mistral-small-latest")
        let small = try #require(service.pricing(for: "mistral-small-latest"))
        #expect(small.input == 0.15 && small.output == 0.60 && small.cacheRead == 0.015)
        let medium = try #require(service.pricing(for: "mistral-medium-latest"))
        #expect(medium.input == 1.50 && medium.output == 7.50)
        let large = try #require(service.pricing(for: "mistral-large-latest"))
        #expect(large.input == 1.36 && large.output == 4.18)
        #expect(service.style.reasoningEffort == "none" && service.style.outputLimit == .maxTokens && service.style.structuredOutput == .jsonSchema)
        #expect(service.name == "Mistral" && AIProvider.cloud("mistral").assistantName == "Mistral")
    }

    @Test func checksAreSentAsLaPlateformeExpects() async throws {
        let server = MockServer { _, _ in .json(200, Self.mistralBody(content: #"{"edits":[]}"#)) }
        let service = mistral(server)
        let endpoint = AIEndpoint.cloud(service: service, model: service.defaultModel, apiKey: "mk-test")
        let response = try await backends(server).send(CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: "mistral-small-latest"), to: endpoint).get()

        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.header("authorization") == "Bearer mk-test")
        let json = request.json
        #expect(json["model"] as? String == "mistral-small-latest")
        #expect(json["max_tokens"] != nil && json["max_completion_tokens"] == nil)
        #expect(json["reasoning_effort"] as? String == "none", "no thinking for a quick check")
        #expect(json["safe_prompt"] == nil && json["temperature"] == nil, "the model's defaults apply")
        #expect((json["messages"] as? [[String: Any]])?.map { $0["role"] as? String } == ["system", "user"])
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect((format["json_schema"] as? [String: Any])?["strict"] as? Bool == true)

        #expect(response.text == #"{"edits":[]}"#)
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "mistral-small-2603", "the alias resolves to a dated release")
        #expect(response.usage == TokenUsage(input: 402, output: 51))
    }

    @Test func keysAreValidatedAgainstTheModelList() async throws {
        let models = """
        {"object":"list","data":[
          {"id":"mistral-small-latest","object":"model","created":1773700000,"owned_by":"mistralai","capabilities":{"completion_chat":true,"function_calling":true,"vision":true},"aliases":["mistral-small-2603"]},
          {"id":"mistral-embed","object":"model","created":1700000000,"owned_by":"mistralai","capabilities":{"completion_chat":false}},
          {"id":"codestral-embed","object":"model","created":1748000000,"owned_by":"mistralai"},
          {"id":"ministral-8b-latest","object":"model","created":1765000000,"owned_by":"mistralai"}
        ]}
        """
        let server = MockServer { _, request in
            guard request.header("authorization") == "Bearer mk-test" else {
                return .json(401, #"{"message":"Unauthorized","request_id":"9e3f5f1c1e3e4b1c8f6a2b0c1d2e3f40"}"#)
            }
            return .json(200, models)
        }
        let service = mistral(server)
        let engine = HybridGrammarEngine(apiKeyProvider: { _ in "mk-test" }, backends: backends(server))
        try await engine.validateAPIKey("mk-test", service: service, model: "mistral-small-latest")
        #expect(server.requests.first?.path == "/v1/models")
        #expect(try await engine.cloudModels(for: service, apiKey: "mk-test") == ["ministral-8b-latest", "mistral-small-latest"], "sorted, without the embedding models")

        let bad = HybridGrammarEngine(apiKeyProvider: { _ in "mk-bad" }, backends: backends(server))
        await #expect(throws: RewriteError.failed("Invalid Mistral API key")) {
            try await bad.validateAPIKey("mk-bad", service: service, model: "mistral-small-latest")
        }
    }
}
