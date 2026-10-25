import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

@MainActor
@Suite(.timeLimit(.minutes(1))) struct ToneSessionTests {
    static let text = "We are happy to share the news today."

    @Test func detectsOncePerText() async throws {
        let detector = CountingToneDetector()
        let session = ToneSession(detector: detector)
        var changes = 0
        session.onChange = { changes += 1 }

        session.update(text: Self.text, settings: AppSettings())
        #expect(session.isDetecting)
        try await waitUntil { !session.isDetecting }
        #expect(session.state == .ready(CountingToneDetector.report))
        #expect(changes == 2, "detecting, then ready")

        session.update(text: Self.text, settings: AppSettings())
        try await Task.sleep(for: .milliseconds(20))
        #expect(detector.texts.count == 1, "the same text isn't sent again")

        session.invalidate()
        session.update(text: Self.text, settings: AppSettings())
        try await waitUntil { detector.texts.count == 2 && !session.isDetecting }
    }

    @Test func aNewerTextCancelsTheDebouncedOne() async throws {
        let detector = CountingToneDetector()
        let session = ToneSession(detector: detector)
        session.update(text: Self.text, settings: AppSettings(), after: .seconds(10))
        session.update(text: Self.text + " Really.", settings: AppSettings())
        try await waitUntil { !session.isDetecting }
        #expect(detector.texts == [Self.text + " Really."])
    }

    @Test func needsEnoughWordsAndAI() {
        let detector = CountingToneDetector()
        let session = ToneSession(detector: detector)
        session.update(text: "Hi there.", settings: AppSettings())
        #expect(session.state == .unavailable(ToneSession.needsTextMessage))

        var off = AppSettings()
        off.aiEnabled = false
        session.update(text: Self.text, settings: off)
        #expect(session.state == .unavailable(ToneSession.aiOffMessage))

        var capped = AppSettings()
        capped.maxAICharacters = 10
        session.update(text: Self.text, settings: capped)
        #expect(session.state == .unavailable(ToneSession.tooLongMessage))
        #expect(!session.isDetecting)
        #expect(detector.texts.isEmpty)
    }

    @Test func failuresAreShownAndRetried() async throws {
        let detector = CountingToneDetector()
        detector.failure.withLock { $0 = .invalidAPIKey }
        let session = ToneSession(detector: detector)
        session.update(text: Self.text, settings: AppSettings())
        try await waitUntil { !session.isDetecting }
        #expect(session.state == .failed("Your Anthropic API key was rejected. Check it in Settings.", offersSettings: true))

        detector.failure.withLock { $0 = nil }
        session.update(text: Self.text, settings: AppSettings())
        try await waitUntil { !session.isDetecting && detector.texts.count == 2 }
        #expect(session.state == .ready(CountingToneDetector.report))
    }

    @Test func resetClearsTheReport() async throws {
        let session = ToneSession(detector: CountingToneDetector())
        session.update(text: Self.text, settings: AppSettings())
        try await waitUntil { !session.isDetecting }
        session.reset()
        #expect(session.state == .unavailable(ToneSession.needsTextMessage))
    }

    @Test func failureMessages() {
        #expect(ToneSession.failure(RewriteError.missingAPIKey) == .failed("Add an Anthropic API key in Settings to use tone detection.", offersSettings: true))
        #expect(ToneSession.failure(RewriteError.failed("You're offline")) == .failed("You're offline", offersSettings: false))
        #expect(ToneSession.failure(RewriteError.textTooLong) == .failed("This text is too long for tone detection.", offersSettings: false))
        let offline = URLError(.notConnectedToInternet)
        #expect(ToneSession.failure(offline) == .failed(offline.localizedDescription, offersSettings: false))
    }
}

final class CountingToneDetector: ToneDetecting, @unchecked Sendable {
    static let report = ToneReport(tones: [ToneScore(tone: .optimistic, intensity: .strong)], sentiment: .positive, summary: "Upbeat.")

    private let state = OSAllocatedUnfairLock(initialState: [String]())
    let failure = OSAllocatedUnfairLock<RewriteError?>(initialState: nil)

    var texts: [String] { state.withLock { $0 } }

    func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport {
        state.withLock { $0.append(text) }
        if let failure = failure.withLock({ $0 }) { throw failure }
        return Self.report
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
