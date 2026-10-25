import Foundation
import GrammarModels

actor EditCache {
    struct Key: Hashable, Sendable {
        var model: String
        var language: String
        var goals: WritingGoals
        var text: String

        init(model: String, language: String?, goals: WritingGoals = .none, text: String) {
            self.model = model
            self.language = language ?? ""
            self.goals = goals
            self.text = text
        }
    }

    private struct Entry {
        var edits: [LocatedEdit]
        var lastUse: UInt64
    }

    let capacity: Int
    private var entries: [Key: Entry] = [:]
    private var clock: UInt64 = 0

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    var count: Int { entries.count }

    func values(for keys: [Key]) -> [[LocatedEdit]?] {
        keys.map { key in
            guard var entry = entries[key] else { return nil }
            clock &+= 1
            entry.lastUse = clock
            entries[key] = entry
            return entry.edits
        }
    }

    func value(for key: Key) -> [LocatedEdit]? {
        values(for: [key])[0]
    }

    func insert(_ edits: [LocatedEdit], for key: Key) {
        clock &+= 1
        entries[key] = Entry(edits: edits, lastUse: clock)
        while entries.count > capacity, let oldest = entries.min(by: { $0.value.lastUse < $1.value.lastUse })?.key {
            entries[oldest] = nil
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}
