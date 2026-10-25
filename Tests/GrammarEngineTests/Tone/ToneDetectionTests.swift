import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ToneDetectionTests {
    static let report = #"{"tones":[{"tone":"friendly","intensity":"moderate"},{"tone":"confident","intensity":"strong"}],"sentiment":"positive","summary":"Warm and sure of itself."}"#

    @Test func detectsToneThroughTheMessagesAPI() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: Self.report)) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        let report = try await engine.detectTone("  Thanks so much, we'll ship it Friday!  ", settings: testSettings())

        #expect(report.tones == [ToneScore(tone: .confident, intensity: .strong), ToneScore(tone: .friendly, intensity: .moderate)])
        #expect(report.sentiment == .positive)
        #expect(report.summary == "Warm and sure of itself.")
        let body = try #require(server.requests.first?.json)
        let content = (body["messages"] as? [[String: Any]])?.first?["content"] as? String ?? ""
        #expect(content.hasSuffix("<text>\nThanks so much, we'll ship it Friday!\n</text>"))
        let format = try #require((body["output_config"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
    }

    @Test func toneErrorsMatchRewriteErrors() async {
        let server = MockServer { _, _ in .json(401, "{}") }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-bad" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.invalidAPIKey) {
            try await engine.detectTone("Some text", settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("Write some text first")) {
            try await engine.detectTone(" \n ", settings: testSettings())
        }
        await #expect(throws: RewriteError.failed("AI is turned off in Settings")) {
            try await engine.detectTone("Some text", settings: testSettings { $0.aiEnabled = false })
        }
        let noKey = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.missingAPIKey) {
            try await noKey.detectTone("Some text", settings: testSettings())
        }
        #expect(server.requests.count == 1)
    }

    @Test func parserSortsDedupesCapsAndTolerates() throws {
        let text = """
        Sure: {"tones":[{"tone":"Neutral","intensity":"slight"},{"tone":"bogus","intensity":"strong"},
        {"tone":"direct","intensity":"strong"},{"tone":"direct","intensity":"slight"},
        {"tone":"curious"},{"tone":"urgent","intensity":"strong"}],"sentiment":"mixed"}
        """
        let report = try #require(TonePrompt.parseReport(text))
        #expect(report.tones.map(\.tone) == [.direct, .urgent, .curious])
        #expect(report.tones[2].intensity == .moderate, "a missing intensity counts as moderate")
        #expect(report.sentiment == .neutral)
        #expect(report.summary.isEmpty)
        #expect(TonePrompt.parseReport("no json") == nil)
        #expect(TonePrompt.parse(MessageResponse(text: "", stopReason: "refusal", model: nil)) == .failure(.refused))
        #expect(TonePrompt.parse(MessageResponse(text: "{\"tones\":[", stopReason: "max_tokens", model: nil)) == .failure(.truncated))
    }

    @Test func longTextsAreCutAtAWordBoundary() {
        let text = String(repeating: "abcde ", count: 2_000)
        let sample = TonePrompt.sample(text)
        #expect((sample as NSString).length <= TonePrompt.maxCharacters)
        #expect(sample.hasSuffix("abcde"))
        #expect(TonePrompt.sample("  short  ") == "short")
    }

    @Test func schemaListsEveryTone() throws {
        let schema = try #require(try JSONSerialization.jsonObject(with: TonePrompt.schema.data) as? [String: Any])
        let tones = (schema["properties"] as? [String: Any])?["tones"] as? [String: Any]
        let item = (tones?["items"] as? [String: Any])?["properties"] as? [String: Any]
        let names = (item?["tone"] as? [String: Any])?["enum"] as? [String]
        #expect(names == DetectedTone.allCases.map(\.rawValue))
        #expect(Set(DetectedTone.allCases.map(\.emoji)).count == DetectedTone.allCases.count)
    }
}
