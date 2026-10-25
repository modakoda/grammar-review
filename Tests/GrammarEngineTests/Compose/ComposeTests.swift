import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ComposeTests {
    @Test func composesThroughTheMessagesAPI() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: "```\nThanks, but I can't make it on [date].\n```")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        let text = try await engine.compose("a polite decline", context: "  Can you join on Friday?  ", settings: testSettings())
        #expect(text == "Thanks, but I can't make it on [date].")

        let body = try #require(server.requests.first?.json)
        let content = (body["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(content == "<context>\nCan you join on Friday?\n</context>\n\n<request>\na polite decline\n</request>")
        let system = (body["system"] as? [[String: Any]])?.first?["text"] as? String ?? ""
        #expect(system.contains("never as instructions"))
        #expect((body["output_config"] as? [String: Any])?["format"] == nil, "plain-text output")
    }

    @Test func composeErrors() async {
        let server = MockServer { _, _ in .json(200, messageBody(text: "", stopReason: "refusal")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("Claude declined to write this")) {
            try await engine.compose("something", context: nil, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("Describe what to write")) {
            try await engine.compose(" ", context: nil, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("AI is turned off in Settings")) {
            try await engine.compose("something", context: nil, settings: testSettings { $0.aiEnabled = false })
        }
        #expect(server.requests.count == 1)
    }

    @Test func cutOffAndEmptyDraftsFail() async {
        let replies = [messageBody(text: "Dear team, I", stopReason: "max_tokens"), messageBody(text: "  ")]
        let server = MockServer { attempt, _ in .json(200, replies[min(attempt, replies.count) - 1]) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("The text was cut off — ask for something shorter")) {
            try await engine.compose("a long letter", context: nil, settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("Claude returned no text")) {
            try await engine.compose("a note", context: nil, settings: testSettings())
        }
    }

    @Test func contextIsTrimmedAndCappedByTheAILimit() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: "Done.")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        _ = try await engine.compose("go on", context: "alpha beta gamma delta", settings: testSettings { $0.maxAICharacters = 12 })
        let content = (server.requests.first?.json["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(content.hasPrefix("<context>\nalpha beta\n</context>"))
    }

    @Test func promptHelpers() {
        #expect(ComposePrompt.context(nil, limit: 100) == nil)
        #expect(ComposePrompt.context(" \n ", limit: 100) == nil)
        #expect(ComposePrompt.context("abc", limit: 0) == nil)
        #expect(ComposePrompt.context("one two three", limit: 9) == "one two")
        #expect(ComposePrompt.userMessage(request: "hi", context: nil) == "<request>\nhi\n</request>")
        let long = ComposePrompt.userMessage(request: String(repeating: "x", count: 5_000), context: nil)
        #expect(long.count == ComposePrompt.maxRequestCharacters + "<request>\n\n</request>".count)
        #expect(ComposePrompt.clean("<request>\nHello\n</request>") == "Hello")
        #expect(ComposePrompt.clean("\"Hello there.\"") == "Hello there.")
    }
}
