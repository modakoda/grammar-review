import AppKit
import ApplicationServices
import GrammarModels

protocol FocusedFieldWatcherDelegate: AnyObject {
    func fieldWatcher(_ watcher: FocusedFieldWatcher, didChange changes: FieldStateTracker.Changes, in field: AXTextFieldHandle)
    func fieldWatcherFieldDidGoAway(_ watcher: FocusedFieldWatcher)
    func fieldWatcherFieldDidBecomeSecure(_ watcher: FocusedFieldWatcher)
}

final class FocusedFieldWatcher {
    static let pollInterval: TimeInterval = 0.5
    static let textCheckOnSelectionLimit = 20_000

    weak var delegate: (any FocusedFieldWatcherDelegate)?
    private(set) var field: AXTextFieldHandle?

    private var notifications: (observation: AppObservation, element: AXElement, names: [String])?
    private var reported = FieldStateTracker()
    private var pollTimer: RepeatingTimer?
    private var pollCount = 0

    @discardableResult
    func watch(_ newField: AXTextFieldHandle?, in observation: AppObservation?) -> Bool {
        switch (field, newField) {
        case (nil, nil):
            return false
        case let (old?, new?) where old.isSameField(as: new):
            return false
        default:
            break
        }
        unregisterNotifications()
        field = newField
        pollCount = 0
        if let newField {
            reported.reset(text: newField.readText(), selection: newField.selectedRange(), frame: newField.frameForChangeTracking())
            if let observation { registerNotifications(for: newField, in: observation) }
            startPolling()
            Log.accessibility.info("Focused \(newField.logName, privacy: .public)")
        } else {
            reported.reset()
            stopPolling()
            Log.accessibility.info("No checkable field focused")
        }
        return true
    }

    func stop() {
        unregisterNotifications()
        field = nil
        reported.reset()
        stopPolling()
    }

    func handle(_ notification: String, for element: AXElement, from pid: pid_t) {
        guard let field else { return }
        switch notification {
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            guard field.processID == pid else { return }
            field.invalidateGeometry()
            sync(field, text: false, selection: false, geometry: true)

        case kAXValueChangedNotification:
            guard field.processID == pid else { return }
            field.invalidateGeometry()
            sync(field, text: true, selection: true, geometry: true)

        case kAXSelectedTextChangedNotification:
            guard field.processID == pid else { return }
            let smallText = (field.lastKnownTextLength ?? 0) <= Self.textCheckOnSelectionLimit
            sync(field, text: smallText, selection: true, geometry: false)

        case kAXUIElementDestroyedNotification:
            guard element.isSame(as: field.element) else { return }
            delegate?.fieldWatcherFieldDidGoAway(self)

        default:
            break
        }
    }

    private func registerNotifications(for field: AXTextFieldHandle, in observation: AppObservation) {
        let names = [kAXValueChangedNotification, kAXSelectedTextChangedNotification, kAXUIElementDestroyedNotification]
            .filter { observation.add($0, to: field.element) }
        notifications = (observation, field.element, names)
    }

    private func unregisterNotifications() {
        guard let registration = notifications else { return }
        for name in registration.names {
            registration.observation.remove(name, from: registration.element)
        }
        notifications = nil
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = RepeatingTimer(interval: Self.pollInterval) { [weak self] in
            self?.poll()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard let field else {
            stopPolling()
            return
        }
        pollCount += 1
        let isLarge = (field.lastKnownTextLength ?? 0) > AXTextFieldHandle.largeTextThreshold
        sync(field, text: !isLarge || pollCount.isMultiple(of: 4), selection: true, geometry: true)
    }

    private func sync(_ field: AXTextFieldHandle, text: Bool, selection: Bool, geometry: Bool) {
        var changes: FieldStateTracker.Changes = []
        if text {
            if let newText = field.readText() {
                if reported.updateText(newText) { changes.insert(.text) }
            } else if field.isUnresponsive {
            } else if !field.isAlive {
                delegate?.fieldWatcherFieldDidGoAway(self)
                return
            } else if field.isSecure {
                Log.accessibility.info("Focused field became secure")
                delegate?.fieldWatcherFieldDidBecomeSecure(self)
                return
            }
        }
        if selection, let range = field.selectedRange(), reported.updateSelection(range) {
            changes.insert(.selection)
        }
        if geometry, let frame = field.frameForChangeTracking(), reported.updateFrame(frame) {
            changes.insert(.geometry)
        }
        if !changes.isEmpty {
            delegate?.fieldWatcher(self, didChange: changes, in: field)
        }
    }
}
