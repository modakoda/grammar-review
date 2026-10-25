import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

final class MockWebSearch: WebSearching {
    private let queries = OSAllocatedUnfairLock<[String]>(initialState: [])
    private let handler: @Sendable (String, Int) async throws -> [WebSearchResult]

    init(handler: @escaping @Sendable (_ query: String, _ attempt: Int) async throws -> [WebSearchResult]) {
        self.handler = handler
    }

    var received: [String] { queries.withLock { $0 } }

    func search(_ query: String, apiKey: String, count: Int) async throws -> [WebSearchResult] {
        let attempt = queries.withLock { queries in
            queries.append(query)
            return queries.count { $0 == query }
        }
        return try await handler(query, attempt)
    }
}

func webResult(_ url: String, _ description: String, title: String = "Page", site: String = "Site") -> WebSearchResult {
    WebSearchResult(url: URL(string: url)!, title: title, description: description, snippets: [], siteName: site)
}

@Suite(.timeLimit(.minutes(1))) struct PlagiarismCheckerTests {
    static let copied = "We hold these truths to be self-evident, that all men are created equal."
    static let original = "My grandmother kept a small notebook of recipes in her kitchen drawer."
    static let quoted = "Four score and seven years ago our fathers brought forth on this continent a new nation."

    private func checker(_ search: MockWebSearch, key: String? = "BSA-key") -> PlagiarismChecker {
        PlagiarismChecker(apiKey: { key }, search: search, retryDelay: .zero)
    }

    @Test func matchingSentencesAreGroupedBySource() async throws {
        let search = MockWebSearch { query, _ in
            if query.contains("We hold") {
                return [
                    webResult("https://www.archives.gov/declaration#top", "We hold these truths to be self-evident, that all men are created equal…"),
                    webResult("https://example.com/essay", "an essay about equality and the founders"),
                ]
            }
            if query.contains("Four score") {
                return [webResult("https://archives.gov/declaration/", "Four score and seven years ago our fathers brought forth on this continent")]
            }
            return [webResult("https://example.com/recipes", "Recipes for a small kitchen")]
        }
        let text = "\(Self.copied) \(Self.original)\n\n\(Self.quoted)"
        let progress = OSAllocatedUnfairLock<[PlagiarismProgress]>(initialState: [])
        let report = try await checker(search).checkPlagiarism(text) { update in progress.withLock { $0.append(update) } }

        #expect(search.received.count == 3)
        #expect(report.checkedPassages.count == 3)
        #expect(report.sources.map(\.url.absoluteString) == ["https://www.archives.gov/declaration#top"])
        #expect(report.sources[0].passages.map { substring(text, $0) } == [Self.copied, Self.quoted])
        #expect(report.matchedPassages.count == 2)
        #expect(report.matchedShare > 0.6 && report.matchedShare < 0.8)
        #expect(progress.withLock { $0.first } == PlagiarismProgress(searched: 0, total: 3))
        #expect(progress.withLock { $0.last } == PlagiarismProgress(searched: 3, total: 3))
    }

    @Test func originalTextHasNoSources() async throws {
        let search = MockWebSearch { _, _ in [webResult("https://example.com", "Something unrelated to the sentence that was searched for.")] }
        let report = try await checker(search).checkPlagiarism(Self.original) { _ in }
        #expect(report.sources.isEmpty)
        #expect(report.matchedShare == 0)
        #expect(report.skippedPassages == 0)
    }

    @Test func sourcesWithMoreMatchesComeFirst() {
        let text = "\(Self.copied) \(Self.quoted)"
        let passages = PassageSampler.passages(in: text)
        let results = [
            [webResult("https://one.example/a", Self.copied)],
            [webResult("https://two.example/b", Self.quoted), webResult("https://one.example/a", Self.quoted)],
        ]
        let report = PlagiarismChecker.report(for: text, passages: passages, results: results, skipped: 4)
        #expect(report.sources.map(\.siteName) == ["Site", "Site"])
        #expect(report.sources.map(\.url.host) == ["one.example", "two.example"])
        #expect(report.sources[0].passages.count == 2)
        #expect(report.skippedPassages == 4)
    }

    @Test func noKeyOrNoSentencesStopsBeforeSearching() async {
        let search = MockWebSearch { _, _ in [] }
        await #expect(throws: PlagiarismError.missingAPIKey) {
            try await checker(search, key: "  ").checkPlagiarism(Self.copied) { _ in }
        }
        await #expect(throws: PlagiarismError.tooShort) {
            try await checker(search).checkPlagiarism("Too short. Also short.") { _ in }
        }
        #expect(search.received.isEmpty)
    }

    @Test func rateLimitsAreRetriedButOtherErrorsStopTheCheck() async throws {
        let flaky = MockWebSearch { _, attempt in
            if attempt == 1 { throw PlagiarismError.rateLimited }
            return []
        }
        _ = try await checker(flaky).checkPlagiarism(Self.copied) { _ in }
        #expect(flaky.received.count == 2)

        let limited = MockWebSearch { _, _ in throw PlagiarismError.rateLimited }
        await #expect(throws: PlagiarismError.rateLimited) {
            try await checker(limited).checkPlagiarism(Self.copied) { _ in }
        }
        #expect(limited.received.count == 1 + PlagiarismChecker.rateLimitRetries)

        let rejected = MockWebSearch { _, _ in throw PlagiarismError.invalidAPIKey }
        await #expect(throws: PlagiarismError.invalidAPIKey) {
            try await checker(rejected).checkPlagiarism("\(Self.copied) \(Self.quoted) \(Self.original)") { _ in }
        }
        #expect(rejected.received.count <= PlagiarismChecker.concurrentSearches)
    }

    @Test func urlsAreComparedWithoutFragmentsSchemesOrWWW() {
        #expect(PlagiarismChecker.canonical(URL(string: "http://WWW.Example.com/page/#part")!) == "https://example.com/page")
        #expect(PlagiarismChecker.canonical(URL(string: "https://example.com/page?id=2")!) == "https://example.com/page?id=2")
    }
}

