import AppKit
import GrammarEngine
import GrammarModels
import Observation

@Observable
final class EditorModel {
    private(set) var text = ""
    private(set) var selection = NSRange(location: 0, length: 0)
    var filter: IssueSeverity?
    private(set) var goals: WritingGoals
    var style: WritingStyle { goals.style }
    private(set) var isChecking = false
    private(set) var aiStatus: AIStatus = .completed
    private(set) var isTyping = false
    private(set) var language: String?
    private(set) var statistics = TextStatistics(text: "", language: nil)
    var sidebarTab: SidebarTab = .suggestions {
        didSet {
            guard sidebarTab != oldValue else { return }
            if sidebarTab == .insights { scheduleToneDetection(after: .zero) }
            redecorate()
        }
    }

    private(set) var tone: ToneState = .unavailable(ToneSession.needsTextMessage)
    private(set) var isDetectingTone = false
    @ObservationIgnored let plagiarism: PlagiarismSession
    @ObservationIgnored private let toneSession: ToneSession
    @ObservationIgnored private let toneDebounce: Duration

    @ObservationIgnored weak var surface: (any EditorTextSurface)? {
        didSet { lastDecorations = nil; redecorate() }
    }

    @ObservationIgnored private let services: EditorServices
    @ObservationIgnored private let issueList = EditorIssueList()
    @ObservationIgnored private let rewriter: EditorRewriter
    @ObservationIgnored private let composer: EditorComposer
    @ObservationIgnored private let checkDebounce: Duration
    @ObservationIgnored private let typingSettle: Duration
    @ObservationIgnored private var isApplyingEdit = false
    @ObservationIgnored private var lastDecorations: EditorDecorations?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?

    init(
        services: EditorServices,
        checkDebounce: Duration = .milliseconds(250),
        typingSettle: Duration = .milliseconds(1200),
        toneDebounce: Duration = .milliseconds(1500)
    ) {
        self.services = services
        self.checkDebounce = checkDebounce
        self.typingSettle = typingSettle
        self.toneDebounce = toneDebounce
        rewriter = EditorRewriter(rewriter: services.rewriter, settings: services.settings)
        composer = EditorComposer(composer: services.composer, settings: services.settings)
        toneSession = ToneSession(detector: services.toneDetector)
        plagiarism = PlagiarismSession(checker: services.plagiarism)
        goals = services.settings().editorGoals
        toneSession.onChange = { [weak self] in
            guard let self else { return }
            self.tone = self.toneSession.state
            self.isDetectingTone = self.toneSession.isDetecting
        }
        plagiarism.onChange = { [weak self] in self?.redecorate() }
    }

    var issues: [TextIssue] { issueList.issues }
    var selectedIssueID: UUID? { issueList.selectedID }
    var ignoredIssues: [TextIssue] { issueList.ignoredIssues }
    var rewrite: RewriteSession? { rewriter.session }
    var compose: ComposeSession? { composer.session }

    var visibleIssues: [TextIssue] {
        guard isTyping, selection.length == 0 else { return issues }
        let caret = selection.location
        return issues.filter { issue in
            !(issue.source == .local && caret >= issue.range.location && caret <= NSMaxRange(issue.range))
        }
    }

    var filteredIssues: [TextIssue] {
        guard let filter else { return visibleIssues }
        return visibleIssues.filter { $0.category.severity == filter }
    }

    func count(of severity: IssueSeverity?) -> Int {
        guard let severity else { return visibleIssues.count }
        return visibleIssues.count { $0.category.severity == severity }
    }

    var acceptAllCount: Int {
        visibleIssues.count { $0.category.severity == .correctness && !$0.replacements.isEmpty }
    }

    var wordCount: Int { statistics.words }

    var status: EditorStatus {
        EditorStatus(text: text, isChecking: isChecking, aiStatus: aiStatus)
    }

    var rewritesSelection: Bool { selection.length > 0 }
    var offersRephrase: Bool { aiStatus != .disabled }

