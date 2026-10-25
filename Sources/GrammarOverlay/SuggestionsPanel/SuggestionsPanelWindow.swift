import AppKit
import SwiftUI

final class SuggestionsPanelWindow {
    let panel = OverlayPanel(level: OverlayLevel.popover, hasShadow: true)
    private let model: PanelModel
    private let background = MaterialBackgroundView()
    private let header: FirstMouseHostingView<PanelHeaderView>
    private let rows: FirstMouseHostingView<PanelRowsView>
    private let footer: FirstMouseHostingView<PanelFooterView>
    private let scrollView = NSScrollView()
    private var measured: (header: CGFloat, rows: CGFloat, footer: CGFloat)?
    private var lastLayout: (anchor: CGRect, alignment: PopoverAlignment, screens: [ScreenLayout])?

    init(model: PanelModel, actions: OverlayActions) {
        self.model = model
        header = FirstMouseHostingView(rootView: PanelHeaderView(model: model, actions: actions))
        rows = FirstMouseHostingView(rootView: PanelRowsView(model: model, actions: actions))
        footer = FirstMouseHostingView(rootView: PanelFooterView(model: model, actions: actions))

        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = rows

        background.addSubview(header)
        background.addSubview(scrollView)
        background.addSubview(footer)
        panel.contentView = background
        model.contentSizeDidChange = { [weak self] in self?.relayout() }
    }

    func contentDidChange() {
        measured = nil
    }

    private func relayout() {
        measured = nil
        guard let lastLayout, panel.isPresented else { return }
        layout(anchor: lastLayout.anchor, alignment: lastLayout.alignment, screens: lastLayout.screens)
    }

    func scrollToTop() {
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @discardableResult
    func layout(anchor: CGRect, alignment: PopoverAlignment = .trailing, screens: [ScreenLayout]) -> PopoverPlacement {
        lastLayout = (anchor, alignment, screens)
        let screen = ScreenChooser.screen(for: anchor, among: screens)
        if measured == nil {
            let available = screen.map { $0.visibleFrame.width - 2 * OverlayMetrics.screenMargin } ?? .greatestFiniteMagnitude
            let width = PanelLayout.width(content: idealWidth(), available: available)
            if model.width != width { model.width = width }
        }
        let heights = measured ?? (
            header: header.measuredSize().height,
            rows: rows.measuredSize().height,
            footer: footer.measuredSize().height
        )
        measured = heights

        let width = model.width
        var maxHeight = OverlayMetrics.panelMaxHeight
        if let screen {
            maxHeight = min(maxHeight, screen.visibleFrame.height - 2 * OverlayMetrics.screenMargin)
        }
        let listHeight = PanelLayout.listHeight(
            header: heights.header, rows: heights.rows, footer: heights.footer, maxHeight: maxHeight
        ).rounded(.up)
        let size = CGSize(width: width, height: heights.header + listHeight + heights.footer)
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: screens, alignment: alignment)
        panel.setFrameIfNeeded(placement.frame.roundedToPoints())

        let total = panel.frame.height
        let footerFrame = CGRect(x: 0, y: 0, width: width, height: heights.footer)
        let headerFrame = CGRect(x: 0, y: max(0, total - heights.header), width: width, height: heights.header)
        let listFrame = CGRect(x: 0, y: footerFrame.maxY, width: width, height: max(0, headerFrame.minY - footerFrame.maxY))
        if footer.frame != footerFrame { footer.frame = footerFrame }
        if header.frame != headerFrame { header.frame = headerFrame }
        if scrollView.frame != listFrame { scrollView.frame = listFrame }
        let rowsFrame = CGRect(x: 0, y: 0, width: width, height: heights.rows)
        if rows.frame.size != rowsFrame.size { rows.frame = rowsFrame }
        return placement
    }

    private func idealWidth() -> CGFloat {
        guard model.tone != nil || model.isDetectingTone else { return 0 }
        let tone = NSHostingView(rootView: PanelToneRow(tone: model.tone, isDetecting: model.isDetectingTone))
        return tone.fittingSize.width + PanelHeaderView.leadingPadding + PanelHeaderView.trailingPadding
            + PanelHeaderView.textTrailingPadding
    }
}
