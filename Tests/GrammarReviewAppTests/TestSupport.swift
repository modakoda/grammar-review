import CoreGraphics
import Foundation
import GrammarAppUI
import GrammarModels
import os
import Testing
@testable import GrammarReviewApp

@MainActor
final class FakeField: TextFieldHandle {
    static let defaultFrame = CGRect(x: 100, y: 100, width: 400, height: 200)

    var text: String?
    var selection: NSRange?
    var fieldFrame: CGRect? = FakeField.defaultFrame
    var isSingleLine = false
    var acceptsReplacements = true
    private(set) var replacements: [String] = []
    private(set) var rectRequests: [NSRange] = []

    let processID: pid_t = 42
    let bundleID: String? = "com.apple.TextEdit"
    let appName: String? = "TextEdit"
    let isSecure = false

    init(_ text: String?) {
        self.text = text
        selection = NSRange(location: text.map { ($0 as NSString).length } ?? 0, length: 0)
    }

    static func rect(for range: NSRange) -> CGRect {
        CGRect(x: 110 + CGFloat(range.location) * 8, y: 280, width: CGFloat(range.length) * 8, height: 16)
    }

    func readText() -> String? { text }
    func selectedRange() -> NSRange? { selection }
    func frame() -> CGRect? { fieldFrame }

    func rects(for range: NSRange) -> [CGRect] {
        rectRequests.append(range)
        return [Self.rect(for: range)]
    }

    func replace(_ range: NSRange, with replacement: String) -> Bool {
        guard acceptsReplacements, let current = text else { return false }
        text = (current as NSString).replacingCharacters(in: range, with: replacement)
        replacements.append("\(range.location)+\(range.length)→\(replacement)")
        return true
    }

    func select(_ range: NSRange) -> Bool {
        selection = range
        return true
    }

    func isSameField(as other: any TextFieldHandle) -> Bool { other === self }
}

@MainActor
final class FakeOverlay: SuggestionPresenting {
    weak var delegate: (any SuggestionPresenterDelegate)?
    let isShowingPanel = false
    private(set) var states: [OverlayState] = []
    private(set) var hides = 0

    func update(_ state: OverlayState) { states.append(state) }
    func showCard(for issueID: UUID?) {}
    func togglePanel() {}
    func showRewrite(_ state: RewriteState?) {}
    func showCompose(_ state: ComposeState?) {}
    func hideAll() { hides += 1 }
}

final class FakeEngine: GrammarChecking {
    private struct State {
        var requests: [CheckRequest] = []
        var streams: [AsyncStream<CheckResult>.Continuation] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let respond: @Sendable (CheckRequest) -> [CheckResult]?

    init(respond: @escaping @Sendable (CheckRequest) -> [CheckResult]? = { _ in nil }) {
        self.respond = respond
    }

    var requests: [CheckRequest] { state.withLock { $0.requests } }

    func check(_ request: CheckRequest) -> AsyncStream<CheckResult> {
        let (stream, continuation) = AsyncStream.makeStream(of: CheckResult.self)
        if let results = respond(request) {
            for result in results { continuation.yield(result) }
            continuation.finish()
        }
        state.withLock { state in
            state.requests.append(request)
            state.streams.append(continuation)
        }
        return stream
    }

    func send(_ result: CheckResult) {
        state.withLock { $0.streams.last }?.yield(result)
    }

    func learnWord(_ word: String) {}
}

final class FakeToneDetector: ToneDetecting {
    static let report = ToneReport(tones: [ToneScore(tone: .friendly, intensity: .moderate)], sentiment: .positive, summary: "Warm.")

    func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport { Self.report }
}

@MainActor
final class SessionHarness {
    let field: FakeField
    let engine: FakeEngine
    let session: FieldSession
    private(set) var results = 0

    init(_ text: String?, settings: SettingsStore, respond: @escaping @Sendable (CheckRequest) -> [CheckResult]? = { _ in nil }) {
        field = FakeField(text)
        engine = FakeEngine(respond: respond)
        session = FieldSession(field: field, engine: engine, settingsStore: settings)
        session.onResult = { [weak self] in self?.results += 1 }
    }

    func check() async throws {
        let seen = results
        session.scheduleCheck(after: .zero)
        try await waitUntil { results > seen }
    }

    func startCheck() async throws {
        let sent = engine.requests.count
        session.scheduleCheck(after: .zero)
        try await waitUntil { engine.requests.count > sent }
    }

    func send(_ result: CheckResult) async throws {
        let seen = results
        engine.send(result)
        try await waitUntil { results > seen }
    }
}

func issue(
    _ location: Int,
    _ text: String,
    _ category: IssueCategory = .spelling,
    source: IssueSource = .local,
    replacements: [String] = ["fix"]
) -> TextIssue {
    TextIssue(range: NSRange(location: location, length: (text as NSString).length), originalText: text,
              replacements: replacements, message: "m", category: category, source: source)
}

func result(_ text: String, _ issues: [TextIssue], _ aiStatus: AIStatus = .completed) -> CheckResult {
    CheckResult(text: text, issues: issues, language: "en", aiStatus: aiStatus)
}

func answering(_ issues: [TextIssue], _ aiStatus: AIStatus = .completed) -> @Sendable (CheckRequest) -> [CheckResult]? {
    { request in [result(request.text, issues, aiStatus)] }
}

@MainActor
func withSettings<T>(_ body: (SettingsStore) async throws -> T) async rethrows -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GrammarReviewAppTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let suiteName = directory.appendingPathComponent("settings").path
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    return try await body(SettingsStore(defaults: defaults))
}

@MainActor
func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
