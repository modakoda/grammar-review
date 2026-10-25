import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct RewriteTests {
    @Test func rewritesThroughTheMessagesAPI() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: "\"I have a cat.\"")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        let result = try await engine.rewrite("i has a cat ", tone: .formal, settings: testSettings())
        #expect(result == "I have a cat. ")
        let body = try #require(server.requests.first?.json)
        #expect(body["temperature"] == nil)
        #expect((body["output_config"] as? [String: Any])?["format"] == nil, "plain-text output")
        let system = (body["system"] as? [[String: Any]])?.first?["text"] as? String ?? ""
        #expect(system.contains(RewritePrompt.instruction(for: .formal)))
        let content = (body["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(content.hasSuffix("<text>\ni has a cat\n</text>"))
    }

    @Test func rewriteErrors() async {
        let server = MockServer { _, _ in .json(401, "{}") }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-bad" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.invalidAPIKey) {
            try await engine.rewrite("Some text", tone: .improve, settings: testSettings())
        }
        await #expect(throws: RewriteError.textTooLong) {
            try await engine.rewrite(String(repeating: "a", count: 8_001), tone: .improve, settings: testSettings())
        }
        let noKey = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.missingAPIKey) {
            try await noKey.rewrite("Some text", tone: .improve, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("AI is turned off in Settings")) {
            try await engine.rewrite("Some text", tone: .improve, settings: testSettings { $0.aiEnabled = false })
        }
        #expect(server.requests.count == 1, "only the 401 call reached the network")
    }

    @Test func refusedRewriteFails() async {
        let server = MockServer { _, _ in .json(200, messageBody(text: "", stopReason: "refusal")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("Claude declined to rewrite this text")) {
            try await engine.rewrite("Some text", tone: .concise, settings: testSettings())
        }
    }

    @Test func blankCutOffAndEmptyRewritesFail() async {
        let replies = [messageBody(text: "I have a", stopReason: "max_tokens"), messageBody(text: " \n ")]
        let server = MockServer { attempt, _ in .json(200, replies[min(attempt, replies.count) - 1]) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("Select some text to rewrite")) {
            try await engine.rewrite(" \n", tone: .improve, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("The rewrite was cut off — try a shorter selection")) {
            try await engine.rewrite("I has a cat.", tone: .improve, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("Claude returned an empty rewrite")) {
            try await engine.rewrite("I has a cat.", tone: .improve, settings: testSettings())
        }
        #expect(server.requests.count == 2, "a blank selection isn't sent")
    }
}
