import Foundation
import GrammarModels

struct CheckPipeline: Sendable {
    static let maxConcurrentRequests = 3

    let spellChecker: any SpellChecking
    let aiService: any GrammarAIService
    let cache: EditCache
    let endpoints: EndpointResolver
    let languages: LanguageSource

    func run(_ request: CheckRequest, continuation: AsyncStream<CheckResult>.Continuation) async {
        defer { continuation.finish() }
        let text = request.text
        let settings = request.settings
        let resolver = await languages.resolver(for: settings)
        let language = resolver.language(of: text)
        let wantsAI = settings.aiEnabled && text.utf16.count <= settings.maxAICharacters

        async let endpointLookup: Result<AIEndpoint, AISetupProblem>? = wantsAI ? endpoints.resolve(settings) : nil
        let local = await localIssues(in: text, language: language, resolver: resolver, settings: settings)
        let resolved = await endpointLookup
        guard !Task.isCancelled else { return }

        let plan = Self.aiPlan(for: text, settings: settings, endpoint: resolved)
        continuation.yield(CheckResult(
            text: text,
            issues: IssueMerger.merge(local: local, ai: [], settings: settings),
            language: language,
            aiStatus: plan.status
        ))
        guard plan.status == .pending, case .success(let endpoint)? = resolved else { return }

        guard let ai = await aiIssues(in: plan.paragraphs, request: request, language: language, resolver: resolver, endpoint: endpoint) else { return }
        continuation.yield(CheckResult(
            text: text,
            issues: IssueMerger.merge(local: local, ai: ai.issues, settings: settings),
            language: language,
            aiStatus: ai.status
        ))
    }

    private func localIssues(in text: String, language: String?, resolver: LanguageResolver, settings: AppSettings) async -> [TextIssue] {
        await spellChecker.misspellings(in: text, language: language, resolver: resolver, settings: settings)
            + ConsistencyChecker.issues(in: text, language: language)
            + StyleGuideChecker.issues(in: text, rules: settings.styleGuide)
    }

    private static func aiPlan(
        for text: String,
        settings: AppSettings,
        endpoint: Result<AIEndpoint, AISetupProblem>?
    ) -> (paragraphs: [Paragraph], status: AIStatus) {
        if !settings.aiEnabled { return ([], .disabled) }
        if text.utf16.count > settings.maxAICharacters { return ([], .textTooLong) }
        if case .failure(let problem)? = endpoint { return ([], problem.status) }
        let paragraphs = ParagraphSplitter.split(text).filter(ParagraphSplitter.isWorthChecking)
        return (paragraphs, paragraphs.isEmpty ? .completed : .pending)
    }

    private func aiIssues(
        in paragraphs: [Paragraph],
        request: CheckRequest,
        language: String?,
        resolver: LanguageResolver,
        endpoint: AIEndpoint
    ) async -> (issues: [TextIssue], status: AIStatus)? {
        let keys = paragraphs.map { paragraph in
            EditCache.Key(
                model: endpoint.cacheID,
                language: resolver.language(ofParagraph: paragraph.text, overall: language),
                goals: request.goals,
                text: paragraph.text
            )
        }
        var edits = await cache.values(for: keys)
        let missing = edits.indices.filter { edits[$0] == nil }
        Log.engine.debug("Check: \(paragraphs.count, privacy: .public) paragraphs, \(missing.count, privacy: .public) uncached")

        if !missing.isEmpty, request.settings.aiDelay > 0 {
            do { try await Task.sleep(for: .seconds(request.settings.aiDelay)) } catch { return nil }
        }
        guard !Task.isCancelled else { return nil }

        let jobs = missing.map { (index: $0, paragraph: paragraphs[$0], key: keys[$0]) }
        let failures = await fetchUncached(jobs, into: &edits, goals: request.goals, endpoint: endpoint)
        guard !Task.isCancelled else { return nil }

        let issues = paragraphs.indices.flatMap { index in
            EditLocator.issues(from: edits[index] ?? [], paragraphLocation: paragraphs[index].location)
        }
        guard let worst = failures.max(by: { $0.displayPriority < $1.displayPriority }) else {
            return (issues, .completed)
        }
        guard worst != .cancelled else { return nil }
        return (issues, .failed(worst.userMessage(for: endpoint.provider)))
    }

    private func fetchUncached(
        _ jobs: [(index: Int, paragraph: Paragraph, key: EditCache.Key)],
        into edits: inout [[LocatedEdit]?],
        goals: WritingGoals,
        endpoint: AIEndpoint
    ) async -> [AIError] {
        guard !jobs.isEmpty else { return [] }
        let results = await fetch(jobs.map { ($0.index, $0.paragraph, $0.key.language) }, goals: goals, endpoint: endpoint)
        var failures: [AIError] = []
        for job in jobs {
            switch results[job.index] ?? .failure(.cancelled) {
            case .success(let located):
                edits[job.index] = located
                await cache.insert(located, for: job.key)
            case .failure(let error):
                failures.append(error)
            }
        }
        return failures
    }

    private func fetch(
        _ jobs: [(index: Int, paragraph: Paragraph, language: String)],
        goals: WritingGoals,
        endpoint: AIEndpoint
    ) async -> [Int: Result<[LocatedEdit], AIError>] {
        let service = aiService
        return await withTaskGroup(of: (Int, Result<[LocatedEdit], AIError>).self) { group in
            var results: [Int: Result<[LocatedEdit], AIError>] = [:]
            var next = 0
            var stopped = false
            func startNext() {
                guard !stopped, next < jobs.count else { return }
                let job = jobs[next]
                next += 1
                group.addTask {
                    let language = job.language.isEmpty ? nil : job.language
                    let result = await service.proofread(paragraph: job.paragraph.text, language: language, goals: goals, endpoint: endpoint)
                    return (job.index, result.map { EditLocator.locate($0, in: job.paragraph.text) })
                }
            }
            for _ in 0..<Self.maxConcurrentRequests { startNext() }
            while let (index, result) = await group.next() {
                results[index] = result
                if case .failure(let error) = result, error.stopsBatch, !stopped {
                    stopped = true
                    group.cancelAll()
                    for job in jobs[next...] { results[job.index] = .failure(error) }
                }
                startNext()
            }
            return results
        }
    }
}
