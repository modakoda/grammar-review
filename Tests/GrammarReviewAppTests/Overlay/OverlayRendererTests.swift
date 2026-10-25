import CoreGraphics
import Foundation
import GrammarAppUI
import GrammarEngine
import GrammarModels
import Testing
@testable import GrammarReviewApp

@MainActor
@Suite(.timeLimit(.minutes(1))) struct OverlayRendererTests {
    private func makeRenderer(_ overlay: FakeOverlay, _ store: SettingsStore, tone: ToneSession? = nil) -> OverlayRenderer {
        OverlayRenderer(overlay: overlay, settingsStore: store, toneSession: tone ?? ToneSession(detector: FakeToneDetector()))
    }

    @Test func describesTheFieldItsSuggestionsAndTheBadgeSettings() async throws {
        try await withSettings { store in
            store.update {
                $0.inputBadgePlacement = .below
                $0.textAreaBadgePlacement = .insideTopLeft
                $0.badgeSpacing = 16
            }
            let issues = [issue(2, "has", .grammar, source: .ai), issue(6, "teh")]
            let h = SessionHarness("I has teh cat.", settings: store, respond: answering(issues, .failed("You're offline")))
            try await h.check()
            h.session.ignore(h.session.issues[1])
            h.field.isSingleLine = true
            let overlay = FakeOverlay()
            let renderer = makeRenderer(overlay, store)
            renderer.render(h.session, lastTextChange: .distantPast)

            let state = try #require(overlay.states.last)
            #expect(state.fieldFrame == FakeField.defaultFrame)
            #expect(state.isSingleLine)
            #expect(state.issues.map(\.issue.originalText) == ["has"])
            #expect(state.issues.map(\.rects) == [[FakeField.rect(for: NSRange(location: 2, length: 3))]])
            #expect(state.ignoredIssues.map(\.originalText) == ["teh"])
            #expect(state.status == .aiUnavailable("You're offline"))
            #expect(state.appName == "TextEdit")
            #expect(state.showBadge)
            #expect(state.badgePlacement == .below, "the placement for input fields")
            #expect(state.badgeSpacing == 16)
            #expect(state.offersRewrite)
            #expect(state.tone == nil && !state.isDetectingTone)

            h.field.isSingleLine = false
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.last?.badgePlacement == .insideTopLeft, "the placement for text areas")

            store.update { $0.aiEnabled = false }
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.last?.offersRewrite == false, "no rewrites with AI off")
        }
    }

    @Test func anUnchangedStateIsNotSentAgain() async throws {
        try await withSettings { store in
            let h = SessionHarness("I has a cat.", settings: store, respond: answering([issue(2, "has", .grammar, source: .ai)]))
            try await h.check()
            let overlay = FakeOverlay()
            let renderer = makeRenderer(overlay, store)
            renderer.render(h.session, lastTextChange: .distantPast)
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.count == 1)
            #expect(renderer.isShowing)

            renderer.forgetLastState()
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.count == 2)
        }
    }

    @Test func aBlankOrHiddenFieldHidesTheOverlayOnce() async throws {
        try await withSettings { store in
            let h = SessionHarness("Some text.", settings: store, respond: answering([]))
            try await h.check()
            let overlay = FakeOverlay()
            let renderer = makeRenderer(overlay, store)
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.count == 1)

            h.field.fieldFrame = nil
            renderer.render(h.session, lastTextChange: .distantPast)
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.hides == 1)
            #expect(!renderer.isShowing)

            h.field.fieldFrame = FakeField.defaultFrame
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.count == 2)

            h.field.text = " \n "
            #expect(h.session.refreshText())
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.hides == 2)

            renderer.hide()
            #expect(overlay.hides == 3)
            #expect(!renderer.isShowing)
        }
    }

    @Test func aMisspellingBeingTypedIsHiddenUntilTypingSettles() async throws {
        try await withSettings { store in
            let issues = [issue(2, "like", .grammar, source: .ai), issue(7, "teh")]
            let h = SessionHarness("I like teh", settings: store, respond: answering(issues))
            try await h.check()
            let overlay = FakeOverlay()
            let renderer = makeRenderer(overlay, store)
            @MainActor func shown(_ selection: NSRange, typedAt lastTextChange: Date) -> [String] {
                h.field.selection = selection
                renderer.render(h.session, lastTextChange: lastTextChange)
                return overlay.states.last?.issues.map(\.issue.originalText) ?? []
            }
            let caretAtEnd = NSRange(location: 10, length: 0)
            #expect(shown(caretAtEnd, typedAt: Date()) == ["like"])
            #expect(shown(NSRange(location: 4, length: 0), typedAt: Date()) == ["like", "teh"], "only local spelling is hidden")
            #expect(shown(caretAtEnd, typedAt: Date()) == ["like"])
            #expect(shown(caretAtEnd, typedAt: .distantPast) == ["like", "teh"], "typing has settled")
            #expect(shown(caretAtEnd, typedAt: Date()) == ["like"])
            #expect(shown(NSRange(location: 7, length: 3), typedAt: Date()) == ["like", "teh"], "a selection isn't typing")
        }
    }

    @Test func onlyTheFirstSuggestionsAreUnderlined() async throws {
        try await withSettings { store in
            let count = OverlayRenderer.maxPositionedIssues + 20
            let issues = (0..<count).map { issue($0 * 4, "teh") }
            let h = SessionHarness(String(repeating: "teh ", count: count), settings: store, respond: answering(issues))
            try await h.check()
            let overlay = FakeOverlay()
            makeRenderer(overlay, store).render(h.session, lastTextChange: .distantPast)

            let state = try #require(overlay.states.last)
            #expect(state.issues.count == count, "the badge and panel still list them all")
            let underlined = state.issues.map { !$0.rects.isEmpty }
            #expect(underlined == Array(repeating: true, count: OverlayRenderer.maxPositionedIssues) + Array(repeating: false, count: 20))
            #expect(h.field.rectRequests.count == OverlayRenderer.maxPositionedIssues)
        }
    }

    @Test func theToneAndItsProgressAreShown() async throws {
        try await withSettings { store in
            let text = "We are happy to share the news with you today."
            let h = SessionHarness(text, settings: store, respond: answering([]))
            try await h.check()
            let tone = ToneSession(detector: FakeToneDetector())
            let overlay = FakeOverlay()
            let renderer = makeRenderer(overlay, store, tone: tone)

            tone.update(text: text, settings: store.settings)
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.last?.isDetectingTone == true)
            #expect(overlay.states.last?.tone == nil)

            try await waitUntil { !tone.isDetecting }
            renderer.render(h.session, lastTextChange: .distantPast)
            #expect(overlay.states.last?.isDetectingTone == false)
            #expect(overlay.states.last?.tone == FakeToneDetector.report)
        }
    }
}
