import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("Change de-duplication")
struct FieldStateTrackerTests {
    private let frame = CGRect(x: 10, y: 10, width: 200, height: 40)

    @Test func unchangedValuesReportNothing() {
        var state = FieldStateTracker()
        state.reset(text: "hello", selection: NSRange(location: 5, length: 0), frame: frame)
        let changes = state.update(text: "hello", selection: NSRange(location: 5, length: 0), frame: frame)
        #expect(changes.isEmpty)
    }

    @Test func eachKindOfChangeIsReported() {
        var state = FieldStateTracker()
        state.reset(text: "hello", selection: NSRange(location: 5, length: 0), frame: frame)
        let typed = state.update(text: "hello!", selection: NSRange(location: 6, length: 0), frame: frame)
        #expect(typed == [.text, .selection])
        let moved = state.update(text: "hello!", selection: NSRange(location: 6, length: 0), frame: frame.offsetBy(dx: 0, dy: 30))
        #expect(moved == [.geometry])
    }

    @Test func changeSeenByANotificationIsNotReportedAgainByThePoll() {
        var state = FieldStateTracker()
        state.reset(text: "a", selection: NSRange(location: 1, length: 0), frame: frame)
        let notified = state.updateText("ab")
        #expect(notified)
        let polled = state.update(text: "ab", selection: NSRange(location: 1, length: 0), frame: frame)
        #expect(polled.isEmpty)
    }

    @Test func unreadableValuesAreNotChanges() {
        var state = FieldStateTracker()
        state.reset(text: "a", selection: NSRange(location: 1, length: 0), frame: frame)
        let changes = state.update(text: nil, selection: nil, frame: nil)
        #expect(changes.isEmpty)
        #expect(state.text == "a")
    }

    @Test func frameJitterIsIgnored() {
        var state = FieldStateTracker()
        state.reset(frame: frame)
        let jitter = state.updateFrame(frame.offsetBy(dx: 0.2, dy: -0.2))
        #expect(!jitter)
        let grew = state.updateFrame(frame.insetBy(dx: 0, dy: -2))
        #expect(grew)
    }

    @Test func scrollingOutOfViewIsAGeometryChange() {
        var state = FieldStateTracker()
        state.reset(frame: frame)
        let hidden = state.updateFrame(.null)
        let stillHidden = state.updateFrame(.null)
        let shownAgain = state.updateFrame(frame)
        #expect(hidden)
        #expect(!stillHidden)
        #expect(shownAgain)
    }

    @Test func firstValuesAfterAnEmptyResetAreChanges() {
        var state = FieldStateTracker()
        state.reset()
        let changes = state.update(text: "", selection: NSRange(location: 0, length: 0), frame: frame)
        #expect(changes == [.text, .selection, .geometry])
    }
}
