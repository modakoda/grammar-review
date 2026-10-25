import AppKit
import GrammarAppUI
import GrammarEngine
import GrammarModels

final class AppCoordinator {
    var onStatusChange: ((MenuBarStatus) -> Void)? {
        get { menuStatus.onChange }
        set { menuStatus.onChange = newValue }
    }

    var onOpenSettings: ((SettingsTab?) -> Void)?

    private let settingsStore: SettingsStore
    private let engine: any GrammarChecking
    private let tracker: any FocusTracking
    private let overlay: any SuggestionPresenting
    private let toneSession: ToneSession
    private let renderer: OverlayRenderer
    private let rewrite: RewriteFlow
    private let compose: ComposeFlow
    private let menuStatus: MenuStatusReporter
    private let geometry = GeometryWatcher()

    private var session: FieldSession?
    private var lastTextChange = Date.distantPast
    private var caretCardIssueID: UUID?
    private var settleTask: Task<Void, Never>?
    private var appliedSettings: AppSettings

    private static let toneDebounce = Duration.milliseconds(1500)

    init(
        settingsStore: SettingsStore,
        engine: any GrammarChecking,
        rewriter: any TextRewriting,
        composer: any TextComposing,
        toneDetector: any ToneDetecting,
        tracker: any FocusTracking,
        overlay: any SuggestionPresenting
    ) {
        self.settingsStore = settingsStore
        self.engine = engine
        self.tracker = tracker
        self.overlay = overlay
        appliedSettings = settingsStore.settings
        toneSession = ToneSession(detector: toneDetector)
        renderer = OverlayRenderer(overlay: overlay, settingsStore: settingsStore, toneSession: toneSession)
        rewrite = RewriteFlow(rewriter: rewriter, overlay: overlay, settingsStore: settingsStore)
        compose = ComposeFlow(composer: composer, overlay: overlay, settingsStore: settingsStore)
        menuStatus = MenuStatusReporter(settingsStore: settingsStore, tracker: tracker)
        rewrite.willStart = { [weak self] in self?.compose.close() }
        compose.willStart = { [weak self] in self?.rewrite.close() }
        menuStatus.checkStatus = { [weak self] in self?.status ?? .done }
    }

    func start() {
        tracker.delegate = self
        overlay.delegate = self
        toneSession.onChange = { [weak self] in self?.render() }
        tracker.start()
        menuStatus.watchPermission()
        menuStatus.update()
    }

    func settingsDidChange(_ settings: AppSettings) {
        let previous = appliedSettings
        appliedSettings = settings
        if settings.differsOnlyInBadge(from: previous) {
            render()
            return
        }
        menuStatus.update()
        toneSession.invalidate()
        if let session {
            if canCheck(session.field) {
                renderer.forgetLastState()
                session.scheduleCheck()
            } else {
                clearField()
            }
        } else if let focused = tracker.focusedField {
            focus(focused)
        }
    }

    func keyboardLayoutDidChange() {
        guard let session, canCheck(session.field) else { return }
        session.scheduleCheck()
    }

    func toggleSuggestions() {
        guard session != nil, renderer.isShowing else {
            NSSound.beep()
            return
        }
        overlay.togglePanel()
    }

    func rewriteSelection() {
        guard let target = session?.field ?? tracker.focusedField else {
            NSSound.beep()
            return
        }
        rewrite.rewriteSelection(in: target)
    }

    func writeWithAI() {
        guard let target = session?.field ?? tracker.focusedField else {
            NSSound.beep()
            return
        }
        compose.start(in: target)
    }

    private var status: CheckStatus { session?.status ?? .done }

    private func focus(_ newField: (any TextFieldHandle)?) {
        if let newField, let field = session?.field, newField.isSameField(as: field) { return }
        if newField == nil, keepsCardOpen {
            Log.app.debug("Keeping the open card while focus is away from the field")
            return
        }
        clearField()
        menuStatus.update()
        guard let newField else { return }
        guard canCheck(newField) else {
            Log.app.debug("Focus ignored in \(newField.bundleID ?? "?", privacy: .public): \(self.ignoreReason(newField), privacy: .public)")
            return
        }
        Log.app.debug("Checking field in \(newField.bundleID ?? "?", privacy: .public)")

        let session = FieldSession(field: newField, engine: engine, settingsStore: settingsStore)
        session.onResult = { [weak self] in
            self?.render()
            self?.menuStatus.update()
        }
        self.session = session
        render()
        session.scheduleCheck(after: .zero)
        geometry.start(probe: { [weak self] in self?.geometryProbe() }, onChange: { [weak self] in self?.render() })
    }

    private var keepsCardOpen: Bool {
        guard let field = session?.field, rewrite.isOpen || compose.isOpen else { return false }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == field.processID
    }

    private func followTrackerFocus() {
        let current = tracker.focusedField
        if let current, let field = session?.field, current.isSameField(as: field) { return }
        focus(current)
    }

    private func clearField() {
        session?.end()
        session = nil
        settleTask?.cancel()
        geometry.stop()
        rewrite.stop()
        compose.stop()
        toneSession.reset()
        caretCardIssueID = nil
        renderer.hide()
    }

    private func ignoreReason(_ field: any TextFieldHandle) -> String {
        let settings = settingsStore.settings
        if !settings.isActive() { return "checking is off or paused" }
        if !settings.allowsApp(field.bundleID) { return "app is disabled" }
        if field.isSecure { return "secure field" }
        return "own process"
    }

    private func canCheck(_ field: any TextFieldHandle) -> Bool {
        let settings = settingsStore.settings
        return settings.isActive()
            && settings.allowsApp(field.bundleID)
            && !field.isSecure
            && field.processID != ProcessInfo.processInfo.processIdentifier
    }

