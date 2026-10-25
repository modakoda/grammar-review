import Testing
@testable import GrammarAccessibility

@Suite("Window exposure")
struct WindowExposureTests {
    private func changes(_ readings: [WindowExposure], in state: inout HiddenWindowsState) -> [Bool] {
        readings.map { state.record($0) }
    }

    @Test func appReturningItselfAsFocusAndWindowIsHidden() {
        #expect(WindowExposure.classify(focusedIsApp: true, focusedWindowIsApp: true) == .hidden)
    }

    @Test func realFocusedElementOrWindowIsExposed() {
        #expect(WindowExposure.classify(focusedIsApp: false, focusedWindowIsApp: nil) == .exposed)
        #expect(WindowExposure.classify(focusedIsApp: false, focusedWindowIsApp: true) == .exposed)
        #expect(WindowExposure.classify(focusedIsApp: true, focusedWindowIsApp: false) == .exposed)
    }

    @Test func appWithoutAFocusedWindowIsUnknown() {
        #expect(WindowExposure.classify(focusedIsApp: true, focusedWindowIsApp: nil) == .unknown)
    }

    @Test func hiddenAfterTwoHiddenReadingsInARow() {
        var state = HiddenWindowsState()
        #expect(changes([.hidden], in: &state) == [false])
        #expect(!state.isHidden)
        #expect(changes([.hidden, .hidden], in: &state) == [true, false])
        #expect(state.isHidden)
    }

    @Test func unknownReadingsChangeNothing() {
        var state = HiddenWindowsState()
        #expect(changes([.hidden, .unknown, .hidden, .unknown], in: &state) == [false, false, true, false])
        #expect(state.isHidden)
    }

    @Test func anExposedReadingRestartsTheCount() {
        var state = HiddenWindowsState()
        #expect(changes([.hidden, .exposed, .hidden], in: &state) == [false, false, false])
        #expect(!state.isHidden)
    }

    @Test func visibleAgainAfterTwoExposedReadingsInARow() {
        var state = HiddenWindowsState()
        _ = changes([.hidden, .hidden], in: &state)
        #expect(changes([.exposed, .hidden, .exposed], in: &state) == [false, false, false])
        #expect(state.isHidden)
        #expect(changes([.exposed], in: &state) == [true])
        #expect(!state.isHidden)
    }

    @Test func resetReportsWhetherItWasHidden() {
        var state = HiddenWindowsState()
        var changed = state.reset()
        #expect(!changed)
        _ = changes([.hidden, .hidden], in: &state)
        changed = state.reset()
        #expect(changed)
        #expect(!state.isHidden)
        #expect(changes([.hidden], in: &state) == [false])
    }
}