    func textDidChange(_ newText: String, selection newSelection: NSRange) {
        selection = newSelection
        guard newText != text else { return }
        issueList.rebase(from: text, to: newText)
        plagiarism.textDidChange(from: text, to: newText)
        text = newText
        statistics = TextStatistics(text: newText, language: language)
        if !isApplyingEdit { markTyping() }
        redecorate()
        scheduleCheck()
        if sidebarTab == .insights { scheduleToneDetection(after: toneDebounce) }
    }

    func selectionDidChange(_ newSelection: NSRange, in currentText: String) {
        selection = newSelection
        guard currentText == text, !isTyping, newSelection.length == 0 else {
            redecorate()
            return
        }
        let caret = newSelection.location
        let hit = visibleIssues.first { caret > $0.range.location && caret < NSMaxRange($0.range) }
        issueList.select(hit?.id)
        redecorate()
    }

    func select(_ issue: TextIssue) {
        issueList.select(issue.id)
        surface?.reveal(issue.range)
        redecorate()
    }

    func setStyle(_ newStyle: WritingStyle) {
        var newGoals = goals
        newGoals.style = newStyle
        setGoals(newGoals)
    }

    func setGoals(_ newGoals: WritingGoals) {
        guard newGoals != goals else { return }
        goals = newGoals
        services.saveGoals(newGoals)
        scheduleCheck(after: .zero)
    }

    @discardableResult
    func accept(_ replacement: String, for issue: TextIssue) -> Bool {
        guard let current = issueList.remove(issue, matching: text) else {
            NSSound.beep()
            return false
        }
        return applyEdit(current.range, replacement)
    }

    func acceptAll() {
        let fixes = visibleIssues
            .filter { $0.category.severity == .correctness && !$0.replacements.isEmpty }
            .sorted { $0.range.location > $1.range.location }
        for issue in fixes {
            accept(issue.replacements[0], for: issue)
        }
    }

    func ignore(_ issue: TextIssue) {
        issueList.ignore(issue)
        redecorate()
    }

    func restore(_ issue: TextIssue) {
        issueList.restore(issue)
        redecorate()
    }

    func addToDictionary(_ issue: TextIssue) {
        let word = issue.originalText
        services.checker.learnWord(word)
        issueList.removeSpelling(of: word)
        redecorate()
        services.addToDictionary(word)
    }

    func openSettings() {
        services.openSettings()
    }

    func settingsDidChange() {
        scheduleCheck(after: .zero)
        toneSession.invalidate()
        if sidebarTab == .insights { scheduleToneDetection(after: .zero) }
    }

    func checkPlagiarism() {
        plagiarism.check(text)
    }

    func revealPlagiarism(_ source: PlagiarismSource) {
        plagiarism.select(source)
        guard let first = plagiarism.ranges(of: source).first else {
            NSSound.beep()
            return
        }
        surface?.reveal(first)
    }

    func openPlagiarismSettings() {
        services.openPlagiarismSettings()
    }

    func revealLongSentence(at index: Int) {
        guard statistics.longSentences.indices.contains(index) else { return }
        surface?.reveal(statistics.longSentences[index])
    }

    func startRewrite(_ tone: RewriteTone) {
        startRewrite(goal: .tone(tone), target: .selectionOrParagraph(selection, in: text))
    }

    func startCustomRewrite() {
        startRewrite(goal: .instruction(""), target: .selectionOrParagraph(selection, in: text))
    }

    func rephraseSentence() {
        startRewrite(goal: .tone(.rephrase), target: .sentence(around: selection, in: text))
    }

    func rephraseSentence(of issue: TextIssue) {
        guard let current = issueList.current(issue) else {
            NSSound.beep()
            return
        }
        startRewrite(goal: .tone(.rephrase), target: .sentence(around: current.range, in: text))
    }

    private func startRewrite(goal: RewriteGoal, target: RewriteTarget?) {
        guard let target else {
            NSSound.beep()
            return
        }
        cancelCompose()
        sidebarTab = .suggestions
        rewriter.start(RewriteSession(
            range: target.range,
            scope: target.scope,
            original: (text as NSString).substring(with: target.range),
            goal: goal,
            result: nil
        ))
        redecorate()
    }

    func changeRewriteTone(_ tone: RewriteTone) {
        rewriter.change(to: .tone(tone))
    }

