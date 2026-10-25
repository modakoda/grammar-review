import AppKit
import GrammarModels
import os
import Testing
@testable import GrammarEditor

final class FakePlagiarismChecker: PlagiarismChecking, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (texts: [String](), report: PlagiarismReport?.none))
    let failure = OSAllocatedUnfairLock<PlagiarismError?>(initialState: nil)
    let delay = OSAllocatedUnfairLock<Duration>(initialState: .zero)

    var texts: [String] { state.withLock { $0.texts } }
    var lastReport: PlagiarismReport? { state.withLock { $0.report } }

    func checkPlagiarism(_ text: String, progress: @escaping @Sendable (PlagiarismProgress) -> Void) async throws -> PlagiarismReport {
        state.withLock { $0.texts.append(text) }
        progress(PlagiarismProgress(searched: 0, total: 1))
        let delay = delay.withLock { $0 }
        if delay > .zero { try await Task.sleep(for: delay) }
        if let failure = failure.withLock({ $0 }) { throw failure }
        progress(PlagiarismProgress(searched: 1, total: 1))
        let ns = text as NSString
        let passage = ns.range(of: "We hold these truths to be self-evident, that all men are created equal.")
        let sources = passage.location == NSNotFound ? [] : [PlagiarismSource(
            url: URL(string: "https://www.archives.gov/founding-docs/declaration-transcript")!,
            title: "Declaration of Independence: A Transcription", siteName: "National Archives",
            published: nil, snippet: "We hold these truths…", passages: [passage], similarity: 1
        )]
        let report = PlagiarismReport(
            text: text, checkedPassages: sources.isEmpty ? [] : [passage], skippedPassages: 0,
            checkedWords: 14, matchedWords: sources.isEmpty ? 0 : 14, sources: sources
        )
        state.withLock { $0.report = report }
        return report
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1))) struct PlagiarismSessionTests {
    @Test func aCheckShowsProgressThenTheReport() async throws {
        let checker = FakePlagiarismChecker()
        let session = PlagiarismSession(checker: checker)
        var changes = 0
        session.onChange = { changes += 1 }
        session.check("We hold these truths to be self-evident, that all men are created equal.")
        #expect(session.isChecking)
        try await waitUntil { if case .ready = session.state { true } else { false } }

        guard case .ready(let report) = session.state else { return }
        #expect(report.sources.count == 1)
        #expect(session.matches == [NSRange(location: 0, length: 72)])
        #expect(!session.isStale)
        #expect(changes >= 2)
    }

    @Test func failuresSayWhetherSettingsCanHelp() async throws {
        let checker = FakePlagiarismChecker()
        checker.failure.withLock { $0 = .missingAPIKey }
        let session = PlagiarismSession(checker: checker)
        session.check("Some text to check for plagiarism right now please.")
        try await waitUntil { if case .failed = session.state { true } else { false } }
        #expect(session.state == .failed(PlagiarismError.missingAPIKey.message, offersSettings: true))

        checker.failure.withLock { $0 = .offline }
        session.check("Some text to check for plagiarism right now please.")
        try await waitUntil { session.state == .failed(PlagiarismError.offline.message, offersSettings: false) }
    }

    @Test func cancellingStopsTheCheck() async throws {
        let checker = FakePlagiarismChecker()
        checker.delay.withLock { $0 = .seconds(30) }
        let session = PlagiarismSession(checker: checker)
        session.check("We hold these truths to be self-evident, that all men are created equal.")
        try await waitUntil { !checker.texts.isEmpty }
        session.cancel()
        #expect(session.state == .idle)
        #expect(session.task == nil)
    }

    @Test func citationsAreCopiedToTheClipboard() {
        let source = PlagiarismSource(
            url: URL(string: "https://example.com/a")!, title: "A Page", siteName: "Example",
            published: nil, snippet: "", passages: [], similarity: 1
        )
        let accessed = ISO8601DateFormatter().date(from: "2026-10-25T12:00:00Z")!
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("GrammarReviewTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        PlagiarismSession.copy(source, style: .mla, accessed: accessed, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "\u{201C}A Page.\u{201D} Example, example.com/a. Accessed 25 Oct. 2026.")
    }
}
