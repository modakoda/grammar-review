import AppKit
import ApplicationServices
import GrammarModels

public final class AccessibilityFocusTracker: FocusTracking {
    public weak var delegate: (any FocusTrackingDelegate)?
    public private(set) var focusedField: (any TextFieldHandle)?
    public private(set) var isTracking = false
    public var windowsAreHidden: Bool { windowExposure.isHidden }

    public init() {
        fieldWatcher.delegate = self
        compatibility.isObserving = { [weak self] observation in
            guard let self else { return false }
            return self.isTracking && self.observations[observation.pid] === observation
        }
        compatibility.webContentDidAppear = { [weak self] observation in
            guard let self, self.activePID == observation.pid else { return }
            self.refreshFocus()
        }
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        permissionTimer = RepeatingTimer(interval: Self.permissionPollInterval) { [weak self] in
            self?.checkPermission()
        }
        checkPermission()
        if !isTracking {
            Log.accessibility.info("Waiting for Accessibility permission")
        }
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        permissionTimer?.invalidate()
        permissionTimer = nil
        endTracking()
        Log.accessibility.info("Focus tracker stopped")
    }

    public func refreshFocus() {
        guard isTracking else { return }
        guard let pid = activePID, let observation = observations[pid] else {
            activate(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier)
            return
        }
        lastFocusedElement = nil
        let (focused, error) = focusedElement(of: observation)
        handleFocus(focused, error: error, hint: nil, in: observation)
    }

    static let permissionPollInterval: TimeInterval = 2
    static let focusPollInterval: TimeInterval = 1

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let fieldWatcher = FocusedFieldWatcher()
    private let compatibility = AppCompatibilityFixer()
    private let windowExposure = WindowExposureMonitor()
    private var isStarted = false
    private var permissionTimer: RepeatingTimer?
    private var focusTimer: RepeatingTimer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var observations: [pid_t: AppObservation] = [:]
    private var activePID: pid_t?
    private var lastActivatedPID: pid_t?
    private var lastFocusedElement: AXElement?
    private var reevaluateFocus = false

    private var field: AXTextFieldHandle? { fieldWatcher.field }

