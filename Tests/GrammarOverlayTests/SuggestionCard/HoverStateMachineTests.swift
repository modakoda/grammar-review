import Foundation
import Testing
@testable import GrammarOverlay

@Suite struct HoverStateMachineTests {
    let a = UUID()
    let b = UUID()
    let show = OverlayMetrics.hoverShowDelay
    let hide = OverlayMetrics.hoverHideDelay

    func hoverCardOpenForA() -> HoverStateMachine {
        var machine = HoverStateMachine()
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.advance(to: 1 + show)
        return machine
    }

    @Test func restingOnAnUnderlineOpensTheCardAfterTheDelay() {
        var machine = HoverStateMachine()
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        #expect(machine.cardIssueID == nil)
        #expect(machine.pointerIssueID == a)
        #expect(machine.nextDeadline == 1 + show)

        machine.advance(to: 1 + show / 2)
        #expect(machine.cardIssueID == nil)

        machine.pointerMoved(overIssue: a, overCard: false, at: 1 + show / 2)
        machine.advance(to: 1 + show)
        #expect(machine.cardIssueID == a)
        #expect(machine.owner == .hover)
        #expect(machine.isHoverCardOpen)
    }

    @Test func passingOverAnUnderlineDoesNotOpenACard() {
        var machine = HoverStateMachine()
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.pointerMoved(overIssue: nil, overCard: false, at: 1.05)
        machine.advance(to: 2)
        #expect(machine.cardIssueID == nil)
        #expect(machine.nextDeadline == nil)
    }

    @Test func hoverCardHidesAfterThePointerLeaves() {
        var machine = hoverCardOpenForA()
        machine.pointerMoved(overIssue: nil, overCard: false, at: 2)
        #expect(machine.cardIssueID == a)
        #expect(machine.nextDeadline == 2 + hide)
        machine.advance(to: 2 + hide - 0.01)
        #expect(machine.cardIssueID == a)
        machine.advance(to: 2 + hide)
        #expect(machine.cardIssueID == nil)
        #expect(machine.owner == nil)
    }

    @Test func returningBeforeTheHideDelayKeepsTheCard() {
        var machine = hoverCardOpenForA()
        machine.pointerMoved(overIssue: nil, overCard: false, at: 2)
        machine.pointerMoved(overIssue: a, overCard: false, at: 2.1)
        machine.advance(to: 3)
        #expect(machine.cardIssueID == a)
    }

    @Test func movingOntoTheCardKeepsItAndLeavingTheCardHidesIt() {
        var machine = hoverCardOpenForA()
        machine.pointerMoved(overIssue: nil, overCard: false, at: 2)
        machine.pointerMoved(overIssue: nil, overCard: true, at: 2.05)
        #expect(machine.pointerOverCard)
        machine.advance(to: 5)
        #expect(machine.cardIssueID == a)

        machine.pointerMoved(overIssue: nil, overCard: false, at: 6)
        machine.advance(to: 6 + hide)
        #expect(machine.cardIssueID == nil)
    }

    @Test func restingOnAnotherIssueReplacesTheHoverCard() {
        var machine = hoverCardOpenForA()
        machine.pointerMoved(overIssue: b, overCard: false, at: 2)
        machine.advance(to: 2 + show)
        #expect(machine.cardIssueID == b)
        #expect(machine.owner == .hover)
    }

    @Test func caretCardOpensImmediatelyAndIgnoresThePointerLeaving() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        #expect(machine.cardIssueID == a)
        #expect(machine.owner == .caret)
        #expect(!machine.isHoverCardOpen)

        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.pointerMoved(overIssue: nil, overCard: false, at: 2)
        machine.advance(to: 10)
        #expect(machine.cardIssueID == a)
        #expect(machine.nextDeadline == nil)
    }

    @Test func hoveringTheCaretIssueKeepsItACaretCard() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.advance(to: 2)
        #expect(machine.owner == .caret)
    }

    @Test func newerHoverReplacesACaretCard() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        machine.pointerMoved(overIssue: b, overCard: false, at: 1)
        machine.advance(to: 1 + show)
        #expect(machine.cardIssueID == b)
        #expect(machine.owner == .hover)
    }

    @Test func caretRequestReplacesAHoverCard() {
        var machine = hoverCardOpenForA()
        machine.showFromCaret(b)
        #expect(machine.cardIssueID == b)
        #expect(machine.owner == .caret)
    }

    @Test func caretNilClosesAnyCard() {
        var caret = HoverStateMachine()
        caret.showFromCaret(a)
        caret.showFromCaret(nil)
        #expect(caret.cardIssueID == nil)

        var hover = hoverCardOpenForA()
        hover.showFromCaret(nil)
        #expect(hover.cardIssueID == nil)
        hover.pointerMoved(overIssue: a, overCard: false, at: 3)
        #expect(hover.cardIssueID == nil)
        hover.advance(to: 3 + show)
        #expect(hover.cardIssueID == a)
    }

    @Test func caretNilWhileThePointerIsOnTheCardHandsItToHover() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        machine.pointerMoved(overIssue: nil, overCard: true, at: 1)
        machine.showFromCaret(nil)
        #expect(machine.cardIssueID == a)
        #expect(machine.owner == .hover)

        machine.pointerMoved(overIssue: nil, overCard: false, at: 2)
        machine.advance(to: 2 + hide)
        #expect(machine.cardIssueID == nil)
    }

    @Test func caretNilWithNothingOpenIsANoOp() {
        var machine = HoverStateMachine()
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.showFromCaret(nil)
        machine.advance(to: 1 + show)
        #expect(machine.cardIssueID == a)
    }

    @Test func cardClosesWhenItsIssueDisappears() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        machine.issuesChanged(present: [a, b], underlined: [a, b])
        #expect(machine.cardIssueID == a)
        machine.issuesChanged(present: [b], underlined: [b])
        #expect(machine.cardIssueID == nil)
    }

    @Test func caretCardSurvivesItsIssueScrollingOutOfView() {
        var machine = HoverStateMachine()
        machine.showFromCaret(a)
        machine.issuesChanged(present: [a], underlined: [])
        #expect(machine.cardIssueID == a)
    }

    @Test func hoverCardClosesWhenItsIssueIsNoLongerUnderlined() {
        var machine = hoverCardOpenForA()
        machine.issuesChanged(present: [a], underlined: [])
        #expect(machine.cardIssueID == nil)
    }

    @Test func pendingHoverIsDroppedWhenTheIssueGoes() {
        var machine = HoverStateMachine()
        machine.pointerMoved(overIssue: a, overCard: false, at: 1)
        machine.issuesChanged(present: [b], underlined: [b])
        #expect(machine.pointerIssueID == nil)
        machine.advance(to: 2)
        #expect(machine.cardIssueID == nil)
    }

    @Test func closeAndReset() {
        var machine = hoverCardOpenForA()
        machine.close()
        #expect(machine.cardIssueID == nil)
        #expect(machine.pointerIssueID == nil)

        var other = HoverStateMachine()
        other.showFromCaret(a)
        other.pointerMoved(overIssue: b, overCard: false, at: 1)
        other.reset()
        #expect(other == HoverStateMachine())
    }

    @Test func deadlineIsTheEarlierOfShowAndHide() {
        var machine = hoverCardOpenForA()
        machine.pointerMoved(overIssue: b, overCard: false, at: 2)
        #expect(machine.nextDeadline == 2 + min(show, hide))
    }
}
