import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("Back-off from hung apps")
struct ResponsivenessTests {
    @Test func repeatedTimeoutsSuspendForAWhile() {
        var health = Responsiveness()
        let now = ContinuousClock.now
        health.record(.cannotComplete, elapsed: .milliseconds(250), now: now)
        #expect(!health.isSuspended(now: now))
        health.record(.cannotComplete, elapsed: .milliseconds(250), now: now)
        #expect(health.isSuspended(now: now))
        #expect(health.isSuspended(now: now + .milliseconds(900)))
        #expect(!health.isSuspended(now: now + .seconds(2)))
    }

    @Test func fastFailuresAreNotTimeouts() {
        var health = Responsiveness()
        let now = ContinuousClock.now
        for _ in 0..<5 { health.record(.cannotComplete, elapsed: .milliseconds(2), now: now) }
        #expect(!health.isSuspended(now: now))
    }

    @Test func anAnswerResetsTheCount() {
        var health = Responsiveness()
        let now = ContinuousClock.now
        health.record(.cannotComplete, elapsed: .milliseconds(250), now: now)
        health.record(.success, elapsed: .milliseconds(1), now: now)
        health.record(.cannotComplete, elapsed: .milliseconds(250), now: now)
        #expect(!health.isSuspended(now: now))
    }
}