    private func textDidChange() {
        guard let session, session.refreshText() else { return }
        lastTextChange = Date()
        if caretCardIssueID != nil {
            caretCardIssueID = nil
            overlay.showCard(for: nil)
        }
        render()
        session.scheduleCheck()
        if overlay.isShowingPanel {
            toneSession.update(text: session.text, settings: settingsStore.settings, after: Self.toneDebounce)
        }

        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: OverlayRenderer.typingSettle)
            guard !Task.isCancelled else { return }
            self?.render()
        }
    }

    private func render() {
        guard let session else { return }
        renderer.render(session, lastTextChange: lastTextChange)
    }

    private func geometryProbe() -> GeometryProbe? {
        guard let session else { return nil }
        let field = session.field
        return GeometryProbe(frame: field.frame(), firstIssueRects: session.issues.first.map { field.rects(for: $0.range) })
    }

    @discardableResult
    private func applyFix(_ replacement: String, to issueID: UUID) -> Bool {
        guard let session, session.applyFix(replacement, to: issueID) else { return false }
        if caretCardIssueID == issueID { caretCardIssueID = nil }
        render()
        session.scheduleCheck()
        return true
    }
}

extension AppCoordinator: FocusTrackingDelegate {
    func focusTracker(_ tracker: any FocusTracking, didFocus field: (any TextFieldHandle)?) {
        focus(field)
    }

    func focusTrackerWindowsHiddenDidChange(_ tracker: any FocusTracking) {
        menuStatus.update()
    }

    func focusTracker(_ tracker: any FocusTracking, textDidChangeIn field: any TextFieldHandle) {
        guard let current = session?.field, current.isSameField(as: field) else { return }
        textDidChange()
    }

    func focusTracker(_ tracker: any FocusTracking, selectionDidChangeIn field: any TextFieldHandle) {
        guard let session, session.field.isSameField(as: field) else { return }
        guard Date().timeIntervalSince(lastTextChange) > 0.3,
              let caret = field.selectedRange(), caret.length == 0
        else { return }
        let hit = session.issues.first { caret.location > $0.range.location && caret.location < NSMaxRange($0.range) }
        if let hit {
            caretCardIssueID = hit.id
            overlay.showCard(for: hit.id)
        } else if caretCardIssueID != nil {
            caretCardIssueID = nil
            overlay.showCard(for: nil)
        }
    }

    func focusTracker(_ tracker: any FocusTracking, geometryDidChangeFor field: any TextFieldHandle) {
        guard let current = session?.field, current.isSameField(as: field) else { return }
        render()
    }
}

extension AppCoordinator: SuggestionPresenterDelegate {
    func presenter(didAccept replacement: String, for issue: TextIssue) {
        applyFix(replacement, to: issue.id)
    }

    func presenter(didIgnore issue: TextIssue) {
        session?.ignore(issue)
        render()
    }

    func presenter(didRestore issue: TextIssue) {
        session?.restore(issue)
        render()
    }

    func presenter(didAddToDictionary issue: TextIssue) {
        let word = issue.originalText
        engine.learnWord(word)
        session?.removeSpelling(of: word)
        render()
        settingsStore.addToDictionary(word)
    }

    func presenterDidRequestFixAll() {
        for issue in session?.correctnessFixes ?? [] {
            applyFix(issue.replacements[0], to: issue.id)
        }
    }

    func presenter(didRequestRewriteWith tone: RewriteTone) {
        rewrite.request(.tone(tone))
    }

    func presenter(didRequestRewriteWithInstruction instruction: String) {
        rewrite.request(.instruction(instruction))
    }

    func presenter(didRequestRephraseSentenceOf issue: TextIssue) {
        textDidChange()
        guard let session, !session.field.isSecure, let range = session.issues.first(where: { $0.id == issue.id })?.range else {
            NSSound.beep()
            return
        }
        rewrite.rephraseSentence(around: range, in: session.field, text: session.text)
    }

    func presenter(didRequestRewriteOf scope: RewriteScope, tone: RewriteTone) {
        guard let field = session?.field else {
            NSSound.beep()
            return
        }
        rewrite.rewrite(scope, tone: tone, in: field)
    }

    func presenterDidOpenPanel() {
        toneSession.update(text: session?.text ?? "", settings: settingsStore.settings)
    }

    func presenter(didRequestCompose request: String, usesContext: Bool) {
        compose.request(request, usesContext: usesContext)
    }

    func presenter(didAcceptCompose text: String) {
        guard compose.isOpen else { return }
        compose.accept(text)
        followTrackerFocus()
    }

    func presenterDidCancelCompose() {
        compose.close()
        followTrackerFocus()
    }

    func presenter(didAcceptRewrite text: String) {
        guard rewrite.isOpen else { return }
        rewrite.accept(text)
        followTrackerFocus()
    }

    func presenterDidCancelRewrite() {
        rewrite.cancel()
        followTrackerFocus()
    }

    func presenterDidRequestDisableForCurrentApp() {
        guard let bundleID = session?.field.bundleID else { return }
        settingsStore.setApp(bundleID, disabled: true)
    }

    func presenterDidRequestSettings() {
        if case .aiUnavailable = status {
            onOpenSettings?(.ai)
        } else {
            onOpenSettings?(nil)
        }
    }

    func presenter(didChooseBadgePlacement placement: BadgePlacement, for kind: FieldKind) {
        settingsStore.update { $0.setBadgePlacement(placement, for: kind) }
    }

    func presenter(didChooseBadgeSpacing spacing: Double) {
        settingsStore.settings.badgeSpacing = spacing
    }

    func presenterDidRequestBadgeSettings() {
        onOpenSettings?(.general)
    }
}
