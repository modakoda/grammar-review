import CoreGraphics
import Foundation
import GrammarModels

nonisolated enum PanelLayout {
    static func width(
        content: CGFloat,
        available: CGFloat,
        minWidth: CGFloat = OverlayMetrics.panelWidth,
        maxWidth: CGFloat = OverlayMetrics.panelMaxWidth
    ) -> CGFloat {
        max(minWidth, min(content.rounded(.up), maxWidth, available))
    }

    static func listHeight(
        header: CGFloat,
        rows: CGFloat,
        footer: CGFloat,
        maxHeight: CGFloat,
        minListHeight: CGFloat = OverlayMetrics.panelMinListHeight
    ) -> CGFloat {
        let available = maxHeight - header - footer
        let floor = min(rows, minListHeight)
        return max(0, min(rows, max(available, floor)))
    }
}
