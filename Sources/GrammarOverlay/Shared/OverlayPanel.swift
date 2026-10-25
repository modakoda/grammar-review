import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    private(set) var isPresented = false
    private var fadeGeneration = 0
    private let acceptsKeyboard: Bool

    init(level: NSWindow.Level, clickThrough: Bool = false, hasShadow: Bool = false, acceptsKeyboard: Bool = false) {
        self.acceptsKeyboard = acceptsKeyboard
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isOpaque = false
        backgroundColor = .clear
        self.hasShadow = hasShadow
        ignoresMouseEvents = clickThrough
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        allowsToolTipsWhenApplicationIsInactive = true
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    func giveUpKeyboard() {
        guard isKeyWindow else { return }
        makeFirstResponder(nil)
        resignKey()
        if isVisible {
            orderOut(nil)
            if isPresented { orderFrontRegardless() }
        }
    }

    var presentedFrame: CGRect? { isPresented ? frame : nil }

    func setFrameIfNeeded(_ newFrame: CGRect) {
        guard newFrame.hasFiniteGeometry, newFrame != frame else { return }
        setFrame(newFrame, display: true)
        if hasShadow { invalidateShadow() }
    }

    func present(animated: Bool) {
        fadeGeneration += 1
        if !isPresented {
            isPresented = true
            alphaValue = animated ? 0 : 1
            orderFrontRegardless()
            if hasShadow { invalidateShadow() }
        }
        guard alphaValue < 1 else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = OverlayMetrics.fadeDuration
                animator().alphaValue = 1
            }
        } else {
            alphaValue = 1
        }
    }

    func dismiss(animated: Bool) {
        guard isPresented else { return }
        isPresented = false
        fadeGeneration += 1
        guard animated, isVisible else {
            orderOut(nil)
            alphaValue = 1
            return
        }
        let generation = fadeGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = OverlayMetrics.fadeDuration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.fadeGeneration == generation else { return }
                self.orderOut(nil)
                self.alphaValue = 1
            }
        }
    }
}
