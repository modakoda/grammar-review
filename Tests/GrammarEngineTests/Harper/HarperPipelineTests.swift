import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite(.timeLimit(.minutes(1))) struct HarperPipelineTests {
    @Test func harperIssuesArriveWithTheLocalPassAndAIWinsOverlaps() async {
        let harper = MockHarperLinter { text in
            [harperLint(text, "an", ["a"], message: "Incorrect indefinite article."), harperLint(text, "teh", ["the"]), harperLint(text, "is", ["are"])]
        }
        let ai = MockAIService { _ in .success([edit("is", "are", before: "They ")]) }
        let engine = makeEngine(ai: ai, harper: harper)
        let text = "They is an teh test."
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))

        #expect(results.map(\.aiStatus) == [.pending, .completed])
        #expect(results[0].issues.map(\.originalText) == ["is", "an", "teh"])
        #expect(results[0].issues.map(\.source) == [.local, .local, .local])
        #expect(results[0].issues.map(\.category) == [.grammar, .grammar, .spelling])
        #expect(results[1].issues.map { "\($0.originalText):\($0.source)" } == ["is:ai", "an:local", "teh:local"])
        #expect(harper.received.map(\.text) == [text])
    }

    @Test func harperRunsWithAIOff() async {
        let harper = MockHarperLinter { text in [harperLint(text, "an", ["a"])] }
        let engine = makeEngine(harper: harper)
        let results = await collect(engine.check(CheckRequest(text: "This is an test.", bundleID: nil, settings: testSettings { $0.aiEnabled = false })))
        #expect(results.map(\.aiStatus) == [.disabled])
        #expect(results[0].issues.map(\.replacements) == [["a"]])
    }
}
