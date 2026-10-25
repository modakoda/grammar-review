import CoreGraphics
import Foundation
import GrammarModels

nonisolated enum HoverHitTest {
    static func issueID(
        at point: CGPoint,
        in segments: [UnderlineSegment],
        inflation: CGFloat = OverlayMetrics.hoverInflation
    ) -> UUID? {
        var best: UUID?
        var bestArea = CGFloat.infinity
        for segment in segments {
            let hitRect = segment.textRect.insetBy(dx: 0, dy: -inflation).union(segment.barRect)
            guard hitRect.containsInclusive(point) else { continue }
            let area = segment.textRect.width * segment.textRect.height
            if area < bestArea {
                best = segment.issueID
                bestArea = area
            }
        }
        return best
    }

    static func anchorRect(for issueID: UUID, in segments: [UnderlineSegment]) -> CGRect? {
        segments.first { $0.issueID == issueID }?.textRect
    }
}
