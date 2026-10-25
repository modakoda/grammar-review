import AppKit
import GrammarModels

final class UnderlineView: NSView {
    private(set) var segments: [UnderlineSegment] = []
    private(set) var activeIssueIDs: Set<UUID> = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { false }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @discardableResult
    func apply(segments: [UnderlineSegment], activeIssueIDs: Set<UUID>) -> Bool {
        guard segments != self.segments || activeIssueIDs != self.activeIssueIDs else { return false }
        self.segments = segments
        self.activeIssueIDs = activeIssueIDs
        needsDisplay = true
        return true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        for segment in segments where activeIssueIDs.contains(segment.issueID) {
            let highlight = backingAlignedRect(segment.textRect, options: .alignAllEdgesNearest)
            guard highlight.intersects(dirtyRect) else { continue }
            segment.severity.underlineColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: highlight, xRadius: 2, yRadius: 2).fill()
        }
        for segment in segments {
            let isActive = activeIssueIDs.contains(segment.issueID)
            var bar = segment.barRect
            if isActive {
                let extra = OverlayMetrics.activeUnderlineThickness - OverlayMetrics.underlineThickness
                bar = bar.insetBy(dx: 0, dy: -extra / 2)
            }
            bar = backingAlignedRect(bar, options: .alignAllEdgesNearest)
            guard bar.intersects(dirtyRect), bar.width > 0, bar.height > 0 else { continue }
            segment.severity.underlineColor.withAlphaComponent(isActive ? 1 : 0.85).setFill()
            let radius = bar.height / 2
            NSBezierPath(roundedRect: bar, xRadius: radius, yRadius: radius).fill()
        }
    }
}
