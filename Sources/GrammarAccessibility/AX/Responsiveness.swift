import ApplicationServices
import CoreGraphics
import Foundation

nonisolated struct Responsiveness {
    var timeoutsBeforeBackoff = 2
    var backoff: Duration = .seconds(1)
    private(set) var consecutiveTimeouts = 0
    private(set) var suspendedUntil: ContinuousClock.Instant?

    init() {}

    mutating func record(_ error: AXError, elapsed: Duration, now: ContinuousClock.Instant = .now) {
        if error == .cannotComplete, elapsed >= AccessibilityTiming.timeoutDetectionThreshold {
            consecutiveTimeouts += 1
            if consecutiveTimeouts >= timeoutsBeforeBackoff {
                suspendedUntil = now + backoff
                consecutiveTimeouts = 0
            }
        } else {
            consecutiveTimeouts = 0
        }
    }

    func isSuspended(now: ContinuousClock.Instant = .now) -> Bool {
        guard let suspendedUntil else { return false }
        return now < suspendedUntil
    }
}
