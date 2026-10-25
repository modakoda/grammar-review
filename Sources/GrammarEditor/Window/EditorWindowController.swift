import AppKit
import GrammarModels
import SwiftUI

public final class EditorWindowController: NSObject, NSWindowDelegate {
    private let model: EditorModel
    private lazy var window = makeWindow()

    public init(services: EditorServices) {
        model = EditorModel(services: services)
        super.init()
    }

    public func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    public func settingsDidChange() {
        model.settingsDidChange()
    }

    public func windowWillClose(_ notification: Notification) {
        model.cancelRewrite()
        model.cancelCompose()
        model.plagiarism.cancel()
        model.sidebarTab = .suggestions
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Grammar Review Editor"
        window.contentView = NSHostingView(rootView: EditorView(model: model))
        window.contentMinSize = NSSize(width: 720, height: 420)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("GrammarReviewEditor")
        return window
    }
}
