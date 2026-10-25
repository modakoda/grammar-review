import AppKit
import GrammarModels

public final class OverlayController: SuggestionPresenting {
    public weak var delegate: (any SuggestionPresenterDelegate)?

    public init() {
        screenTracker.onChange = { [weak self] in self?.screensDidChange() }
    }

    private var state: OverlayState?
    private var segments: [UnderlineSegment] = []
    private var hover = HoverStateMachine()
    private var layoutIsStale = false

    lazy var actions = makeActions()
    private let underlines = UnderlinePresenter()
    private lazy var badge = BadgePresenter(actions: actions)
    private lazy var card = SuggestionCardPresenter(actions: actions)
    private lazy var suggestionsPanel = SuggestionsPanelPresenter(actions: actions)
    lazy var rewriteCard = RewriteCardPresenter(actions: actions)
    lazy var composeCard = ComposeCardPresenter(actions: actions)

    let screenTracker = ScreenTracker()
    private lazy var hoverWakeup = DeadlineTimer { [weak self] in self?.pointerDidMove() }
    private lazy var moveMonitor = EventMonitor(matching: .mouseMoved) { [weak self] in self?.pointerDidMove() }
    private lazy var downMonitor = EventMonitor(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] in
        self?.mouseDidGoDown()
    }

    var pointerLocation: () -> CGPoint = { NSEvent.mouseLocation }

    private var screens: [ScreenLayout] { screenTracker.screens }

    public func update(_ newState: OverlayState) {
        screenTracker.refreshIfNeeded()
        guard newState != state || layoutIsStale else { return }
        state = newState
        layoutIsStale = false

        segments = UnderlineLayout.segments(for: newState.issues, fieldFrame: newState.fieldFrame)
        Log.overlay.debug("Update: \(newState.issues.count, privacy: .public) issues, \(self.segments.count, privacy: .public) underline segments, badge \(newState.showBadge && newState.fieldFrame.isDrawable, privacy: .public)")
        hover.issuesChanged(
            present: Set(newState.issues.map(\.id)),
            underlined: Set(segments.map(\.issueID))
        )

        underlines.render(segments, fieldFrame: newState.fieldFrame, active: activeIssueIDs)
        renderBadge()
        renderCard()
        renderPanel()
        updateMonitors()
        scheduleHoverWakeup()
    }

    public func showCard(for issueID: UUID?) {
        screenTracker.refreshIfNeeded()
        let before = hover
        hover.showFromCaret(issueID)
        if hover != before { hoverDidChange() }
    }

    public var isShowingPanel: Bool { suggestionsPanel.isOpen }

    public func togglePanel() {
        if suggestionsPanel.isOpen {
            closePanel()
        } else {
            openPanel()
        }
    }

    public func showRewrite(_ newState: RewriteState?) {
        guard let newState else {
            rewriteCard.dismiss()
            updateMonitors()
            return
        }
        screenTracker.refreshIfNeeded()
        if !rewriteCard.isPresented {
            closeCard()
            closePanel()
        }
        rewriteCard.show(newState, screens: screens)
        updateMonitors()
    }

    public func showCompose(_ newState: ComposeState?) {
        guard let newState else {
            composeCard.dismiss()
            updateMonitors()
            return
        }
        screenTracker.refreshIfNeeded()
        let isNew = !composeCard.isPresented
        if isNew {
            closeCard()
            closePanel()
            rewriteCard.dismiss()
        }
        composeCard.show(newState, screens: screens, takesKeyboard: isNew)
        updateMonitors()
    }

    public func hideAll() {
        state = nil
        segments = []
        hover.reset()
        hoverWakeup.cancel()
        underlines.hide()
        badge.hide()
        card.hide(animated: false)
        suggestionsPanel.hide()
        rewriteCard.hide()
        composeCard.dismiss()
        moveMonitor.stop()
        downMonitor.stop()
    }

    func closePanel() {
        guard suggestionsPanel.close() else { return }
        updateMonitors()
    }

    func closeCard(ifShowing issue: TextIssue) {
        guard hover.cardIssueID == issue.id else { return }
        closeCard()
    }

    func pointerDidMove() {
        let now = ProcessInfo.processInfo.systemUptime
        let point = pointerLocation()
        let before = hover

        let overCard = card.panel?.presentedFrame.map {
            $0.insetBy(dx: -OverlayMetrics.cardHoverSlack, dy: -OverlayMetrics.cardHoverSlack).containsInclusive(point)
        } ?? false
        let overOtherOverlay = [badge.panel, suggestionsPanel.panel, rewriteCard.panel]
            .contains { $0?.presentedFrame?.containsInclusive(point) == true }
        let issueID = (overCard || overOtherOverlay) ? nil : HoverHitTest.issueID(at: point, in: segments)

        hover.pointerMoved(overIssue: issueID, overCard: overCard, at: now)
        hover.advance(to: now)
        if hover != before {
            hoverDidChange()
        } else {
            scheduleHoverWakeup()
        }
    }

    func mouseDidGoDown() {
        let point = pointerLocation()
        let isInside = { (panels: [OverlayPanel?]) in
            panels.contains { $0?.presentedFrame?.containsInclusive(point) == true }
        }
        if !isInside([suggestionsPanel.panel, badge.panel, card.panel, rewriteCard.panel, composeCard.panel]) {
            if rewriteCard.isPresented { actions.cancelRewrite() }
            if composeCard.isPresented { actions.cancelCompose() }
        }
        if suggestionsPanel.isOpen, !isInside([suggestionsPanel.panel, badge.panel, card.panel, rewriteCard.panel]) {
            closePanel()
        }
        if hover.isHoverCardOpen,
           card.panel?.presentedFrame?.containsInclusive(point) != true,
           HoverHitTest.issueID(at: point, in: segments) != hover.cardIssueID {
            closeCard()
        }
    }

    private var activeIssueIDs: Set<UUID> {
        Set([hover.pointerIssueID, hover.cardIssueID].compactMap(\.self))
    }

    private func renderBadge() {
        guard let state, state.showBadge, state.fieldFrame.isDrawable else {
            badge.hide()
            return
        }
        badge.render(state, circle: badgeCircle(for: state))
    }

    private func renderCard() {
        guard let issueID = hover.cardIssueID,
              let issue = state?.issues.first(where: { $0.id == issueID })?.issue,
              let anchor = HoverHitTest.anchorRect(for: issueID, in: segments)
        else {
            card.hide(animated: true)
            return
        }
        card.show(issue, anchor: anchor, offersRewrite: state?.offersRewrite ?? true, screens: screens)
    }

    private func renderPanel() {
        let anchor = panelAnchor()
        suggestionsPanel.render(state, anchor: anchor.rect, alignment: anchor.alignment, screens: screens)
    }

    private func panelAnchor() -> (rect: CGRect, alignment: PopoverAlignment) {
        if let state, state.fieldFrame.isDrawable {
            let circle = badgeCircle(for: state)
            return (circle, circle.midX < state.fieldFrame.midX ? .leading : .trailing)
        }
        let mouse = pointerLocation()
        return (CGRect(x: mouse.x, y: mouse.y, width: 1, height: 1), .trailing)
    }

    private func badgeCircle(for state: OverlayState) -> CGRect {
        BadgeLayout.circleFrame(
            fieldFrame: state.fieldFrame,
            isSingleLine: state.isSingleLine,
            placement: state.badgePlacement,
            screens: screens,
            gap: state.badgeSpacing
        )
    }

    private func openPanel() {
        screenTracker.refreshIfNeeded()
        closeCard()
        let anchor = panelAnchor()
        suggestionsPanel.open(state, anchor: anchor.rect, alignment: anchor.alignment, screens: screens)
        updateMonitors()
        delegate?.presenterDidOpenPanel()
    }

    private func closeCard() {
        let before = hover
        hover.close()
        if hover != before { hoverDidChange() }
    }

    private func hoverDidChange() {
        renderCard()
        underlines.emphasize(activeIssueIDs)
        updateMonitors()
        scheduleHoverWakeup()
    }

    private func scheduleHoverWakeup() {
        let now = ProcessInfo.processInfo.systemUptime
        var deadline = hover.nextDeadline
        if hover.isHoverCardOpen {
            let poll = now + OverlayMetrics.hoverPollInterval
            deadline = min(deadline ?? poll, poll)
        }
        guard let deadline else {
            hoverWakeup.cancel()
            return
        }
        hoverWakeup.schedule(at: deadline, now: now)
    }

    private func updateMonitors() {
        if !segments.isEmpty || hover.cardIssueID != nil {
            moveMonitor.start()
        } else if moveMonitor.isRunning {
            moveMonitor.stop()
            hoverWakeup.cancel()
        }

        if suggestionsPanel.isOpen || hover.isHoverCardOpen || rewriteCard.isPresented || composeCard.isPresented {
            downMonitor.start()
        } else {
            downMonitor.stop()
        }
    }

    private func screensDidChange() {
        layoutIsStale = true
        if let state { update(state) }
        if let rewrite = rewriteCard.state, rewriteCard.isPresented { showRewrite(rewrite) }
        if let compose = composeCard.state, composeCard.isPresented { showCompose(compose) }
    }
}