    private func checkPermission() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted, !isTracking {
            beginTracking()
        } else if !trusted, isTracking {
            Log.accessibility.error("Accessibility permission was revoked; tracking paused")
            endTracking()
        }
    }

    private func beginTracking() {
        isTracking = true
        AXElement.systemWide().setMessagingTimeout(AccessibilityTiming.messagingTimeout)

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated { self?.activate(pid: pid) }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated {
                    if let pid { self?.applicationDidTerminate(pid) }
                }
            },
        ]
        focusTimer = RepeatingTimer(interval: Self.focusPollInterval) { [weak self] in
            self?.pollFocus()
        }
        Log.accessibility.info("Accessibility granted; tracking focus")
        activate(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    private func endTracking() {
        guard isTracking else { return }
        isTracking = false
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers = []
        focusTimer?.invalidate()
        focusTimer = nil

        let hadField = field != nil
        fieldWatcher.stop()
        focusedField = nil

        for observation in observations.values {
            compatibility.undo(on: observation)
            observation.invalidate()
        }
        observations.removeAll()
        activePID = nil
        lastActivatedPID = nil
        lastFocusedElement = nil
        reevaluateFocus = false
        if hadField { delegate?.focusTracker(self, didFocus: nil) }
        if windowExposure.reset() { delegate?.focusTrackerWindowsHiddenDidChange(self) }
    }

    private func activate(pid: pid_t?) {
        guard isTracking else { return }
        lastActivatedPID = pid
        lastFocusedElement = nil
        reevaluateFocus = false
        guard let pid, pid != ownPID,
              let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated
        else {
            activePID = nil
            setField(nil)
            return
        }
        let observation = observation(for: app)
        activePID = pid
        let (focused, error) = focusedElement(of: observation)
        handleFocus(focused, error: error, hint: nil, in: observation)
    }

    private func observation(for app: NSRunningApplication) -> AppObservation {
        if let existing = observations[app.processIdentifier] {
            existing.registerIfNeeded()
            compatibility.apply(to: existing)
            return existing
        }
        let observation = AppObservation(application: app, handler: self)
        observation.registerIfNeeded(force: true)
        observations[observation.pid] = observation
        Log.accessibility.info("Observing \(observation.bundleID ?? "pid \(observation.pid)", privacy: .public) (\(observation.family.rawValue, privacy: .public))")
        compatibility.apply(to: observation)
        return observation
    }

    private func applicationDidTerminate(_ pid: pid_t) {
        if field?.processID == pid { setField(nil) }
        observations.removeValue(forKey: pid)?.invalidate()
        if activePID == pid {
            activePID = nil
            lastFocusedElement = nil
        }
    }

    private func focusedElement(of observation: AppObservation) -> (AXElement?, AXError) {
        guard !observation.health.isSuspended() else { return (nil, .cannotComplete) }
        let start = ContinuousClock.now
        let (value, error) = observation.app.copyValue(kAXFocusedUIElementAttribute)
        observation.health.record(error, elapsed: start.duration(to: .now))
        return (AXValueConversion.element(value), error)
    }

    private func handleFocus(_ focused: AXElement?, error: AXError, hint: AXElement?, in observation: AppObservation) {
        guard let element = focused ?? hint else {
            if error == .cannotComplete, field?.processID == observation.pid {
                reevaluateFocus = true
                return
            }
            lastFocusedElement = nil
            reevaluateFocus = error == .cannotComplete
            setField(nil)
            return
        }
        lastFocusedElement = element
        if windowExposure.record(focused: element, in: observation) {
            delegate?.focusTrackerWindowsHiddenDidChange(self)
        }
        let inspection = FieldInspector.inspect(element, appPID: observation.pid)
        reevaluateFocus = inspection.decision.isTransient
        if inspection.decision == .reject(.unresponsive), field?.processID == observation.pid {
            return
        }
        guard case .accept = inspection.decision, let target = inspection.target else {
            if field != nil {
                Log.accessibility.debug("Focus moved to \(inspection.role ?? "?", privacy: .public) in \(observation.bundleID ?? "?", privacy: .public): \(String(describing: inspection.decision), privacy: .public)")
            }
            setField(nil)
            return
        }
        if let field, field.element.isSame(as: target) { return }
        setField(AXTextFieldHandle(
            element: target,
            processID: observation.pid,
            bundleID: observation.bundleID,
            appName: observation.appName,
            role: inspection.role
        ))
    }

    private func setField(_ newField: AXTextFieldHandle?) {
        let observation = newField.flatMap { observations[$0.processID] }
        guard fieldWatcher.watch(newField, in: observation) else { return }
        focusedField = newField
        delegate?.focusTracker(self, didFocus: newField)
    }

    private func fieldDestroyed() {
        Log.accessibility.debug("Focused field went away")
        lastFocusedElement = nil
        setField(nil)
        guard let pid = activePID, let observation = observations[pid] else { return }
        let (focused, error) = focusedElement(of: observation)
        handleFocus(focused, error: error, hint: nil, in: observation)
    }

    private func pollFocus() {
        guard isTracking else { return }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if frontPID != lastActivatedPID {
            activate(pid: frontPID)
            return
        }
        guard let pid = activePID, let observation = observations[pid] else { return }
        if !observation.health.isSuspended() {
            observation.registerIfNeeded()
            if observation.compatibility.manualAccessibility == nil { compatibility.apply(to: observation) }
        }

        let (focused, error) = focusedElement(of: observation)
        let changed = switch (focused, lastFocusedElement) {
        case (nil, nil): false
        case let (now?, before?): !now.isSame(as: before)
        default: true
        }
        if changed || reevaluateFocus {
            handleFocus(focused, error: error, hint: nil, in: observation)
        }
    }
}

extension AccessibilityFocusTracker: AXNotificationHandling {
    func observation(_ observation: AppObservation, didReceive notification: String, for element: AXElement) {
        guard isTracking, observations[observation.pid] === observation else { return }
        switch notification {
        case kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification:
            guard observation.pid == activePID else { return }
            let hint = notification == kAXFocusedUIElementChangedNotification ? element : nil
            let (focused, error) = focusedElement(of: observation)
            handleFocus(focused, error: error, hint: hint, in: observation)
        default:
            fieldWatcher.handle(notification, for: element, from: observation.pid)
        }
    }
}

extension AccessibilityFocusTracker: FocusedFieldWatcherDelegate {
    func fieldWatcher(_ watcher: FocusedFieldWatcher, didChange changes: FieldStateTracker.Changes, in field: AXTextFieldHandle) {
        if changes.contains(.text) {
            delegate?.focusTracker(self, textDidChangeIn: field)
        }
        if changes.contains(.selection), watcher.field === field {
            delegate?.focusTracker(self, selectionDidChangeIn: field)
        }
        if changes.contains(.geometry), watcher.field === field {
            delegate?.focusTracker(self, geometryDidChangeFor: field)
        }
    }

    func fieldWatcherFieldDidGoAway(_ watcher: FocusedFieldWatcher) {
        fieldDestroyed()
    }

    func fieldWatcherFieldDidBecomeSecure(_ watcher: FocusedFieldWatcher) {
        setField(nil)
    }
}
