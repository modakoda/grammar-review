import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ClaudeClientTests {
    private let okBody = messageBody(text: #"{"edits":[]}"#)

    private func check(_ server: MockServer, model: String = "claude-haiku-5-5") async -> Result<MessageResponse, AIError> {
        await server.client().createMessage(CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: model), apiKey: "sk-test")
    }

    @Test func sendsTheRequiredHeaders() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: #"{"edits":[]}"#)) }
        _ = try await check(server).get()
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/messages")
        #expect(request.request.httpMethod == "POST")
        #expect(request.header("x-api-key") == "sk-test")
        #expect(request.header("anthropic-version") == "2026-10-21")
        #expect(request.header("content-type") == "application/json")
        #expect(request.header("anthropic-beta") == nil, "Haiku 5.5 has no server-side fallback")
        #expect(request.json["fallbacks"] == nil)
    }

    @Test func aRejectedKeyIsInvalid() async {
        let server = MockServer { _, _ in .json(401, #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#) }
        let result = await check(server)
        #expect(result == .failure(.invalidAPIKey))
        #expect(AIError.invalidAPIKey.userMessage(for: .claude) == "Invalid API key")
        #expect(server.requests.count == 1, "auth errors are not retried")
    }

    @Test func aPermissionErrorShowsAnthropicsMessage() async {
        let message = "Your organization must complete identity verification to use this model."
        let server = MockServer { _, _ in .json(403, #"{"type":"error","error":{"type":"permission_error","message":"\#(message)"}}"#) }
        let result = await check(server)
        #expect(result == .failure(.http(status: 403, message: message)))
        #expect(AIError.http(status: 403, message: message).userMessage(for: .claude) == "Claude error: \(message)")
        #expect(AIError.http(status: 403, message: nil).userMessage(for: .claude) == "Your API key isn't allowed to use this model")
        #expect(server.requests.count == 1, "permission errors are not retried")
    }

    @Test(arguments: [429, 529, 500, 503])
    func transientErrorsAreRetriedOnce(status: Int) async throws {
        let body = okBody
        let server = MockServer { attempt, _ in attempt == 1 ? .json(status, #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#) : .json(200, body) }
        _ = try await check(server).get()
        #expect(server.requests.count == 2)
    }

    @Test(arguments: [429, 529, 502])
    func persistentlyBusyMapsToBusy(status: Int) async {
        let server = MockServer { _, _ in .json(status, "{}", headers: ["retry-after": "0"]) }
        let result = await check(server)
        #expect(result == .failure(.busy))
        #expect(AIError.busy.userMessage(for: .claude) == "Claude is busy — try again shortly")
        #expect(server.requests.count == 2)
    }

    @Test func theMonthlySpendCapIsNotMistakenForARateLimit() async {
        let body = #"{"type":"error","error":{"type":"rate_limit_error","message":"You have reached your API usage limits: "# +
            #"your organization has crossed its monthly API usage threshold, set based on your organization's API tier. "# +
            #"You will regain access on 2026-11-01 at 00:00 UTC.","details":{"error_code":"enforced_spend_limit_reached"}},"# +
            #""request_id":"req_018EeWyXxfu5pfWkrYcMdjWG"}"#
        let server = MockServer { _, _ in .json(429, body) }
        guard case .failure(let error) = await check(server) else {
            Issue.record("expected failure")
            return
        }
        #expect(error.userMessage(for: .claude) == "Your Anthropic organization reached its monthly usage limit")
        #expect(server.requests.count == 1, "retrying fails until the next month")
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .cannotFindHost])
    func networkLossMeansOffline(code: URLError.Code) async {
        let server = MockServer { _, _ in .failure(code) }
        #expect(await check(server) == .failure(.offline))
        #expect(AIError.offline.userMessage(for: .claude) == "You're offline")
    }

    @Test func timeoutIsReported() async {
        let server = MockServer { _, _ in .failure(.timedOut) }
        #expect(await check(server) == .failure(.timedOut))
    }

    @Test func otherErrorsGetShortMessages() async {
        let server = MockServer { _, _ in .json(400, #"{"type":"error","error":{"type":"invalid_request_error","message":"Your credit balance is too low to access the Anthropic API."}}"#) }
        let result = await check(server)
        guard case .failure(let error) = result else {
            Issue.record("expected failure")
            return
        }
        #expect(error == .http(status: 400, message: "Your credit balance is too low to access the Anthropic API."))
        #expect(error.userMessage(for: .claude) == "Your Anthropic credit balance is too low")
        #expect(AIError.http(status: 404, message: nil).userMessage(for: .claude) == "This model isn't available for your API key")
        #expect(AIError.network("x").userMessage(for: .claude) == "Couldn't reach Claude")
        let ownLimit = "You have reached your specified workspace API usage limits. You will regain access on 2026-11-01 at 00:00 UTC."
        #expect(AIError.http(status: 400, message: ownLimit).userMessage(for: .claude) == "You've reached the spend limit set in the Claude Console")
        #expect(AIError.http(status: 400, message: "max_tokens: 200000 > 128000, the maximum for claude-haiku-5-5").userMessage(for: .claude)
            == "Claude error: max_tokens: 200000 > 128000, the maximum for claude-haiku-5-5")
        #expect(AIError.http(status: 418, message: nil).userMessage(for: .claude) == "Claude request failed (HTTP 418)")
    }

    @Test func sonnetAndOpusOptIntoServerSideFallbacks() async throws {
        let body = okBody
        let server = MockServer { _, _ in .json(200, body) }
        _ = try await check(server, model: "claude-sonnet-5-5").get()
        _ = try await check(server, model: "claude-opus-5-5").get()
        for request in server.requests {
            #expect(request.header("anthropic-beta") == ClaudeClient.fallbackBeta)
            #expect(request.json["fallbacks"] as? String == "default")
        }
    }

    @Test func rejectedFallbackBetaIsDroppedAndRetried() async throws {
        let body = okBody
        let server = MockServer { _, request in
            request.header("anthropic-beta") != nil
                ? .json(400, #"{"type":"error","error":{"type":"invalid_request_error","message":"Unexpected value(s) `server-side-fallback-2026-07-01` for the `anthropic-beta` header."}}"#)
                : .json(200, body)
        }
        let client = server.client()
        let request = CheckPrompt.request(paragraph: "Hello there.", language: "en", model: "claude-sonnet-5-5")
        _ = try await client.createMessage(request, apiKey: "sk-test").get()
        _ = try await client.createMessage(request, apiKey: "sk-test").get()
        #expect(server.requests.map { $0.header("anthropic-beta") != nil } == [true, false, false])
        #expect(server.requests.last?.json["fallbacks"] == nil)
    }

    @Test func countTokensValidatesKeys() async throws {
        let server = MockServer { _, request in
            request.header("x-api-key") == "good" ? .json(200, #"{"input_tokens":8}"#) : .json(401, #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#)
        }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        try await engine.validateAPIKey("good", model: "claude-haiku-5-5")
        await #expect(throws: RewriteError.invalidAPIKey) {
            try await engine.validateAPIKey("bad", model: "claude-haiku-5-5")
        }
        await #expect(throws: RewriteError.missingAPIKey) {
            try await engine.validateAPIKey("  ", model: "claude-haiku-5-5")
        }
        #expect(server.requests.allSatisfy { $0.path == "/v1/messages/count_tokens" })
        #expect(server.requests.first?.json["model"] as? String == "claude-haiku-5-5")
    }

    @Test func aKeyForEveryWorkspaceIsExplainedWhenAdded() async {
        let server = MockServer { _, _ in
            .json(400, #"{"type":"error","error":{"type":"invalid_request_error","message":"This API key is not scoped to a workspace, "# +
                #"so this request must include the anthropic-workspace-id header with the ID of the workspace to use. "# +
                #"Add the header, or use an API key that is scoped to a workspace."}}"#)
        }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("This API key isn't scoped to a workspace. Create one for a single workspace.")) {
            try await engine.validateAPIKey("sk-ant-api03-unscoped", model: "claude-haiku-5-5")
        }
    }
}
