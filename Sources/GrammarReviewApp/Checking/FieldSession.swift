import AppKit
import GrammarAppUI
import GrammarEngine
import GrammarModels

final class FieldSession {
    static let checkDebounce = Duration.milliseconds(250)

    let field: any TextFieldHandle
    private(set) var text: String
    private(set) var issues: [TextIssue] = []
    private(set) var status: CheckStatus = .checking
    private var ignored = IgnoredIssues()
    var onResult: () -> Void = {}

    private let engine: any GrammarChecking
    private let settingsStore: SettingsStore
    private var debounceTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?

    init(field: any TextFieldHandle, engine: any GrammarChecking, settingsStore: SettingsStore) {
        self.field = field
        self.engine = engine
        self.settingsStore = settingsStore
        text = field.readText() ?? ""
    }

    var ignoredIssues: [TextIssue] { ignored.list }

    var correctnessFixes: [TextIssue] {
        issues
            .filter { $0.category.severity == .correctness && !$0.replacements.isEmpty }
            .sorted { $0.range.location > $1.range.location }
    }

    func end() {
        debounceTask?.cancel()
        checkTask?.cancel()
    }

    func refreshText() -> Bool {
        guard let newText = field.readText(), newText != text else { return false }
        rebase(to: newText)
        status = .checking
        return true
    }

    func scheduleCheck(after delay: Duration = checkDebounce) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            self?.runCheck()
        }
    }

    func applyFix(_ replacement: String, to issueID: UUID) -> Bool {
        if let current = field.readText(), current != text {
            rebase(to: current)
        }
        let ns = text as NSString
        guard let issue = issues.first(where: { $0.id == issueID }),
              NSMaxRange(issue.range) <= ns.length,
              ns.substring(with: issue.range) == issue.originalText
        else {
            Log.app.info("Fix skipped: issue no longer matches the text")
            NSSound.beep()
            return false
        }
        guard field.replace(issue.range, with: replacement) else {
            Log.app.error("Replacing text failed in \(self.field.bundleID ?? "?", privacy: .public)")
            NSSound.beep()
            return false
        }
        issues.removeAll { $0.id == issueID }
        rebase(to: ns.replacingCharacters(in: issue.range, with: replacement))
        return true
    }

    func ignore(_ issue: TextIssue) {
        ignored.ignore(issue, in: &issues)
    }

    func restore(_ issue: TextIssue) {
        ignored.restore(issue, into: &issues)
    }

    func removeSpelling(of word: String) {
        let isWord = { (other: TextIssue) in
            other.category == .spelling && other.originalText.caseInsensitiveCompare(word) == .orderedSame
        }
        issues.removeAll(where: isWord)
        ignored.removeHidden(where: isWord)
    }

    private func rebase(to newText: String) {
        issues = IssueRebaser.rebase(issues, from: text, to: newText)
        ignored.rebase(from: text, to: newText)
        text = newText
    }

    private func runCheck() {
        checkTask?.cancel()
        let settings = settingsStore.settings
        let request = CheckRequest(text: text, bundleID: field.bundleID, settings: settings, goals: settings.goals(forApp: field.bundleID))
        let stream = engine.check(request)
        checkTask = Task { [weak self] in
            for await result in stream {
                guard !Task.isCancelled else { return }
                self?.handle(result)
            }
        }
    }

    private func handle(_ result: CheckResult) {
        var fresh = result.text == text
            ? result.issues
            : IssueRebaser.rebase(result.issues, from: result.text, to: text)

        if !result.isFinal {
            let carried = (issues + ignored.hidden).filter { old in
                old.source == .ai && !fresh.contains { NSIntersectionRange($0.range, old.range).length > 0 }
            }
            fresh += carried
            fresh.sort { $0.range.location < $1.range.location }
        }

        issues = ignored.filter(fresh)
        status = Self.checkStatus(for: result.aiStatus)
        Log.app.debug("Check result: \(result.issues.count, privacy: .public) issues (\(self.issues.count, privacy: .public) kept), AI \(String(describing: result.aiStatus), privacy: .public)")
        onResult()
    }

    private static func checkStatus(for aiStatus: AIStatus) -> CheckStatus {
        switch aiStatus {
        case .pending: .checking
        case .completed, .disabled: .done
        case .missingAPIKey: .aiUnavailable("Add an Anthropic API key in Settings to get grammar and style suggestions.")
        case .textTooLong: .aiUnavailable("This text is too long for AI checks; showing spelling only.")
        case .failed(let message): .aiUnavailable(message)
        }
    }
}
