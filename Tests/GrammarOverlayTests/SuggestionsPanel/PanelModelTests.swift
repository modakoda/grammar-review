import CoreGraphics
import GrammarModels
import Testing
@testable import GrammarOverlay

@MainActor
@Suite struct PanelModelTests {
    private func state(_ issues: [TextIssue], status: CheckStatus = .done) -> OverlayState {
        OverlayState(fieldFrame: CGRect(x: 100, y: 100, width: 400, height: 200), issues: issues.map { positioned($0) },
                     status: status, appName: "Notes", showBadge: true)
    }

    @Test func reportsAChangeOnlyWhenWhatItShowsChanges() {
        let model = PanelModel()
        let issue = makeIssue()
        #expect(model.update(from: state([issue])))
        #expect(!model.update(from: state([issue])))

        var moved = state([issue])
        moved.fieldFrame = CGRect(x: 300, y: 300, width: 400, height: 200)
        moved.badgePlacement = .right
        #expect(!model.update(from: moved), "the panel shows neither the field's frame nor the badge")

        #expect(model.update(from: state([issue], status: .checking)))
        #expect(model.isChecking)
        var detecting = state([issue], status: .checking)
        detecting.isDetectingTone = true
        #expect(model.update(from: detecting))
        #expect(model.isDetectingTone)
    }

    @Test func withoutAFieldThePanelIsEmpty() {
        let model = PanelModel()
        var full = state([makeIssue()], status: .aiUnavailable("You're offline"))
        full.ignoredIssues = [makeIssue()]
        full.offersRewrite = false
        full.tone = ToneReport(tones: [ToneScore(tone: .friendly, intensity: .moderate)], sentiment: .positive, summary: "")
        _ = model.update(from: full)
        #expect(model.aiUnavailableMessage == "You're offline")
        #expect(!model.offersRewrite)
        #expect(model.appName == "Notes")

        #expect(model.update(from: nil))
        #expect(model.issues.isEmpty && model.ignored.isEmpty && model.tone == nil && model.appName == nil)
        #expect(model.status == .done && model.aiUnavailableMessage == nil)
        #expect(model.offersRewrite)
    }

    @Test func showingEveryRewriteStyleResizesThePanel() {
        let model = PanelModel()
        var resized = 0
        model.contentSizeDidChange = { resized += 1 }
        model.toggleRewriteStyles()
        #expect(model.showsAllRewriteStyles && resized == 1)
        model.toggleRewriteStyles()
        #expect(!model.showsAllRewriteStyles && resized == 2)
    }
}
