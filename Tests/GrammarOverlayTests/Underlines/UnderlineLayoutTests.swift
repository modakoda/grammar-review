import CoreGraphics
import Foundation
import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct UnderlineLayoutTests {
    let field = CGRect(x: 100, y: 100, width: 400, height: 200)
    let thickness = OverlayMetrics.underlineThickness

    @Test func barIsCentredOnTheBottomOfTheTextRect() {
        let issue = makeIssue()
        let rect = CGRect(x: 120, y: 250, width: 30, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(issue, rect)], fieldFrame: field)
        #expect(segments.count == 1)
        #expect(segments[0].issueID == issue.id)
        #expect(segments[0].severity == .correctness)
        #expect(segments[0].textRect == rect)
        #expect(segments[0].barRect == CGRect(x: 120, y: 250 - thickness / 2, width: 30, height: thickness))
    }

    @Test func oneSegmentPerLineInOrder() {
        let issue = makeIssue(.style)
        let line1 = CGRect(x: 400, y: 250, width: 90, height: 16)
        let line2 = CGRect(x: 110, y: 232, width: 60, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(issue, line1, line2)], fieldFrame: field)
        #expect(segments.map(\.textRect) == [line1, line2])
        #expect(segments.allSatisfy { $0.severity == .style })
    }

    @Test func severityFollowsTheCategory() {
        let issues = [makeIssue(.grammar), makeIssue(.wordChoice), makeIssue(.style)]
        let rect = CGRect(x: 120, y: 250, width: 30, height: 16)
        let segments = UnderlineLayout.segments(for: issues.map { positioned($0, rect) }, fieldFrame: field)
        #expect(segments.map(\.severity) == [.correctness, .clarity, .style])
    }

    @Test func skipsIssuesWithoutRectsAndDegenerateRects() {
        let segments = UnderlineLayout.segments(
            for: [
                PositionedIssue(issue: makeIssue(), rects: []),
                positioned(makeIssue(), .zero),
                positioned(makeIssue(), CGRect(x: 120, y: 250, width: 30, height: 0)),
                positioned(makeIssue(), CGRect(x: 120, y: 250, width: 0, height: 16)),
                positioned(makeIssue(), .null),
                positioned(makeIssue(), CGRect(x: CGFloat.nan, y: 250, width: 30, height: 16)),
            ],
            fieldFrame: field
        )
        #expect(segments.isEmpty)
    }

    @Test func clipsHorizontallyToTheField() {
        let rect = CGRect(x: 450, y: 250, width: 100, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: field)
        #expect(segments.count == 1)
        #expect(segments[0].textRect == CGRect(x: 450, y: 250, width: 50, height: 16))
        #expect(segments[0].barRect.maxX == field.maxX)
    }

    @Test func skipsRectsOutsideTheField() {
        let left = CGRect(x: 0, y: 250, width: 50, height: 16)
        let above = CGRect(x: 120, y: 320, width: 30, height: 16)
        let below = CGRect(x: 120, y: 60, width: 30, height: 16)
        let segments = UnderlineLayout.segments(
            for: [positioned(makeIssue(), left), positioned(makeIssue(), above), positioned(makeIssue(), below)],
            fieldFrame: field
        )
        #expect(segments.isEmpty)
    }

    @Test func skipsALineHalfScrolledOutAtTheBottom() {
        let rect = CGRect(x: 120, y: 92, width: 30, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: field)
        #expect(segments.isEmpty)
    }

    @Test func keepsTheLastLineWhenItsBottomSitsOnTheFieldEdge() {
        let rect = CGRect(x: 120, y: 98, width: 30, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: field)
        #expect(segments.count == 1)
        #expect(segments[0].textRect == CGRect(x: 120, y: 100, width: 30, height: 14))
    }

    @Test func keepsALineHalfScrolledOutAtTheTopWithItsVisiblePart() {
        let rect = CGRect(x: 120, y: 292, width: 30, height: 16)
        let segments = UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: field)
        #expect(segments.count == 1)
        #expect(segments[0].textRect == CGRect(x: 120, y: 292, width: 30, height: 8))
        #expect(segments[0].barRect.midY == 292)
    }

    @Test func noFieldGeometryMeansNoSegments() {
        let rect = CGRect(x: 120, y: 250, width: 30, height: 16)
        #expect(UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: .zero).isEmpty)
        #expect(UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: .null).isEmpty)
    }

    @Test func windowIsTheFieldOutset() {
        let outset = OverlayMetrics.underlineWindowOutset
        #expect(UnderlineLayout.windowFrame(fieldFrame: field) == field.insetBy(dx: -outset, dy: -outset))
    }

    @Test func barsOfVisibleLinesFitInsideTheUnderlineWindow() {
        let window = UnderlineLayout.windowFrame(fieldFrame: field)
        let rects = [
            CGRect(x: 100, y: 98, width: 30, height: 16),
            CGRect(x: 470, y: 284, width: 30, height: 16),
            CGRect(x: 300, y: 150, width: 300, height: 16),
        ]
        let segments = UnderlineLayout.segments(for: rects.map { positioned(makeIssue(), $0) }, fieldFrame: field)
        #expect(segments.count == 3)
        for segment in segments {
            #expect(window.contains(segment.barRect))
        }
    }

    @Test func offsettingConvertsToWindowCoordinates() {
        let rect = CGRect(x: 120, y: 250, width: 30, height: 16)
        let segment = UnderlineLayout.segments(for: [positioned(makeIssue(), rect)], fieldFrame: field)[0]
        let window = UnderlineLayout.windowFrame(fieldFrame: field)
        let local = segment.offsetBy(dx: -window.minX, dy: -window.minY)
        #expect(local.textRect == CoordinateConversion.toWindow(segment.textRect, windowFrame: window))
        #expect(local.barRect == CoordinateConversion.toWindow(segment.barRect, windowFrame: window))
    }
}
