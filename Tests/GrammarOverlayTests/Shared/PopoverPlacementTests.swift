import CoreGraphics
import Testing
@testable import GrammarOverlay

@Suite struct PopoverPlacementTests {
    let size = CGSize(width: 300, height: 120)
    let gap = OverlayMetrics.anchorGap
    let margin = OverlayMetrics.screenMargin

    @Test func placesBelowTheAnchorAlignedToItsLeftEdge() {
        let anchor = CGRect(x: 200, y: 500, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen])
        #expect(placement.edge == .below)
        #expect(placement.frame == CGRect(x: 200, y: 500 - gap - 120, width: 300, height: 120))
    }

    @Test func flipsAboveWhenThereIsNoRoomBelow() {
        let anchor = CGRect(x: 200, y: 120, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen])
        #expect(placement.edge == .above)
        #expect(placement.frame.minY == anchor.maxY + gap)
        #expect(placement.frame.height == 120)
    }

    @Test func staysBelowWhenItExactlyFits() {
        let bottom = primaryScreen.visibleFrame.minY + margin
        let anchor = CGRect(x: 200, y: bottom + 120 + gap, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen])
        #expect(placement.edge == .below)
        #expect(placement.frame.minY == bottom)
    }

    @Test func clampsToTheRightEdgeOfTheVisibleFrame() {
        let anchor = CGRect(x: 1300, y: 500, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen])
        #expect(placement.frame.maxX == primaryScreen.visibleFrame.maxX - margin)
        #expect(placement.frame.width == 300)
    }

    @Test func clampsToTheLeftEdgeOfTheVisibleFrame() {
        let anchor = CGRect(x: -50, y: 500, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen])
        #expect(placement.frame.minX == primaryScreen.visibleFrame.minX + margin)
    }

    @Test func trailingAlignmentLinesUpRightEdges() {
        let anchor = CGRect(x: 700, y: 500, width: 22, height: 22)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen], alignment: .trailing)
        #expect(placement.frame.maxX == anchor.maxX)
        #expect(placement.edge == .below)
    }

    @Test func whenNeitherSideFitsTakesTheRoomierSideAndClamps() {
        let tall = CGSize(width: 300, height: 700)
        let anchor = CGRect(x: 200, y: 600, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: tall, anchor: anchor, screens: [primaryScreen])
        let bounds = primaryScreen.visibleFrame.insetBy(dx: margin, dy: margin)
        #expect(placement.edge == .below)
        #expect(placement.frame.minY == bounds.minY)
        #expect(placement.frame.maxY <= bounds.maxY)
    }

    @Test func shrinksAPopoverTallerThanTheScreen() {
        let huge = CGSize(width: 300, height: 2000)
        let anchor = CGRect(x: 200, y: 400, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: huge, anchor: anchor, screens: [primaryScreen])
        let bounds = primaryScreen.visibleFrame.insetBy(dx: margin, dy: margin)
        #expect(placement.frame.height == bounds.height)
        #expect(bounds.contains(placement.frame))
    }

    @Test func usesTheVisibleFrameOfTheAnchorsScreen() {
        let anchor = CGRect(x: 2000, y: 130, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen, rightScreen])
        #expect(placement.edge == .below)
        #expect(placement.frame.minY == 130 - gap - 120)
        #expect(rightScreen.visibleFrame.contains(placement.frame))
    }

    @Test func clampsToTheAnchorsScreenNotThePrimaryOne() {
        let anchor = CGRect(x: 1400, y: 500, width: 30, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [primaryScreen, rightScreen])
        #expect(placement.frame.maxX == primaryScreen.visibleFrame.maxX - margin)
    }

    @Test func withoutScreensPlacesBelowUnclamped() {
        let anchor = CGRect(x: -500, y: 10, width: 40, height: 18)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: [])
        #expect(placement.edge == .below)
        #expect(placement.frame == CGRect(x: -500, y: 10 - gap - 120, width: 300, height: 120))
    }
}
