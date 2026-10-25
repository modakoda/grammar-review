import AppKit

final class UnderlinePresenter {
    private var window: UnderlineWindow?

    func render(_ segments: [UnderlineSegment], fieldFrame: CGRect?, active: Set<UUID>) {
        guard let fieldFrame, fieldFrame.isDrawable, !segments.isEmpty else {
            window?.panel.dismiss(animated: false)
            return
        }
        let window = ensureWindow()
        let frame = UnderlineLayout.windowFrame(fieldFrame: fieldFrame).roundedToPoints()
        window.panel.setFrameIfNeeded(frame)
        let local = segments.map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        window.view.apply(segments: local, activeIssueIDs: active)
        window.panel.present(animated: false)
    }

    func emphasize(_ active: Set<UUID>) {
        guard let window, window.panel.isPresented else { return }
        window.view.apply(segments: window.view.segments, activeIssueIDs: active)
    }

    func hide() {
        window?.view.apply(segments: [], activeIssueIDs: [])
        window?.panel.dismiss(animated: false)
    }

    private func ensureWindow() -> UnderlineWindow {
        if let window { return window }
        let window = UnderlineWindow()
        self.window = window
        return window
    }
}
