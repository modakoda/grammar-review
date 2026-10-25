import Foundation

nonisolated struct HoverStateMachine: Equatable, Sendable {
    enum Owner: Equatable, Sendable {
        case hover
        case caret
    }

    var showDelay: TimeInterval = OverlayMetrics.hoverShowDelay
    var hideDelay: TimeInterval = OverlayMetrics.hoverHideDelay

    private(set) var cardIssueID: UUID?
    private(set) var owner: Owner?
    private(set) var pointerIssueID: UUID?
    private(set) var pointerOverCard = false
    private var restingSince: TimeInterval?
    private var leftSince: TimeInterval?

    init(showDelay: TimeInterval = OverlayMetrics.hoverShowDelay, hideDelay: TimeInterval = OverlayMetrics.hoverHideDelay) {
        self.showDelay = showDelay
        self.hideDelay = hideDelay
    }

    var isHoverCardOpen: Bool { cardIssueID != nil && owner == .hover }

    var nextDeadline: TimeInterval? {
        let show = restingSince.map { $0 + showDelay }
        let hide = (owner == .hover) ? leftSince.map { $0 + hideDelay } : nil
        switch (show, hide) {
        case let (s?, h?): return min(s, h)
        case let (s?, nil): return s
        case let (nil, h?): return h
        case (nil, nil): return nil
        }
    }

    mutating func pointerMoved(overIssue issueID: UUID?, overCard: Bool, at now: TimeInterval) {
        pointerOverCard = overCard && cardIssueID != nil
        if pointerOverCard {
            pointerIssueID = nil
            restingSince = nil
            leftSince = nil
            return
        }

        if issueID != pointerIssueID {
            pointerIssueID = issueID
            restingSince = (issueID != nil && issueID != cardIssueID) ? now : nil
        }

        if let issueID, issueID == cardIssueID {
            restingSince = nil
            leftSince = nil
        } else if owner == .hover, cardIssueID != nil, leftSince == nil {
            leftSince = now
        }
    }

    mutating func advance(to now: TimeInterval) {
        if let since = restingSince, let issueID = pointerIssueID, now >= since + showDelay {
            cardIssueID = issueID
            owner = .hover
            restingSince = nil
            leftSince = nil
        }
        if owner == .hover, let left = leftSince, now >= left + hideDelay {
            close()
        }
    }

    mutating func showFromCaret(_ issueID: UUID?) {
        if let issueID {
            cardIssueID = issueID
            owner = .caret
            restingSince = nil
            leftSince = nil
            return
        }
        guard cardIssueID != nil else { return }
        if pointerOverCard {
            owner = .hover
            return
        }
        close()
    }

    mutating func close() {
        cardIssueID = nil
        owner = nil
        restingSince = nil
        leftSince = nil
        pointerOverCard = false
        pointerIssueID = nil
    }

    mutating func issuesChanged(present: Set<UUID>, underlined: Set<UUID>) {
        if let card = cardIssueID {
            let keep = owner == .caret ? present.contains(card) : underlined.contains(card)
            if !keep { close() }
        }
        if let pointer = pointerIssueID, !underlined.contains(pointer) {
            pointerIssueID = nil
            restingSince = nil
        }
    }

    mutating func reset() {
        self = HoverStateMachine(showDelay: showDelay, hideDelay: hideDelay)
    }
}
