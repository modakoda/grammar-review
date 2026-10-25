import Foundation

public enum CitationStyle: String, CaseIterable, Identifiable, Sendable {
    case apa
    case mla
    case chicago

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apa: "APA"
        case .mla: "MLA"
        case .chicago: "Chicago"
        }
    }

    public var edition: String {
        switch self {
        case .apa: "APA, 7th edition"
        case .mla: "MLA, 9th edition"
        case .chicago: "Chicago, 17th edition"
        }
    }
}

public enum Citation {
    public static func format(_ source: PlagiarismSource, style: CitationStyle, accessed: Date) -> String {
        let title = source.title.trimmedForCitation
        let site = source.siteName.trimmedForCitation
        let url = source.url.absoluteString
        switch style {
        case .apa:
            let date = source.published.map { "\(year($0)), \(fullMonth($0)) \(day($0))" } ?? "n.d."
            var parts = ["\(sentence(title)) (\(date))."]
            if !site.isEmpty, site.caseInsensitiveCompare(title) != .orderedSame { parts.append(sentence(site)) }
            parts.append(source.published == nil ? "Retrieved \(fullMonth(accessed)) \(day(accessed)), \(year(accessed)), from \(url)" : url)
            return parts.joined(separator: " ")
        case .mla:
            var details = site.isEmpty ? [] : [site]
            if let published = source.published { details.append("\(day(published)) \(shortMonth(published)) \(year(published))") }
            details.append(withoutScheme(url))
            return "\u{201C}\(sentence(title))\u{201D} \(details.joined(separator: ", ")). Accessed \(day(accessed)) \(shortMonth(accessed)) \(year(accessed))."
        case .chicago:
            var parts = ["\u{201C}\(sentence(title))\u{201D}"]
            if !site.isEmpty { parts.append(sentence(site)) }
            if let published = source.published {
                parts.append("\(fullMonth(published)) \(day(published)), \(year(published)).")
            } else {
                parts.append("Accessed \(fullMonth(accessed)) \(day(accessed)), \(year(accessed)).")
            }
            parts.append("\(url).")
            return parts.joined(separator: " ")
        }
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let fullMonths = ["January", "February", "March", "April", "May", "June", "July", "August",
                                     "September", "October", "November", "December"]
    private static let shortMonths = ["Jan.", "Feb.", "Mar.", "Apr.", "May", "June", "July", "Aug.", "Sept.", "Oct.", "Nov.", "Dec."]

    private static func year(_ date: Date) -> Int { calendar.component(.year, from: date) }
    private static func day(_ date: Date) -> Int { calendar.component(.day, from: date) }
    private static func fullMonth(_ date: Date) -> String { fullMonths[calendar.component(.month, from: date) - 1] }
    private static func shortMonth(_ date: Date) -> String { shortMonths[calendar.component(.month, from: date) - 1] }

    private static func sentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".?!".contains(last) ? text : text + "."
    }

    private static func withoutScheme(_ url: String) -> String {
        for scheme in ["https://", "http://"] where url.hasPrefix(scheme) {
            return String(url.dropFirst(scheme.count))
        }
        return url
    }
}

private extension String {
    var trimmedForCitation: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
