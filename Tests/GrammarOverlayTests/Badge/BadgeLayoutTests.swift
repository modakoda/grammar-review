import CoreGraphics
import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct BadgeLayoutTests {
    let d = OverlayMetrics.badgeDiameter
    let inset = OverlayMetrics.badgeInset

    @Test func sitsInsideTheBottomRightCornerOfTheField() {
        let field = CGRect(x: 100, y: 300, width: 500, height: 200)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        #expect(circle == CGRect(x: 600 - inset - d, y: 300 + inset, width: d, height: d))
    }

    @Test func isVerticallyCentredInASingleLineField() {
        let field = CGRect(x: 100, y: 300, width: 500, height: 24)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        #expect(circle.midY == field.midY)
        #expect(circle.maxX == field.maxX - inset)
    }

    @Test func isHorizontallyCentredInAVeryNarrowField() {
        let field = CGRect(x: 100, y: 300, width: 20, height: 200)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        #expect(circle.midX == field.midX)
    }

    @Test func staysOnScreenWhenTheFieldRunsPastTheRightEdge() {
        let field = CGRect(x: 1200, y: 300, width: 400, height: 200)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        let bounds = primaryScreen.visibleFrame.insetBy(dx: OverlayMetrics.badgePadding, dy: OverlayMetrics.badgePadding)
        #expect(circle.maxX == bounds.maxX)
        #expect(circle.minY == field.minY + inset)
    }

    @Test func staysAboveTheDockWhenTheFieldTouchesTheBottomOfTheScreen() {
        let field = CGRect(x: 100, y: 0, width: 500, height: 200)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        #expect(circle.minY == primaryScreen.visibleFrame.minY + OverlayMetrics.badgePadding)
    }

    @Test func usesTheFieldsOwnScreen() {
        let field = CGRect(x: 2000, y: 0, width: 500, height: 200)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen, rightScreen])
        #expect(circle.minY == field.minY + inset)
        #expect(circle.maxX == field.maxX - inset)
    }

    @Test func windowFrameAddsPaddingAroundTheCircle() {
        let circle = CGRect(x: 10, y: 20, width: d, height: d)
        let window = BadgeLayout.windowFrame(circleFrame: circle)
        let pad = OverlayMetrics.badgePadding
        #expect(window == CGRect(x: 10 - pad, y: 20 - pad, width: d + 2 * pad, height: d + 2 * pad))
        let field = CGRect(x: 1400, y: 40, width: 100, height: 60)
        let clampedCircle = BadgeLayout.circleFrame(fieldFrame: field, screens: [primaryScreen])
        #expect(primaryScreen.visibleFrame.contains(BadgeLayout.windowFrame(circleFrame: clampedCircle)))
    }
}
