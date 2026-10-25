import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

@Suite struct UsageReportingTests {
    @Test func claudeUsageIsDecoded() throws {
        let usage = #""usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":300,"cache_read_input_tokens":4000}"#
        let body = #"{"content":[{"type":"text","text":"x"}],"stop_reason":"end_turn","model":"claude-sonnet-5-5","# + usage + "}"
        let response = try ClaudeClient.decodeMessage(Data(body.utf8)).get()
        #expect(response.usage == TokenUsage(input: 10, output: 20, cacheWrite: 300, cacheRead: 4000))
        let bare = try ClaudeClient.decodeMessage(Data(#"{"content":[]}"#.utf8)).get()
        #expect(bare.usage == nil)
    }

    @Test func theEngineReportsEveryResponseWithItsPurpose() async throws {
        let server = MockServer { _, request in
            let system = (request.json["system"] as? [[String: Any]])?.first?["text"] as? String ?? ""
            let text = system.contains("tone detector")
                ? #"{"tones":[],"sentiment":"neutral","summary":""}"#
                : "Rewritten."
            return .json(200, messageBody(text: text))
        }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        let events = OSAllocatedUnfairLock(initialState: [UsageEvent]())
        engine.setUsageHandler { event in events.withLock { $0.append(event) } }

        _ = try await engine.rewrite("Some text.", tone: .formal, settings: testSettings())
        _ = try await engine.detectTone("Some text with enough words in it.", settings: testSettings())
        let recorded = events.withLock { $0 }
        #expect(recorded.map(\.purpose) == [.rewrite, .tone])
        #expect(recorded.first == UsageEvent(provider: .claude, model: "claude-haiku-5-5", purpose: .rewrite, tokens: TokenUsage(input: 12, output: 34)))

        engine.setUsageHandler(nil)
        _ = try await engine.rewrite("Some text.", tone: .formal, settings: testSettings())
        #expect(events.withLock { $0 }.count == 2)
    }
}
