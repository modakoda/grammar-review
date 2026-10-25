import AppKit

final class EventMonitor {
    private let mask: NSEvent.EventTypeMask
    private let handler: () -> Void
    private var monitors: [Any] = []

    init(matching mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        self.mask = mask
        self.handler = handler
    }

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated { self?.handler() }
            },
            NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated { self?.handler() }
                return event
            },
        ].compactMap(\.self)
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
    }
}
