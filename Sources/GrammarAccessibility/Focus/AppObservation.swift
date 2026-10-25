import AppKit
import ApplicationServices
import GrammarModels

protocol AXNotificationHandling: AnyObject {
    func observation(_ observation: AppObservation, didReceive notification: String, for element: AXElement)
}

final class AppObservation {
    static let appNotifications = [
        kAXFocusedUIElementChangedNotification,
        kAXFocusedWindowChangedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
    ]

    struct Compatibility {
        var manualAccessibility: ManualAccessibilityResult?
        var probe: WebContentProbe?
        var enhancedUserInterfaceEnabled = false
        var enhancedUserInterfaceAttempted = false
        var probeScheduled = false
        var probeAttempts = 0
    }

    let pid: pid_t
    let app: AXElement
    let bundleID: String?
    let appName: String?
    let family: AppFamily
    weak var handler: (any AXNotificationHandling)?
    var compatibility = Compatibility()
    var health = Responsiveness()

    private var observer: AXObserver?
    private var retainedSelf: Unmanaged<AppObservation>?
    private(set) var registeredAppNotifications: Set<String> = []
    private var lastRegistrationAttempt: ContinuousClock.Instant?

    var isFullyRegistered: Bool {
        observer != nil && registeredAppNotifications.count == Self.appNotifications.count
    }

    init(application: NSRunningApplication, handler: any AXNotificationHandling) {
        pid = application.processIdentifier
        app = AXElement.application(pid)
        bundleID = application.bundleIdentifier
        appName = application.localizedName
        family = AppCompatibility.family(
            bundleID: application.bundleIdentifier,
            isElectron: AppCompatibility.isElectronApp(at: application.bundleURL)
        )
        self.handler = handler
        app.setMessagingTimeout(AccessibilityTiming.messagingTimeout)
    }

    func registerIfNeeded(force: Bool = false) {
        guard !isFullyRegistered else { return }
        let now = ContinuousClock.now
        if !force, let last = lastRegistrationAttempt, last.duration(to: now) < .seconds(2) { return }
        lastRegistrationAttempt = now

        if observer == nil {
            var created: AXObserver?
            let error = AXObserverCreate(pid, appObservationCallback, &created)
            guard error == .success, let created else {
                Log.accessibility.debug("AXObserverCreate failed for pid \(self.pid, privacy: .public): \(error.logName, privacy: .public)")
                return
            }
            observer = created
            retainedSelf = Unmanaged.passRetained(self)
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        }

        var failures: [String] = []
        for notification in Self.appNotifications where !registeredAppNotifications.contains(notification) {
            if add(notification, to: app) {
                registeredAppNotifications.insert(notification)
            } else {
                failures.append(notification)
            }
        }
        if !failures.isEmpty {
            Log.accessibility.debug("\(self.bundleID ?? "?", privacy: .public): couldn't register \(failures.joined(separator: ", "), privacy: .public)")
        }
    }

    @discardableResult
    func add(_ notification: String, to element: AXElement) -> Bool {
        guard let observer, let retainedSelf else { return false }
        let error = AXObserverAddNotification(observer, element.raw, notification as CFString, retainedSelf.toOpaque())
        return error == .success || error == .notificationAlreadyRegistered
    }

    func remove(_ notification: String, from element: AXElement) {
        guard let observer else { return }
        _ = AXObserverRemoveNotification(observer, element.raw, notification as CFString)
    }

    func invalidate() {
        if let observer {
            for notification in registeredAppNotifications {
                _ = AXObserverRemoveNotification(observer, app.raw, notification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        registeredAppNotifications.removeAll()
        observer = nil
        handler = nil
        retainedSelf?.release()
        retainedSelf = nil
    }

    fileprivate func deliver(_ notification: String, element: AXElement) {
        handler?.observation(self, didReceive: notification, for: element)
    }
}

private nonisolated func appObservationCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    nonisolated(unsafe) let element = element
    let name = notification as String
    let address = UInt(bitPattern: refcon)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        let observation = Unmanaged<AppObservation>.fromOpaque(pointer).takeUnretainedValue()
        observation.deliver(name, element: AXElement(element))
    }
}
