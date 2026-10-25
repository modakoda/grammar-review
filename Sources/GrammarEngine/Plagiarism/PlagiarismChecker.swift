import Foundation
import GrammarModels
import os

public final class PlagiarismChecker: PlagiarismChecking {
    public static let maxSearches = 20
    static let resultsPerSearch = 10
    static let concurrentSearches = 2
    static let rateLimitRetries = 2

    private let apiKey: @Sendable () -> String?
    private let search: any WebSearching
    private let retryDelay: Duration

    public convenience init(apiKey: @escaping @Sendable () -> String?) {
        self.init(apiKey: apiKey, search: BraveSearchClient())
    }

    init(apiKey: @escaping @Sendable () -> String?, search: any WebSearching, retryDelay: Duration = .milliseconds(1100)) {
        self.apiKey = apiKey
        self.search = search
        self.retryDelay = retryDelay
    }

    public func validateKey(_ key: String) async throws {
        _ = try await search.search("grammar", apiKey: key.trimmedWhitespace, count: 1)
    }

    public func checkPlagiarism(_ text: String, progress: @escaping @Sendable (PlagiarismProgress) -> Void) async throws -> PlagiarismReport {
        guard let key = apiKey()?.trimmedWhitespace, !key.isEmpty else { throw PlagiarismError.missingAPIKey }
        let all = PassageSampler.passages(in: text)
        guard !all.isEmpty else { throw PlagiarismError.tooShort }
        let passages = PassageSampler.sample(all, limit: Self.maxSearches)
        progress(PlagiarismProgress(searched: 0, total: passages.count))
        let results = try await searchAll(passages, key: key, progress: progress)
        Log.engine.debug("Plagiarism: searched \(passages.count, privacy: .public) of \(all.count, privacy: .public) sentences")
        return Self.report(for: text, passages: passages, results: results, skipped: all.count - passages.count)
    }

    static func report(for text: String, passages: [Passage], results: [[WebSearchResult]], skipped: Int) -> PlagiarismReport {
        var sources: [String: PlagiarismSource] = [:]
        var order: [String] = []
        var matchedWords = 0
        for (passage, found) in zip(passages, results) {
            var matched = false
            for result in found {
                guard let share = PassageMatcher.matches(passage, result) else { continue }
                matched = true
                let key = canonical(result.url)
                if var source = sources[key] {
                    if !source.passages.contains(passage.range) { source.passages.append(passage.range) }
                    source.similarity = max(source.similarity, share)
                    sources[key] = source
                } else {
                    order.append(key)
                    sources[key] = PlagiarismSource(
                        url: result.url,
                        title: result.title,
                        siteName: result.siteName,
                        published: result.published,
                        snippet: result.description,
                        passages: [passage.range],
                        similarity: share
                    )
                }
            }
            if matched { matchedWords += passage.words.count }
        }
        let ranked = order.enumerated().compactMap { index, key in sources[key].map { (index, $0) } }
            .sorted { lhs, rhs in
                if lhs.1.passages.count != rhs.1.passages.count { return lhs.1.passages.count > rhs.1.passages.count }
                if lhs.1.similarity != rhs.1.similarity { return lhs.1.similarity > rhs.1.similarity }
                return lhs.0 < rhs.0
            }
            .map(\.1)
        return PlagiarismReport(
            text: text,
            checkedPassages: passages.map(\.range),
            skippedPassages: skipped,
            checkedWords: passages.reduce(0) { $0 + $1.words.count },
            matchedWords: matchedWords,
            sources: ranked
        )
    }

    static func canonical(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        components.fragment = nil
        components.scheme = "https"
        var host = components.host?.lowercased() ?? ""
        if host.hasPrefix("www.") { host.removeFirst(4) }
        components.host = host
        var key = components.string ?? url.absoluteString
        if key.hasSuffix("/") { key.removeLast() }
        return key
    }

    private func searchAll(
        _ passages: [Passage],
        key: String,
        progress: @escaping @Sendable (PlagiarismProgress) -> Void
    ) async throws -> [[WebSearchResult]] {
        try await withThrowingTaskGroup(of: (Int, [WebSearchResult]).self) { group in
            var results = Array(repeating: [WebSearchResult](), count: passages.count)
            var next = 0
            var done = 0
            func startNext() {
                guard next < passages.count else { return }
                let index = next
                let query = PassageSampler.query(for: passages[index])
                next += 1
                group.addTask { [self] in (index, try await searchRetryingRateLimits(query, key: key)) }
            }
            for _ in 0..<Self.concurrentSearches { startNext() }
            while let (index, found) = try await group.next() {
                results[index] = found
                done += 1
                progress(PlagiarismProgress(searched: done, total: passages.count))
                startNext()
            }
            return results
        }
    }

    private func searchRetryingRateLimits(_ query: String, key: String) async throws -> [WebSearchResult] {
        var attempt = 0
        while true {
            do {
                return try await search.search(query, apiKey: key, count: Self.resultsPerSearch)
            } catch PlagiarismError.rateLimited where attempt < Self.rateLimitRetries {
                attempt += 1
                try await Task.sleep(for: retryDelay * attempt)
            }
        }
    }
}
