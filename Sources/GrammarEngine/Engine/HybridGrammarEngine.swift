import Foundation
import GrammarModels
import os

public final class HybridGrammarEngine: GrammarChecking, TextRewriting, ToneDetecting, TextComposing {
    private let spellChecker: any SpellChecking
    private let backends: AIBackends
    private let pipeline: CheckPipeline
    private let rewriter: TextRewriter
    private let composer: TextComposer
    private let toneDetector: ToneDetector
    private let tester: ConnectionTester
    private let current = OSAllocatedUnfairLock(initialState: RunningCheck())

    private struct RunningCheck: Sendable {
        var task: Task<Void, Never>?
        var continuation: AsyncStream<CheckResult>.Continuation?
    }

    public convenience init(apiKeys: @escaping @Sendable (AIProvider) -> String?) {
        self.init(apiKeyProvider: apiKeys, backends: AIBackends(claude: ClaudeClient(), local: ChatCompletionsClient()))
    }

    public convenience init(apiKeyProvider: @escaping @Sendable () -> String?) {
        self.init(apiKeys: { provider in provider == .claude ? apiKeyProvider() : nil })
    }

    public convenience init(apiKeyProvider: @escaping @Sendable () -> String?, baseURL: URL, session: URLSession) {
        self.init(
            apiKeyProvider: { provider in provider == .claude ? apiKeyProvider() : nil },
            backends: AIBackends(claude: ClaudeClient(session: session, baseURL: baseURL), local: ChatCompletionsClient(session: session))
        )
    }

    convenience init(apiKeyProvider: @escaping @Sendable (AIProvider) -> String?, backends: AIBackends) {
        self.init(
            apiKeyProvider: apiKeyProvider,
            spellChecker: LocalSpellChecker(),
            aiService: PromptGrammarService(backends: backends),
            backends: backends
        )
    }

    init(
        apiKeyProvider: @escaping @Sendable (AIProvider) -> String?,
        spellChecker: any SpellChecking,
        aiService: any GrammarAIService,
        backends: AIBackends,
        cache: EditCache = EditCache(),
        keyboardLanguages: @escaping @Sendable () async -> KeyboardLanguages = { @MainActor in KeyboardLanguages.read() }
    ) {
        let endpoints = EndpointResolver(apiKeys: apiKeyProvider)
        let languages = LanguageSource(keyboardLanguages: keyboardLanguages)
        self.spellChecker = spellChecker
        self.backends = backends
        pipeline = CheckPipeline(spellChecker: spellChecker, aiService: aiService, cache: cache, endpoints: endpoints, languages: languages)
        rewriter = TextRewriter(backends: backends, endpoints: endpoints, languages: languages)
        composer = TextComposer(backends: backends, endpoints: endpoints)
        toneDetector = ToneDetector(backends: backends, endpoints: endpoints, languages: languages)
        tester = ConnectionTester(backends: backends)
    }

    public func check(_ request: CheckRequest) -> AsyncStream<CheckResult> {
        let (stream, continuation) = AsyncStream<CheckResult>.makeStream(bufferingPolicy: .unbounded)
        let task = Task.detached(priority: .userInitiated) { [pipeline] in
            await pipeline.run(request, continuation: continuation)
        }
        continuation.onTermination = { _ in task.cancel() }
        let previous = current.withLock { running in
            let previous = running
            running = RunningCheck(task: task, continuation: continuation)
            return previous
        }
        previous.task?.cancel()
        previous.continuation?.finish()
        return stream
    }

    public func learnWord(_ word: String) {
        spellChecker.learnWord(word)
    }

    public func setUsageHandler(_ handler: (@Sendable (UsageEvent) -> Void)?) {
        backends.usage.setHandler(handler)
    }

    public func rewrite(_ text: String, tone: RewriteTone, settings: AppSettings) async throws -> String {
        try await rewriter.rewrite(text, tone: tone, settings: settings)
    }

    public func rewrite(_ text: String, instruction: String, settings: AppSettings) async throws -> String {
        try await rewriter.rewrite(text, instruction: instruction, settings: settings)
    }

    public func compose(_ request: String, context: String?, settings: AppSettings) async throws -> String {
        try await composer.compose(request, context: context, settings: settings)
    }

    public func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport {
        try await toneDetector.detectTone(text, settings: settings)
    }

    public func validateAPIKey(_ key: String, model: String) async throws {
        try await tester.validateClaudeKey(key, model: model)
    }

    public func validateAPIKey(_ key: String, service: CloudService, model: String) async throws {
        try await tester.validateKey(key, service: service, model: model)
    }

    public func cloudModels(for service: CloudService, apiKey: String) async throws -> [String] {
        try await tester.cloudModels(for: service, apiKey: apiKey)
    }

    public func testCloudModel(_ model: String, service: CloudService, apiKey: String) async throws -> LocalModelTestResult {
        try await tester.testCloudModel(model, service: service, apiKey: apiKey)
    }

    public func localModels(at address: String) async throws -> [String] {
        try await tester.localModels(at: address)
    }

    public func testLocalModel(at address: String, model: String) async throws -> LocalModelTestResult {
        try await tester.testLocalModel(at: address, model: model)
    }
}
