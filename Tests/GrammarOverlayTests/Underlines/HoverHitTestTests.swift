import CoreGraphics
import Foundation
import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct HoverHitTestTests {
    let field = CGRect(x: 0, y: 0, width: 800, height: 600)

    func segments(_ issues: [PositionedIssue]) -> [UnderlineSegment] {
        UnderlineLayout.segments(for: issues, fieldFrame: field)
    }

    @Test func hitsInsideTheText() {
        let issue = makeIssue()
        let s = segments([positioned(issue, CGRect(x: 100, y: 300, width: 40, height: 16))])
        #expect(HoverHitTest.issueID(at: CGPoint(x: 120, y: 308), in: s) == issue.id)
    }

    @Test func inflatesVerticallyButNotHorizontally() {
        let issue = makeIssue()
        let s = segments([positioned(issue, CGRect(x: 100, y: 300, width: 40, height: 16))])
        let inflation = OverlayMetrics.hoverInflation
        #expect(HoverHitTest.issueID(at: CGPoint(x: 120, y: 300 - inflation + 0.5), in: s) == issue.id)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 120, y: 316 + inflation - 0.5), in: s) == issue.id)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 120, y: 300 - inflation - 1), in: s) == nil)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 120, y: 316 + inflation + 1), in: s) == nil)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 99, y: 308), in: s) == nil)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 141, y: 308), in: s) == nil)
    }

    @Test func hitsAnyLineOfAMultiLineIssue() {
        let issue = makeIssue(.clarity)
        let s = segments([positioned(issue, CGRect(x: 600, y: 300, width: 150, height: 16), CGRect(x: 10, y: 282, width: 90, height: 16))])
        #expect(HoverHitTest.issueID(at: CGPoint(x: 50, y: 290), in: s) == issue.id)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 300, y: 290), in: s) == nil)
    }

    @Test func smallestOverlappingIssueWins() {
        let sentence = makeIssue(.style)
        let word = makeIssue(.spelling)
        let s = segments([
            positioned(sentence, CGRect(x: 100, y: 300, width: 400, height: 16)),
            positioned(word, CGRect(x: 200, y: 300, width: 40, height: 16)),
        ])
        #expect(HoverHitTest.issueID(at: CGPoint(x: 210, y: 308), in: s) == word.id)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 150, y: 308), in: s) == sentence.id)
    }

    @Test func clippedPartsAreNotHittable() {
        let issue = makeIssue()
        let s = segments([positioned(issue, CGRect(x: 780, y: 300, width: 40, height: 16))])
        #expect(HoverHitTest.issueID(at: CGPoint(x: 790, y: 308), in: s) == issue.id)
        #expect(HoverHitTest.issueID(at: CGPoint(x: 810, y: 308), in: s) == nil)
    }

    @Test func anchorIsTheFirstVisibleLine() {
        let issue = makeIssue()
        let hidden = CGRect(x: 100, y: 700, width: 40, height: 16)
        let visible = CGRect(x: 10, y: 580, width: 60, height: 16)
        let s = segments([positioned(issue, hidden, visible)])
        #expect(HoverHitTest.anchorRect(for: issue.id, in: s) == visible)
        #expect(HoverHitTest.anchorRect(for: UUID(), in: s) == nil)
    }

    @Test func nothingToHit() {
        #expect(HoverHitTest.issueID(at: CGPoint(x: 1, y: 1), in: []) == nil)
    }
}
