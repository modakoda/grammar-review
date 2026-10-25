import AppKit

final class ScreenTracker {
    var provider: () -> [ScreenLayout] = {
        NSScreen.screens.map { ScreenLayout(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }

    var onChange: () -> Void = {}
    private(set) var screens: [ScreenLayout] = []
    private var isStale = true
    private var observer: (any NSObjectProtocol)?

    func refreshIfNeeded() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensDidChange() }
            }
        }
        guard isStale else { return }
        screens = provider()
        isStale = false
    }

    private func screensDidChange() {
        isStale = true
        onChange()
    }
}
