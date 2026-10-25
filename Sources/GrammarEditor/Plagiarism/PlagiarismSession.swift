import AppKit
import GrammarEngine
import GrammarModels
import Observation

@Observable
final class PlagiarismSession {
    enum State: Equatable {
        case idle
        case checking(PlagiarismProgress)
        case ready(PlagiarismReport)
        case failed(String, offersSettings: Bool)
    }

    private(set) var state: State = .idle
    private(set) var matches: [NSRange] = []
    private(set) var isStale = false
    private(set) var selectedSourceID: String?

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let checker: any PlagiarismChecking
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    @ObservationIgnored private var tracked: [TextIssue] = []
    @ObservationIgnored private var passageIDs: [NSRange: UUID] = [:]

    init(checker: any PlagiarismChecking) {
        self.checker = checker
    }

    var isChecking: Bool {
        if case .checking = state { true } else { false }
    }

    func check(_ text: String) {
        task?.cancel()
        clearMatches()
        state = .checking(PlagiarismProgress(searched: 0, total: 0))
        onChange?()
        let checker = checker
        let progressed: @Sendable (PlagiarismProgress) -> Void = { [weak self] progress in
            Task { @MainActor in self?.progressed(progress) }
        }
        task = Task { [weak self] in
            do {
                let report = try await checker.checkPlagiarism(text, progress: progressed)
                guard !Task.isCancelled else { return }
                self?.finished(report)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let failure = error as? PlagiarismError ?? .failed(error.localizedDescription)
                self?.state = .failed(failure.message, offersSettings: failure.offersSettings)
                self?.onChange?()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if isChecking {
            state = .idle
            onChange?()
        }
    }

    func textDidChange(from oldText: String, to newText: String) {
        guard !tracked.isEmpty || isReady, oldText != newText else { return }
        tracked = IssueRebaser.rebase(tracked, from: oldText, to: newText)
        matches = tracked.map(\.range)
        isStale = true
    }

    func select(_ source: PlagiarismSource?) {
        selectedSourceID = source?.id
        onChange?()
    }

    func ranges(of source: PlagiarismSource) -> [NSRange] {
        let ids = Set(source.passages.compactMap { passageIDs[$0] })
        return tracked.filter { ids.contains($0.id) }.map(\.range)
    }

    var selectedRanges: [NSRange] {
        guard case .ready(let report) = state, let source = report.sources.first(where: { $0.id == selectedSourceID }) else { return [] }
        return ranges(of: source)
    }

    static func copy(_ source: PlagiarismSource, style: CitationStyle, accessed: Date = Date(), to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(Citation.format(source, style: style, accessed: accessed), forType: .string)
    }

    private var isReady: Bool {
        if case .ready = state { true } else { false }
    }

    private func progressed(_ progress: PlagiarismProgress) {
        guard case .checking(let current) = state, progress.searched >= current.searched else { return }
        state = .checking(progress)
    }

    private func finished(_ report: PlagiarismReport) {
        let ns = report.text as NSString
        tracked = report.matchedPassages.map { range in
            TextIssue(range: range, originalText: ns.substring(with: range), replacements: [], message: "", category: .style, source: .local)
        }
        passageIDs = Dictionary(tracked.map { ($0.range, $0.id) }, uniquingKeysWith: { first, _ in first })
        matches = tracked.map(\.range)
        isStale = false
        selectedSourceID = nil
        state = .ready(report)
        onChange?()
    }

    private func clearMatches() {
        tracked = []
        passageIDs = [:]
        matches = []
        isStale = false
        selectedSourceID = nil
    }
}
