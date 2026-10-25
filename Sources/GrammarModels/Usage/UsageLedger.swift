import Foundation

public struct UsageLedger: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var provider: AIProvider
        public var model: String
        public var purpose: AIPurpose
        public var requests: Int
        public var tokens: TokenUsage

        public init(provider: AIProvider, model: String, purpose: AIPurpose, requests: Int = 0, tokens: TokenUsage = .zero) {
            self.provider = provider
            self.model = model
            self.purpose = purpose
            self.requests = requests
            self.tokens = tokens
        }

        public var estimatedCost: Double? {
            switch provider {
            case .local: 0
            case .claude: ModelPricing.forModel(model)?.cost(of: tokens)
            case .cloud(let id): CloudService.find(id)?.pricing(for: model)?.cost(of: tokens)
            }
        }
    }

    public struct Period: Codable, Sendable, Equatable {
        public var month: String
        public var entries: [Entry]

        public init(month: String, entries: [Entry] = []) {
            self.month = month
            self.entries = entries
        }

        public var requests: Int { entries.reduce(0) { $0 + $1.requests } }
        public var tokens: TokenUsage { entries.reduce(.zero) { $0 + $1.tokens } }
        public var estimatedCost: Double { entries.compactMap(\.estimatedCost).reduce(0, +) }
        public var hasUnpricedUsage: Bool { entries.contains { $0.estimatedCost == nil } }

        public var byModel: [Entry] {
            var rows: [String: Entry] = [:]
            for entry in entries {
                let key = "\(entry.provider.rawValue)|\(entry.model)"
                var row = rows[key] ?? Entry(provider: entry.provider, model: entry.model, purpose: entry.purpose)
                row.requests += entry.requests
                row.tokens += entry.tokens
                rows[key] = row
            }
            return rows.values.sorted { ($0.estimatedCost ?? .infinity, $0.tokens.total) > ($1.estimatedCost ?? .infinity, $1.tokens.total) }
        }

        public var requestsByPurpose: [(purpose: AIPurpose, requests: Int)] {
            AIPurpose.allCases.compactMap { purpose in
                let count = entries.filter { $0.purpose == purpose }.reduce(0) { $0 + $1.requests }
                return count > 0 ? (purpose, count) : nil
            }
        }
    }

    public var current: Period
    public var previous: Period?

    public init(month: String) {
        current = Period(month: month)
    }

    public static func month(of date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    public mutating func roll(to month: String) {
        guard month > current.month else { return }
        previous = current.entries.isEmpty ? nil : current
        if let previous, !Self.isMonth(previous.month, justBefore: month) { self.previous = nil }
        current = Period(month: month)
    }

    public mutating func record(_ event: UsageEvent, month: String) {
        roll(to: month)
        if let index = current.entries.firstIndex(where: {
            $0.provider == event.provider && $0.model == event.model && $0.purpose == event.purpose
        }) {
            current.entries[index].requests += 1
            current.entries[index].tokens += event.tokens
        } else {
            current.entries.append(Entry(provider: event.provider, model: event.model, purpose: event.purpose, requests: 1, tokens: event.tokens))
        }
    }

    static func isMonth(_ earlier: String, justBefore later: String) -> Bool {
        let a = earlier.split(separator: "-").compactMap { Int($0) }
        let b = later.split(separator: "-").compactMap { Int($0) }
        guard a.count == 2, b.count == 2 else { return false }
        return a[0] * 12 + a[1] + 1 == b[0] * 12 + b[1]
    }
}
