import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite(.timeLimit(.minutes(1))) struct EngineStreamTests {
    static let grammarEdits: @Sendable (String) async -> Result<[AIEdit], AIError> = { paragraph in
        var edits: [AIEdit] = []
        if paragraph.contains("has") { edits.append(edit("has", "have", before: "I ")) }
        if paragraph.contains("teh") { edits.append(edit("teh", "the", before: "has ", .spelling)) }
        return .success(edits)
    }

    @Test func yieldsLocalFirstThenTheMergedFinalResult() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let text = "I has teh cat."
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))

        #expect(results.map(\.aiStatus) == [.pending, .completed])
        #expect(results.allSatisfy { $0.text == text && $0.language == "en" })
        let local = results[0].issues
        #expect(local.map(\.source) == [.local])
        #expect(local.map(\.originalText) == ["teh"])

        let final = results[1].issues
        #expect(final.map(\.originalText) == ["has", "teh"])
        #expect(final.map(\.source) == [.ai, .ai])
        #expect(final[1].replacements == ["the", "tech"])
        #expect(ai.calls == [text])
    }

    @Test func multiParagraphIssuesAreOffsetIntoTheFullText() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai, spell: MockSpellChecker(words: [:]))
        let text = "First line is fine.\n\n😀 And I has a cat."
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        let final = results.last
        #expect(final?.aiStatus == .completed)
        let has = final?.issues.first
        #expect(has.map { substring(text, $0.range) } == "has")
        #expect(has?.range.location == 30)
        #expect(Set(ai.calls) == ["First line is fine.", "😀 And I has a cat."])
    }

    @Test func secondCheckCancelsTheFirst() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let slow = testSettings(aiDelay: 30)
        let first = engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: slow))
        var iterator = first.makeAsyncIterator()
        let firstLocal = await iterator.next()
        #expect(firstLocal?.aiStatus == .pending)

        let second = engine.check(CheckRequest(text: "I has a dog.", bundleID: nil, settings: testSettings()))
        let afterCancel = await iterator.next()
        #expect(afterCancel == nil)

        let results = await collect(second)
        #expect(results.map(\.aiStatus) == [.pending, .completed])
        #expect(results.last?.issues.map(\.originalText) == ["has"])
        #expect(ai.calls == ["I has a dog."], "the cancelled check never reached Claude")
    }

    @Test func cancellingDuringTheRequestYieldsNothingMore() async {
        let ai = MockAIService { _ in
            try? await Task.sleep(for: .seconds(30))
            return .failure(.cancelled)
        }
        let engine = makeEngine(ai: ai)
        let first = engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: testSettings()))
        var iterator = first.makeAsyncIterator()
        _ = await iterator.next()
        while ai.calls.isEmpty { await Task.yield() }
        _ = engine.check(CheckRequest(text: "Ok", bundleID: nil, settings: testSettings()))
        let afterCancel = await iterator.next()
        #expect(afterCancel == nil)
    }

    @Test func cacheHitSkipsTheNetworkAndTheDelay() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let text = "I has teh cat."
        let first = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        #expect(ai.calls.count == 1)

        let clock = ContinuousClock()
        let start = clock.now
        let second = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings(aiDelay: 20))))
        #expect(clock.now - start < .seconds(5), "fully cached text skips the typing delay")
        #expect(ai.calls.count == 1, "cache hit: no new request")
        #expect(second.map(\.aiStatus) == [.pending, .completed])
        #expect(second.last?.issues.map(\.range) == first.last?.issues.map(\.range))
    }

    @Test func onlyEditedParagraphsAreResent() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        _ = await collect(engine.check(CheckRequest(text: "First paragraph.\nSecond paragraph.", bundleID: nil, settings: testSettings())))
        _ = await collect(engine.check(CheckRequest(text: "First paragraph.\nSecond paragraph, edited.", bundleID: nil, settings: testSettings())))
        #expect(ai.calls.sorted() == ["First paragraph.", "Second paragraph, edited.", "Second paragraph."])
    }

    @Test func cacheKeyIncludesTheModel() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let text = "I has a cat."
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings { $0.aiModel = "claude-opus-5-5" })))
        #expect(ai.calls.count == 2)
    }

    @Test func goalsReachTheAIAndKeyTheCache() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let text = "I has a cat."
        let formal = WritingGoals(style: .formal)
        let expert = WritingGoals(style: .formal, audience: .expert)
        for goals in [WritingGoals.none, formal, formal, expert] {
            _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings(), goals: goals)))
        }
        #expect(ai.goals == [.none, formal, expert], "each set of goals is fetched once, then cached")
    }

    @Test func atMostThreeRequestsInFlight() async {
        let ai = MockAIService { _ in
            try? await Task.sleep(for: .milliseconds(50))
            return .success([])
        }
        let engine = makeEngine(ai: ai)
        let text = (1...7).map { "This is paragraph number \($0)." }.joined(separator: "\n")
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        #expect(results.last?.aiStatus == .completed)
        #expect(ai.calls.count == 7)
        #expect(ai.maxInFlight <= 3)
        #expect(ai.maxInFlight >= 2)
    }

    @Test func partialFailureKeepsSuccessfulParagraphs() async {
        let ai = MockAIService { paragraph in
            paragraph.hasPrefix("Broken") ? .failure(.busy) : await Self.grammarEdits(paragraph)
        }
        let engine = makeEngine(ai: ai, spell: MockSpellChecker(words: [:]))
        let text = "I has a cat.\nBroken paragraph here."
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        #expect(results.last?.aiStatus == .failed("Claude is busy — try again shortly"))
        #expect(results.last?.issues.map(\.originalText) == ["has"])
        #expect(results.last?.isFinal == true)

        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        #expect(ai.calls.filter { $0.hasPrefix("Broken") }.count == 2)
        #expect(ai.calls.filter { $0.hasPrefix("I has") }.count == 1)
    }

    @Test func invalidKeyStopsTheBatchEarly() async {
        let ai = MockAIService { _ in .failure(.invalidAPIKey) }
        let engine = makeEngine(ai: ai)
        let text = (1...9).map { "Paragraph number \($0) is here." }.joined(separator: "\n")
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        #expect(results.last?.aiStatus == .failed("Invalid API key"))
        #expect(ai.calls.count <= 3)
    }

    @Test func missingKeyIsFinalAfterTheLocalPass() async {
        for key in [nil, "", "  "] as [String?] {
            let ai = MockAIService()
            let results = await collect(makeEngine(ai: ai, key: key).check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: testSettings())))
            #expect(results.map(\.aiStatus) == [.missingAPIKey])
            #expect(results.first?.issues.map(\.originalText) == ["teh"])
            #expect(ai.calls.isEmpty)
        }
    }

    @Test func aiDisabledAndTooLongAreFinal() async {
        let ai = MockAIService()
        let engine = makeEngine(ai: ai)
        let disabled = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: testSettings { $0.aiEnabled = false })))
        #expect(disabled.map(\.aiStatus) == [.disabled])
        let long = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: testSettings { $0.maxAICharacters = 10 })))
        #expect(long.map(\.aiStatus) == [.textTooLong])
        #expect(long.first?.issues.count == 1)
        #expect(ai.calls.isEmpty)
    }

    @Test func nothingWorthSendingCompletesImmediately() async {
        let ai = MockAIService()
        let results = await collect(makeEngine(ai: ai).check(CheckRequest(text: "Ok\n\n👍", bundleID: nil, settings: testSettings())))
        #expect(results.map(\.aiStatus) == [.completed])
        #expect(ai.calls.isEmpty)
    }

    @Test func categoriesAndPersonalDictionaryApplyToBothPasses() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let settings = testSettings {
            $0.enabledCategories = [.grammar, .spelling]
            $0.personalDictionary = ["TEH"]
        }
        let results = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: settings)))
        #expect(results.first?.issues.isEmpty == true)
        #expect(results.last?.issues.map(\.originalText) == ["has"])
    }

    @MainActor
    @Test func apiKeyProviderRunsOffTheMainThread() async {
        let flag = Flag()
        let engine = makeEngine(ai: MockAIService(), keyCalledOnMain: flag)
        _ = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: testSettings())))
        #expect(flag.get == false)
    }

    @Test func endToEndThroughTheHTTPClient() async {
        let body = messageBody(text: editsJSON([edit("has", "have", before: "I ", .grammar, "Use “have” with “I”.")]))
        let server = MockServer { _, _ in .json(200, body) }
        let backends = AIBackends(claude: server.client(), local: server.localClient())
        let engine = HybridGrammarEngine(
            apiKeyProvider: { _ in "sk-test" },
            spellChecker: MockSpellChecker(words: [:]),
            aiService: PromptGrammarService(backends: backends),
            backends: backends
        )
        let text = "Hi.\nI has a cat 🐈 today."
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: "com.apple.TextEdit", settings: testSettings())))
        #expect(results.last?.aiStatus == .completed)
        let issue = results.last?.issues.first
        #expect(issue.map { substring(text, $0.range) } == "has")
        #expect(issue?.range.location == 6)
        #expect(issue?.message == "Use “have” with “I”.")
        #expect(server.requests.count == 1)
    }

    static func localSettings(model: String = "qwen3-30b-a3b", address: String = "localhost:1234") -> AppSettings {
        testSettings {
            $0.aiProvider = .local
            $0.localServerURL = address
            $0.localModel = model
        }
    }

    @Test func localProviderNeedsNoAPIKey() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let flag = Flag()
        let engine = makeEngine(ai: ai, key: nil, keyCalledOnMain: flag)
        let results = await collect(engine.check(CheckRequest(text: "I has a cat.", bundleID: nil, settings: Self.localSettings())))
        #expect(results.last?.aiStatus == .completed)
        #expect(results.last?.issues.map(\.originalText) == ["has"])
        #expect(ai.endpoints == [.local(baseURL: URL(string: "http://localhost:1234/v1")!, model: "qwen3-30b-a3b")])
        #expect(flag.get == nil, "the Keychain is not read for the local provider")
    }

    @Test func unconfiguredLocalProviderIsFinalAfterTheLocalPass() async {
        let ai = MockAIService()
        let engine = makeEngine(ai: ai)
        let noModel = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: Self.localSettings(model: " "))))
        #expect(noModel.map(\.aiStatus) == [.failed("Choose a local model in Settings → AI")])
        #expect(noModel.first?.issues.map(\.originalText) == ["teh"])
        let noAddress = await collect(engine.check(CheckRequest(text: "I has teh cat.", bundleID: nil, settings: Self.localSettings(address: ""))))
        #expect(noAddress.map(\.aiStatus) == [.failed(EndpointResolver.invalidAddressMessage)])
        #expect(ai.calls.isEmpty)
    }

    @Test func localFailuresUseLocalWording() async {
        let ai = MockAIService { _ in .failure(.serverUnreachable) }
        let engine = makeEngine(ai: ai)
        let text = (1...6).map { "Paragraph number \($0) is here." }.joined(separator: "\n")
        let results = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: Self.localSettings())))
        #expect(results.last?.aiStatus == .failed("Can't reach the local AI server. Is it running?"))
        #expect(ai.calls.count <= 3, "an unreachable server stops the batch")
    }

    @Test func switchingProviderDoesNotReuseCachedEdits() async {
        let ai = MockAIService(handler: Self.grammarEdits)
        let engine = makeEngine(ai: ai)
        let text = "I has a cat."
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: testSettings())))
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: Self.localSettings())))
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: Self.localSettings(address: "http://localhost:11434/v1"))))
        _ = await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: Self.localSettings())))
        #expect(ai.calls.count == 3)
    }

    @Test func localEndToEndThroughTheHTTPClient() async throws {
        let body = completionBody(content: "<think>The verb is wrong.</think>" + editsJSON([edit("has", "have", before: "I ")]))
        let server = MockServer { _, _ in .json(200, body) }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        let settings = Self.localSettings(address: "https://\(server.host)")
        let results = await collect(engine.check(CheckRequest(text: "I has a cat today.", bundleID: nil, settings: settings)))
        #expect(results.last?.aiStatus == .completed)
        #expect(results.last?.issues.contains { $0.originalText == "has" && $0.source == .ai } == true)
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.json["model"] as? String == "qwen3-30b-a3b")
    }

    @Test func localRewrite() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: "I have a cat.")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        let settings = Self.localSettings(address: "https://\(server.host)/v1")
        let rewritten = try await engine.rewrite("I has a cat.", tone: .improve, settings: settings)
        #expect(rewritten == "I have a cat.")
        let request = try #require(server.requests.first)
        #expect(request.json["response_format"] == nil, "rewrites are plain text")

        let unconfigured = Self.localSettings(model: "")
        await #expect(throws: RewriteError.failed("Choose a local model in Settings → AI")) {
            try await engine.rewrite("I has a cat.", tone: .improve, settings: unconfigured)
        }
    }

    @Test func localRewriteFailuresNameTheLocalModel() async {
        let server = MockServer { _, _ in .json(200, completionBody(content: "  ")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("The local model returned an empty rewrite")) {
            try await engine.rewrite("I has a cat.", tone: .improve, settings: Self.localSettings(address: "https://\(server.host)/v1"))
        }
    }

    @Test func testingALocalModelProofreadsASampleSentence() async throws {
        let edits = [edit("go", "goes", before: "She "), edit("days", "day", before: "every ")]
        let server = MockServer { _, request in
            request.path.hasSuffix("/models")
                ? .json(200, #"{"object":"list","data":[{"id":"qwen3-30b-a3b"},{"id":"text-embedding-nomic-embed-text-v1.5"},{"id":"gemma-3-27b"}]}"#)
                : .json(200, completionBody(content: editsJSON(edits)))
        }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        let address = "https://\(server.host)"

        #expect(try await engine.localModels(at: address) == ["gemma-3-27b", "qwen3-30b-a3b"])
        let result = try await engine.testLocalModel(at: address, model: "gemma-3-27b")
        #expect(result.suggestionCount == 2)
        let request = try #require(server.requests.last)
        #expect(request.path == "/v1/chat/completions")
        #expect(String(data: request.body, encoding: .utf8)?.contains("She go to school every days.") == true)

        await #expect(throws: RewriteError.failed(EndpointResolver.invalidAddressMessage)) {
            try await engine.localModels(at: "ftp://example.com")
        }
    }

    @Test func testingALocalModelReportsUnusableAnswers() async {
        let server = MockServer { _, _ in .json(200, completionBody(content: "Sure! The sentence has two mistakes.")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { nil }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("The local model's answer wasn't in the expected format")) {
            try await engine.testLocalModel(at: "https://\(server.host)", model: "tiny")
        }
    }
}
