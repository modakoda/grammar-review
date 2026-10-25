import Foundation
import GrammarModels
import Observation

@Observable
public final class UsageStore {
    public nonisolated static let defaultsKey = "usage.v1"

    public private(set) var ledger: UsageLedger
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, now: { Date() }, calendar: .current)
    }

    init(defaults: UserDefaults, now: @escaping () -> Date, calendar: Calendar) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        let month = UsageLedger.month(of: now(), calendar: calendar)
        var ledger = defaults.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode(UsageLedger.self, from: $0) }
            ?? UsageLedger(month: month)
        ledger.roll(to: month)
        self.ledger = ledger
    }

    public func record(_ event: UsageEvent) {
        ledger.record(event, month: UsageLedger.month(of: now(), calendar: calendar))
        save()
    }

    public func refresh() {
        let month = UsageLedger.month(of: now(), calendar: calendar)
        guard month > ledger.current.month else { return }
        ledger.roll(to: month)
        save()
    }

    public func reset() {
        ledger = UsageLedger(month: UsageLedger.month(of: now(), calendar: calendar))
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
