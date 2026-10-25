import CoreGraphics
import Testing
@testable import GrammarOverlay

@Suite struct PanelLayoutTests {
    @Test func shortContentIsShownInFull() {
        #expect(PanelLayout.listHeight(header: 40, rows: 120, footer: 36, maxHeight: 420) == 120)
    }

    @Test func longContentIsCappedSoThePanelFitsMaxHeight() {
        let expected: CGFloat = 420 - 40 - 36
        #expect(PanelLayout.listHeight(header: 40, rows: 2000, footer: 36, maxHeight: 420) == expected)
    }

    @Test func listNeverCollapsesBelowTheMinimum() {
        #expect(PanelLayout.listHeight(header: 200, rows: 500, footer: 200, maxHeight: 300, minListHeight: 60) == 60)
        #expect(PanelLayout.listHeight(header: 200, rows: 30, footer: 200, maxHeight: 300, minListHeight: 60) == 30)
    }

    @Test func widensForWideContentWithinLimits() {
        #expect(PanelLayout.width(content: 0, available: 1_000) == OverlayMetrics.panelWidth)
        #expect(PanelLayout.width(content: 383.2, available: 1_000) == 384)
        #expect(PanelLayout.width(content: 900, available: 1_000) == OverlayMetrics.panelMaxWidth)
        #expect(PanelLayout.width(content: 900, available: 400) == 400, "never wider than the screen")
        #expect(PanelLayout.width(content: 900, available: 200) == OverlayMetrics.panelWidth)
    }
}
