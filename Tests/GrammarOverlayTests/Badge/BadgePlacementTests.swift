import CoreGraphics
import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct BadgePlacementTests {
    let d = OverlayMetrics.badgeDiameter
    let inset = OverlayMetrics.badgeInset
    let gap = OverlayMetrics.badgeOutsideGap
    let singleLine = CGRect(x: 100, y: 300, width: 500, height: 24)
    let textArea = CGRect(x: 100, y: 300, width: 500, height: 200)

    @Test func automaticKeepsTheBadgeInsideALargeField() {
        let circle = BadgeLayout.circleFrame(fieldFrame: textArea, placement: .automatic, screens: [primaryScreen])
        #expect(circle == BadgeLayout.circleFrame(fieldFrame: textArea, placement: .insideBottomLeft, screens: [primaryScreen]))
    }

    @Test func automaticMovesTheBadgeBesideASingleLineField() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .automatic, screens: [primaryScreen])
        #expect(circle.maxX == singleLine.minX - gap)
        #expect(circle.midY == singleLine.midY)
        #expect(!circle.intersects(singleLine))
    }

    @Test func automaticTreatsShortAndNarrowFieldsAsSmall() {
        let outside: [BadgeLayout.Spot] = [.left, .right, .below, .above, .insideBottomLeft]
        #expect(BadgeLayout.candidates(for: .automatic, fieldFrame: CGRect(x: 0, y: 0, width: 500, height: 40)) == outside)
        #expect(BadgeLayout.candidates(for: .automatic, fieldFrame: CGRect(x: 0, y: 0, width: 20, height: 200)) == outside)
        #expect(BadgeLayout.candidates(for: .automatic, fieldFrame: CGRect(x: 0, y: 0, width: 500, height: 60)) == [.insideBottomLeft])
    }

    @Test func automaticPutsTheBadgeLeftOfAnInputFieldOfAnyHeight() {
        let input = CGRect(x: 100, y: 300, width: 500, height: 80)
        #expect(BadgeLayout.candidates(for: .automatic, fieldFrame: input, isSingleLine: true) == [.left, .right, .below, .above, .insideBottomLeft])
        let circle = BadgeLayout.circleFrame(fieldFrame: input, isSingleLine: true, placement: .automatic, screens: [primaryScreen])
        #expect(circle.maxX == input.minX - gap)
        #expect(circle.midY == input.midY)
    }

    @Test func besideAnInputFieldTheBadgeIsCentredOnIt() {
        let input = CGRect(x: 100, y: 300, width: 500, height: 40)
        let circle = BadgeLayout.circleFrame(fieldFrame: input, isSingleLine: true, placement: .right, screens: [primaryScreen])
        #expect(circle.minX == input.maxX + gap)
        #expect(circle.midY == input.midY)
    }

    @Test func insidePlacementsNeverMoveOutside() {
        #expect(BadgeLayout.candidates(for: .insideTopLeft, fieldFrame: singleLine) == [.insideTopLeft])
        #expect(BadgeLayout.candidates(for: .insideBottomRight, fieldFrame: singleLine) == [.insideBottomRight])
    }

    @Test func outsidePlacementsFallBackInsideAtTheirOwnCorner() {
        #expect(BadgeLayout.candidates(for: .left, fieldFrame: singleLine) == [.left, .right, .below, .above, .insideBottomLeft])
        #expect(BadgeLayout.candidates(for: .above, fieldFrame: singleLine) == [.above, .right, .below, .left, .insideTopRight])
    }

    @Test func insideCornersHugTheirCorner() {
        func circle(_ placement: BadgePlacement) -> CGRect {
            BadgeLayout.circleFrame(fieldFrame: textArea, placement: placement, screens: [primaryScreen])
        }
        #expect(circle(.insideTopRight) == CGRect(x: textArea.maxX - inset - d, y: textArea.maxY - inset - d, width: d, height: d))
        #expect(circle(.insideBottomLeft) == CGRect(x: textArea.minX + inset, y: textArea.minY + inset, width: d, height: d))
        #expect(circle(.insideTopLeft) == CGRect(x: textArea.minX + inset, y: textArea.maxY - inset - d, width: d, height: d))
    }

    @Test func insideTopLeftIsVerticallyCentredInASingleLineField() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .insideTopLeft, screens: [primaryScreen])
        #expect(circle.minX == singleLine.minX + inset)
        #expect(circle.midY == singleLine.midY)
    }

    @Test func leftSitsBesideTheStartOfASingleLineField() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .left, screens: [primaryScreen])
        #expect(circle.maxX == singleLine.minX - gap)
        #expect(circle.midY == singleLine.midY)
    }

    @Test func aboveSitsOverTheRightCorner() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .above, screens: [primaryScreen])
        #expect(circle == CGRect(x: singleLine.maxX - inset - d, y: singleLine.maxY + gap, width: d, height: d))
    }

    @Test func leftFallsBackToRightAtTheScreensLeftEdge() {
        let field = CGRect(x: 0, y: 300, width: 500, height: 24)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .left, screens: [primaryScreen])
        #expect(circle.minX == field.maxX + gap)
    }

    @Test func rightOfATallFieldKeepsTheCornerHeight() {
        let circle = BadgeLayout.circleFrame(fieldFrame: textArea, placement: .right, screens: [primaryScreen])
        #expect(circle == CGRect(x: textArea.maxX + gap, y: textArea.minY + inset, width: d, height: d))
    }

    @Test func belowSitsUnderTheRightCorner() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .below, screens: [primaryScreen])
        #expect(circle == CGRect(x: singleLine.maxX - inset - d, y: singleLine.minY - gap - d, width: d, height: d))
    }

    @Test func rightFallsBackToBelowAtTheScreensRightEdge() {
        let field = CGRect(x: 1000, y: 300, width: 440, height: 24)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .right, screens: [primaryScreen])
        #expect(circle.maxY == field.minY - gap)
        #expect(!circle.intersects(field))
    }

    @Test func belowFallsBackToRightAboveTheDock() {
        let field = CGRect(x: 100, y: 62, width: 500, height: 24)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .below, screens: [primaryScreen])
        #expect(circle.minX == field.maxX + gap)
        #expect(!circle.intersects(field))
    }

    @Test func automaticGoesAboveAFullWidthFieldOnTheDock() {
        let field = CGRect(x: 0, y: 62, width: 1440, height: 24)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .automatic, screens: [primaryScreen])
        #expect(circle == CGRect(x: field.maxX - inset - d, y: field.maxY + gap, width: d, height: d))
    }

    @Test func fallsBackInsideWhenNoSpotOutsideFits() {
        let field = primaryScreen.visibleFrame
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .right, screens: [primaryScreen])
        #expect(circle == CGRect(x: field.maxX - inset - d, y: field.minY + inset, width: d, height: d))
    }

    @Test func rightSlidesUpAlongTheFieldWhenItsBottomIsOffScreen() {
        let field = CGRect(x: 100, y: 0, width: 500, height: 300)
        let circle = BadgeLayout.circleFrame(fieldFrame: field, placement: .right, screens: [primaryScreen])
        #expect(circle.minX == field.maxX + gap)
        #expect(circle.minY == primaryScreen.visibleFrame.minY + OverlayMetrics.badgePadding)
    }

    @Test func outsideBadgeWindowDoesNotOverlapTheField() {
        let circle = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .right, screens: [primaryScreen])
        let window = BadgeLayout.windowFrame(circleFrame: circle)
        #expect(window.minX >= singleLine.maxX)
    }

    @Test func spacingMovesAnOutsideBadgeAwayFromTheField() {
        let left = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .left, screens: [primaryScreen], gap: 16)
        #expect(left.maxX == singleLine.minX - 16)
        let below = BadgeLayout.circleFrame(fieldFrame: singleLine, placement: .below, screens: [primaryScreen], gap: 16)
        #expect(below.maxY == singleLine.minY - 16)
        let inside = BadgeLayout.circleFrame(fieldFrame: textArea, placement: .insideBottomLeft, screens: [primaryScreen], gap: 16)
        #expect(inside.minX == textArea.minX + inset)
    }

    @Test func theSmallestSpacingKeepsTheBadgeWindowOffTheField() {
        #expect(AppSettings.badgeSpacingRange.lowerBound >= OverlayMetrics.badgePadding)
        #expect(CGFloat(AppSettings().badgeSpacing) == gap)
    }
}
