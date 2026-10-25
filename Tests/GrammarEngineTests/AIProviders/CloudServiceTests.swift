import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct CloudServiceTests {
    private func service(_ server: MockServer, style: CloudService.RequestStyle = .standard, listsModels: Bool = true) -> CloudService {
        CloudService(
            id: "test", name: "Test AI", assistantName: "Tess",
            baseURL: server.baseURL.appending(path: "v1"), consoleURL: server.baseURL,
            keyHint: "key", environmentVariable: "TEST_AI_KEY",
            models: [AIModelOption(id: "tess-1", name: "Tess 1", detail: "", pricing: ModelPricing(input: 1, output: 2))],
            defaultModel: "tess-1", style: style, listsModels: listsModels, notes: ""
        )
    }

    private func engine(_ server: MockServer, key: String? = "sk-cloud") -> HybridGrammarEngine {
        let backends = AIBackends(claude: server.client(), local: server.localClient())
        return HybridGrammarEngine(apiKeyProvider: { provider in provider == .claude ? nil : key }, backends: backends)
    }

    @Test func registryIsConsistent() {
        let ids = CloudService.all.map(\.id)
        #expect(Set(ids).count == ids.count, "unique IDs")
        for service in CloudService.all {
            #expect(service.id == service.id.lowercased() && !service.id.contains(" "), "\(service.id) is a stable, lowercase ID")
            #expect(service.baseURL.scheme == "https", "\(service.id) uses https")
            #expect(service.consoleURL.scheme == "https")
            #expect(!service.models.isEmpty && service.option(for: service.defaultModel) != nil, "\(service.id)'s default model is listed")
            #expect(Set(service.models.map(\.id)).count == service.models.count)
            #expect(service.models.allSatisfy { $0.pricing != nil }, "\(service.id) prices every listed model")
            #expect(service.environmentVariable.hasSuffix("_API_KEY"))
            #expect(CloudService.find(service.id) == service)
            #expect(AIProvider(rawValue: service.id) == .cloud(service.id))
        }
        #expect(AIProvider.allCases.first == .claude && AIProvider.allCases.last == .local)
        #expect(AIProvider.allCases.count == CloudService.all.count + 2)
    }

    @Test func providerRoundTripsThroughJSONAndRejectsUnknownServices() throws {
        for provider in AIProvider.allCases {
            let data = try JSONEncoder().encode([provider])
            #expect(try JSONDecoder().decode([AIProvider].self, from: data) == [provider])
        }
        #expect(String(data: try JSONEncoder().encode([AIProvider.cloud("openai")]), encoding: .utf8) == #"["openai"]"#)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([AIProvider].self, from: Data(#"["bogus"]"#.utf8)) }
        #expect(AIProvider(rawValue: "bogus") == nil)
        #expect(AIProvider.cloud("openai").displayName == "OpenAI (API key)")
        #expect(AIProvider.cloud("openai").assistantName == "GPT")
        #expect(AIProvider.cloud("openai").usesAPIKey && AIProvider.claude.usesAPIKey && !AIProvider.local.usesAPIKey)
    }

    @Test func cloudRequestsCarryTheBearerTokenAndTheServicesStyle() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
        let style = CloudService.RequestStyle(structuredOutput: .jsonSchema, outputLimit: .maxCompletionTokens, systemRole: "developer", reasoningEffort: "low")
        let service = service(server, style: style)
        var settings = testSettings { $0.aiProvider = .cloud("test") }
        settings.cloudModels["test"] = "tess-1"
        let endpoint = AIEndpoint.cloud(service: service, model: settings.cloudModel(for: service), apiKey: "sk-cloud")
        let backends = AIBackends(claude: server.client(), local: server.localClient())
        _ = await backends.send(CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: "tess-1"), to: endpoint)

        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.header("authorization") == "Bearer sk-cloud")
        #expect(request.header("x-api-key") == nil)
        #expect(request.request.timeoutInterval == ClaudeClient.defaultTimeout, "cloud services get the request's own timeout")
        let json = request.json
        #expect(json["max_completion_tokens"] != nil && json["max_tokens"] == nil)
        #expect(json["reasoning_effort"] as? String == "low")
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "developer")
        #expect((json["response_format"] as? [String: Any])?["type"] as? String == "json_schema")
        #expect(endpoint.cacheID == "test#tess-1" && endpoint.provider == .cloud("test"))
    }

    @Test func servicesWithoutSchemaSupportGetTheSchemaInThePrompt() throws {
        let request = CheckPrompt.request(paragraph: "x", language: "en", model: "m")
        let object = ChatCompletionsClient.chatBody(request, style: CloudService.RequestStyle(structuredOutput: .jsonObject))
        let json = try #require(try JSONSerialization.jsonObject(with: object.data) as? [String: Any])
        #expect((json["response_format"] as? [String: Any])?["type"] as? String == "json_object")
        let system = (json["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(system.hasPrefix(CheckPrompt.system))
        #expect(system.contains("JSON Schema") && system.contains("\"edits\""))

        let none = ChatCompletionsClient.chatBody(request, style: CloudService.RequestStyle(structuredOutput: .none))
        let noneJSON = try #require(try JSONSerialization.jsonObject(with: none.data) as? [String: Any])
        #expect(noneJSON["response_format"] == nil)
        #expect(((noneJSON["messages"] as? [[String: Any]])?.first?["content"] as? String)?.contains("JSON Schema") == true)

        let rewrite = RewritePrompt.request(text: "x", tone: .formal, language: "en", model: "m")
        let rewriteBody = ChatCompletionsClient.chatBody(rewrite, style: CloudService.RequestStyle(structuredOutput: .jsonObject))
        let rewriteJSON = try #require(try JSONSerialization.jsonObject(with: rewriteBody.data) as? [String: Any])
        #expect(rewriteJSON["response_format"] == nil)
        #expect(((rewriteJSON["messages"] as? [[String: Any]])?.first?["content"] as? String)?.contains("JSON Schema") == false)
    }

    @Test func aModelsOwnStyleWinsOverTheServices() {
        let reasoning = CloudService.RequestStyle(outputLimit: .maxCompletionTokens, reasoningEffort: "low")
        let service = CloudService(
            id: "s", name: "S", assistantName: "S", baseURL: URL(string: "https://s.test/v1")!, consoleURL: URL(string: "https://s.test")!,
            keyHint: "", environmentVariable: "S_API_KEY",
            models: [AIModelOption(id: "plain", name: "", detail: ""), AIModelOption(id: "think", name: "", detail: "", style: reasoning)],
            defaultModel: "plain", notes: ""
        )
        #expect(service.style(for: "plain") == .standard)
        #expect(service.style(for: "think") == reasoning)
        #expect(service.style(for: "unknown") == .standard)
    }

    @Test func keysAreValidatedWithATinyCompletionWhereModelsCannotBeListed() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: "OK")) }
        let service = service(server, listsModels: false)
        try await engine(server).validateAPIKey("sk-good", service: service, model: "tess-1")
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect((request.json["max_tokens"] as? Int ?? 0) <= 16)
    }

    @Test func aMissingServiceKeyNamesTheService() async {
        let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
        let settings = testSettings { $0.aiProvider = .cloud("openai") }
        let results = await collect(engine(server, key: nil).check(CheckRequest(text: "I has a cat.", bundleID: nil, settings: settings)))
        #expect(results.last?.aiStatus == .failed("Add your OpenAI API key in Settings → AI"))
        #expect(server.requests.isEmpty)
        await #expect(throws: RewriteError.failed("Add your OpenAI API key in Settings → AI")) {
            try await engine(server, key: nil).rewrite("Some text.", tone: .formal, settings: settings)
        }
    }

    @Test func aBlankModelChoiceMeansTheDefault() {
        var settings = AppSettings()
        #expect(settings.cloudModel(for: .openAI) == CloudService.openAI.defaultModel)
        settings.cloudModels["openai"] = "  "
        #expect(settings.cloudModel(for: .openAI) == CloudService.openAI.defaultModel)
        settings.cloudModels["openai"] = "gpt-custom"
        #expect(settings.cloudModel(for: .openAI) == "gpt-custom")
    }

    @Test func cloudUsageIsPricedFromTheService() {
        var ledger = UsageLedger(month: "2026-10")
        let model = CloudService.openAI.defaultModel
        ledger.record(UsageEvent(provider: .cloud("openai"), model: model, purpose: .check, tokens: TokenUsage(input: 1_000_000, output: 1_000_000)), month: "2026-10")
        ledger.record(UsageEvent(provider: .cloud("openai"), model: "gpt-unknown", purpose: .check, tokens: TokenUsage(input: 5)), month: "2026-10")
        let expected = CloudService.openAI.pricing(for: model)!.cost(of: TokenUsage(input: 1_000_000, output: 1_000_000))
        #expect(abs(ledger.current.estimatedCost - expected) < 1e-9)
        #expect(ledger.current.hasUnpricedUsage)
        #expect(ModelPricing(input: 2, output: 4).cacheRead == 2, "no separate cached-input price means the input price")
    }

    @Test func spentCreditIsNotMistakenForARateLimit() async {
        let broke = MockServer { _, _ in
            .json(429, #"{"error":{"message":"You exceeded your current quota, please check your plan and billing details.","type":"insufficient_quota","param":null,"code":"insufficient_quota"}}"#)
        }
        let backends = AIBackends(claude: broke.client(), local: broke.localClient())
        let request = CheckPrompt.request(paragraph: "x", language: "en", model: "tess-1")
        let result = await backends.send(request, to: .cloud(service: service(broke), model: "tess-1", apiKey: "sk-cloud"))
        #expect(result == .failure(.http(status: 429, message: "You exceeded your current quota, please check your plan and billing details.")))
        #expect(AIError.http(status: 429, message: nil).userMessage(forService: service(broke)) == "Test AI rate limit or quota reached")

        let limited = MockServer { _, _ in .json(429, #"{"error":{"message":"Rate limit reached for requests","type":"requests","code":"rate_limit_exceeded"}}"#) }
        let busy = await AIBackends(claude: limited.client(), local: limited.localClient())
            .send(request, to: .cloud(service: service(limited), model: "tess-1", apiKey: "sk-cloud"))
        #expect(busy == .failure(.busy), "a real rate limit is retried later")
    }

    @Test func cloudErrorsNameTheService() {
        let provider = AIProvider.cloud("openai")
        #expect(AIError.invalidAPIKey.userMessage(for: provider) == "Invalid OpenAI API key")
        #expect(AIError.busy.userMessage(for: provider) == "GPT is busy — try again shortly")
        #expect(AIError.timedOut.userMessage(for: provider) == "GPT took too long to respond")
        #expect(AIError.http(status: 402, message: "Insufficient Balance").userMessage(for: provider) == "Billing problem — check your OpenAI account")
        #expect(AIError.http(status: 403, message: nil).userMessage(for: provider) == "Your OpenAI key can't use this model")
        #expect(AIError.http(status: 404, message: nil).userMessage(for: provider) == "OpenAI doesn't have this model. Check the model in Settings → AI.")
        #expect(AIError.http(status: 429, message: nil).userMessage(for: provider) == "OpenAI rate limit or quota reached")
        #expect(AIError.http(status: 500, message: "boom").userMessage(for: provider) == "OpenAI error: boom")
        #expect(AIError.http(status: 500, message: " ").userMessage(for: provider) == "OpenAI request failed (HTTP 500)")
        #expect(AIError.serverUnreachable.userMessage(for: provider) == "Couldn't reach OpenAI")
        for service in CloudService.all {
            #expect(AIError.busy.userMessage(for: .cloud(service.id)) == AIError.busy.userMessage(forService: service), "\(service.id)")
        }
    }
}
