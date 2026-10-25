import AppKit
import SwiftUI

enum AppWindows {
    static func makeWindow(title: String, contentSize: NSSize, rootView: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.contentViewController = hosting
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    static func present(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        if !window.isVisible || !isOnScreen(window.frame) {
            window.center()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        Task { @MainActor in
            await Task.yield()
            if !isOnScreen(window.frame) { window.center() }
        }
    }

    static func isOnScreen(_ frame: NSRect, screens: [NSRect] = NSScreen.screens.map(\.visibleFrame)) -> Bool {
        screens.contains { $0.contains(frame) }
    }
}

final class WindowCloseObserver: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
