import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

@Suite struct UsageLedgerTests {
    static let haiku = UsageEvent(provider: .claude, model: "claude-haiku-5-5", purpose: .check, tokens: TokenUsage(input: 1_000_000, output: 1_000_000))

    @Test func pricesFollowTheModel() throws {
        let haiku = try #require(ModelPricing.forModel("claude-haiku-5-5"))
        #expect(abs(haiku.cost(of: TokenUsage(input: 1_000_000, output: 1_000_000, cacheWrite: 1_000_000, cacheRead: 1_000_000)) - 0.735) < 1e-9)
        let opus = try #require(ModelPricing.forModel("claude-opus-5-5"))
        #expect(abs(opus.cost(of: TokenUsage(input: 500_000, output: 100_000)) - 4.0) < 1e-9)
        #expect(opus.cacheRead == 0.20)
        let sonnet = try #require(ModelPricing.forModel("claude-sonnet-5-5"))
        #expect([sonnet.input, sonnet.cacheWrite, sonnet.cacheRead, sonnet.output] == [2, 2.5, 0.10, 10])
        #expect(ModelPricing.forModel("claude-unknown") == nil)
    }

    @Test func recordingAddsUpPerModelAndPurpose() {
        var ledger = UsageLedger(month: "2026-10")
        ledger.record(Self.haiku, month: "2026-10")
        ledger.record(Self.haiku, month: "2026-10")
        var rewrite = Self.haiku
        rewrite.purpose = .rewrite
        ledger.record(rewrite, month: "2026-10")
        ledger.record(UsageEvent(provider: .local, model: "qwen3", purpose: .check, tokens: TokenUsage(input: 50, output: 5)), month: "2026-10")

        let period = ledger.current
        #expect(period.entries.count == 3)
        #expect(period.requests == 4)
        #expect(period.requestsByPurpose.map(\.purpose) == [.check, .rewrite])
        #expect(period.requestsByPurpose.first?.requests == 3)
        #expect(abs(period.estimatedCost - 1.8) < 1e-9, "three Haiku requests at $0.60; local is free")
        #expect(!period.hasUnpricedUsage)
        #expect(period.byModel.map(\.model) == ["claude-haiku-5-5", "qwen3"])
        #expect(period.byModel.first?.requests == 3)
    }

    @Test func unknownModelsAreFlagged() {
        var ledger = UsageLedger(month: "2026-10")
        ledger.record(UsageEvent(provider: .claude, model: "claude-new", purpose: .check, tokens: TokenUsage(input: 5)), month: "2026-10")
        #expect(ledger.current.hasUnpricedUsage)
        #expect(ledger.current.estimatedCost == 0)
    }

    @Test func aNewMonthKeepsTheLastOne() {
        var ledger = UsageLedger(month: "2026-11")
        ledger.record(Self.haiku, month: "2026-11")
        ledger.record(Self.haiku, month: "2026-12")
        #expect(ledger.current.month == "2026-12" && ledger.current.requests == 1)
        #expect(ledger.previous?.month == "2026-11")

        ledger.roll(to: "2027-01")
        #expect(ledger.previous?.month == "2026-12", "across the year")
        ledger.roll(to: "2027-03")
        #expect(ledger.previous == nil, "a month without usage in between")
        ledger.roll(to: "2027-02")
        #expect(ledger.current.month == "2027-03", "the clock going back doesn't roll")
    }

    @Test func monthOfADate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(UsageLedger.month(of: Date(timeIntervalSince1970: 1_790_000_000), calendar: calendar) == "2026-09")
    }
}