    func rewrite(withInstruction instruction: String) {
        let instruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        rewriter.change(to: .instruction(instruction))
    }

    func applyRewrite() {
        guard let session = rewrite, case .ready(let replacement) = session.result else { return }
        let ns = text as NSString
        guard NSMaxRange(session.range) <= ns.length, ns.substring(with: session.range) == session.original else {
            rewriter.fail("The text changed since this rewrite. Rewrite it again.")
            return
        }
        rewriter.end()
        applyEdit(session.range, replacement)
    }

    func cancelRewrite() {
        rewriter.end()
        redecorate()
    }

    func startCompose() {
        cancelRewrite()
        sidebarTab = .suggestions
        let ns = text as NSString
        let range = NSMaxRange(selection) <= ns.length ? selection : NSRange(location: ns.length, length: 0)
        composer.start(ComposeSession(
            usesText: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            range: range,
            replaced: ns.substring(with: range)
        ))
        redecorate()
    }

    func setComposeUsesText(_ usesText: Bool) {
        composer.setUsesText(usesText)
    }

    func compose(_ request: String) {
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session = compose, !request.isEmpty else { return }
        let context = session.usesText ? (text as NSString).replacingCharacters(in: session.range, with: "") : nil
        composer.compose(request, context: context)
    }

    func insertComposed() {
        guard let session = compose, case .ready(let composed) = session.result else { return }
        let ns = text as NSString
        guard NSMaxRange(session.range) <= ns.length, ns.substring(with: session.range) == session.replaced else {
            composer.fail("The text changed where this was going to go. Place the cursor and try again.")
            return
        }
        composer.end()
        applyEdit(session.range, ComposeInsertion.text(composed, at: session.range, in: text, as: .paragraph))
    }

    func cancelCompose() {
        let wasComposing = compose != nil
        composer.end()
        if wasComposing { redecorate() }
    }

    private func scheduleCheck(after delay: Duration? = nil) {
        debounceTask?.cancel()
        isChecking = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let delay = delay ?? checkDebounce
        debounceTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            self?.runCheck()
        }
    }

    private func runCheck() {
        checkTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issueList.clear()
            isChecking = false
            aiStatus = .completed
            redecorate()
            return
        }
        let request = CheckRequest(text: text, bundleID: Bundle.main.bundleIdentifier, settings: services.settings(), goals: goals)
        let stream = services.checker.check(request)
        checkTask = Task { [weak self] in
            for await result in stream {
                guard !Task.isCancelled else { return }
                self?.handle(result)
            }
        }
    }

    private func handle(_ result: CheckResult) {
        issueList.update(with: result, text: text)
        aiStatus = result.aiStatus
        if result.language != language {
            language = result.language
            statistics = TextStatistics(text: text, language: language)
        }
        if result.isFinal, result.text == text { isChecking = false }
        redecorate()
    }

    private func scheduleToneDetection(after delay: Duration) {
        toneSession.update(text: text, settings: services.settings(), after: delay)
    }

    @discardableResult
    private func applyEdit(_ range: NSRange, _ replacement: String) -> Bool {
        isApplyingEdit = true
        defer { isApplyingEdit = false }
        guard let surface, surface.replaceText(in: range, with: replacement) else {
            NSSound.beep()
            redecorate()
            return false
        }
        return true
    }

    private func markTyping() {
        isTyping = true
        settleTask?.cancel()
        let settle = typingSettle
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled, let self else { return }
            self.isTyping = false
            self.redecorate()
        }
    }

    private func redecorate() {
        let decorations = EditorDecorations(
            underlines: visibleIssues.map { EditorDecorations.Underline(range: $0.range, severity: $0.category.severity) },
            active: issueList.selected?.range,
            rewriteTarget: rewrite?.range ?? compose.flatMap { $0.range.length > 0 ? $0.range : nil },
            longSentences: sidebarTab == .insights ? statistics.longSentences : [],
            plagiarism: sidebarTab == .plagiarism ? plagiarism.matches : [],
            selectedPlagiarism: sidebarTab == .plagiarism ? plagiarism.selectedRanges : []
        )
        guard decorations != lastDecorations, let surface else { return }
        lastDecorations = decorations
        surface.decorate(decorations)
    }
}