@Suite struct CitationTests {
    static let accessed = ISO8601DateFormatter().date(from: "2026-10-25T12:00:00Z")!
    static let published = ISO8601DateFormatter().date(from: "2023-05-17T00:00:00Z")!

    private func source(published: Date?, title: String = "Declaration of Independence: A Transcription") -> PlagiarismSource {
        PlagiarismSource(
            url: URL(string: "https://www.archives.gov/founding-docs/declaration-transcript")!,
            title: title, siteName: "National Archives", published: published, snippet: "", passages: [], similarity: 1
        )
    }

    @Test func apa() {
        #expect(Citation.format(source(published: Self.published), style: .apa, accessed: Self.accessed)
            == "Declaration of Independence: A Transcription. (2023, May 17). National Archives. https://www.archives.gov/founding-docs/declaration-transcript")
        #expect(Citation.format(source(published: nil), style: .apa, accessed: Self.accessed)
            == "Declaration of Independence: A Transcription. (n.d.). National Archives. Retrieved October 25, 2026, from https://www.archives.gov/founding-docs/declaration-transcript")
    }

    @Test func mla() {
        #expect(Citation.format(source(published: Self.published), style: .mla, accessed: Self.accessed)
            == "\u{201C}Declaration of Independence: A Transcription.\u{201D} National Archives, 17 May 2023, www.archives.gov/founding-docs/declaration-transcript. Accessed 25 Oct. 2026.")
    }

    @Test func chicago() {
        #expect(Citation.format(source(published: nil, title: "Is it true?"), style: .chicago, accessed: Self.accessed)
            == "\u{201C}Is it true?\u{201D} National Archives. Accessed October 25, 2026. https://www.archives.gov/founding-docs/declaration-transcript.")
        #expect(Citation.format(source(published: Self.published), style: .chicago, accessed: Self.accessed)
            == "\u{201C}Declaration of Independence: A Transcription.\u{201D} National Archives. May 17, 2023. https://www.archives.gov/founding-docs/declaration-transcript.")
    }
}
