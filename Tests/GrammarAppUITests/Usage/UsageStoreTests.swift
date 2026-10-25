import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct UsageStoreTests {
    static let event = UsageEvent(provider: .claude, model: "claude-haiku-5-5", purpose: .check, tokens: TokenUsage(input: 100, output: 10))

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func persistsAndRollsOverTheMonth() async throws {
        try await withTemporaryDefaults { defaults in
            let clock = TestClock(try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23))))
            let store = UsageStore(defaults: defaults, now: { clock.now }, calendar: calendar)
            store.record(Self.event)
            store.record(Self.event)
            #expect(store.ledger.current.requests == 2)

            let reloaded = UsageStore(defaults: defaults, now: { clock.now }, calendar: calendar)
            #expect(reloaded.ledger == store.ledger)

            clock.now = clock.now.addingTimeInterval(2 * 3600)
            reloaded.refresh()
            #expect(reloaded.ledger.current.month == "2026-11")
            #expect(reloaded.ledger.previous?.requests == 2)

            reloaded.reset()
            #expect(reloaded.ledger == UsageLedger(month: "2026-11"))
            #expect(UsageStore(defaults: defaults, now: { clock.now }, calendar: calendar).ledger == UsageLedger(month: "2026-11"))
        }
    }

    @Test func formatting() {
        #expect(UsageFormat.dollars(0) == "$0.00")
        #expect(UsageFormat.dollars(0.004) == "<$0.01")
        #expect(UsageFormat.dollars(1.234) == "$1.23")
        #expect(UsageFormat.tokens(950) == "950")
        #expect(UsageFormat.tokens(12_340) == "12.3K")
        #expect(UsageFormat.tokens(4_500_000) == "4.5M")
        #expect(UsageFormat.monthName("2026-10", locale: Locale(identifier: "en_US")) == "October 2026")
        #expect(UsageFormat.monthName("garbage") == "garbage")
    }
}
