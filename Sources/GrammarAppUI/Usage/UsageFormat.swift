import Foundation
import GrammarModels

enum UsageFormat {
    static func dollars(_ value: Double) -> String {
        if value == 0 { return "$0.00" }
        if value < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", value)
    }

    static func tokens(_ count: Int) -> String {
        switch count {
        case ..<1000: "\(count)"
        case ..<1_000_000: String(format: "%.1fK", Double(count) / 1000)
        default: String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }

    static func monthName(_ month: String, locale: Locale = .current) -> String {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: 15))
        else { return month }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date)
    }
}
