import Foundation

public enum IssueCategory: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case spelling
    case grammar
    case punctuation
    case wordChoice
    case clarity
    case style

    public var id: String { rawValue }

    public var severity: IssueSeverity {
        switch self {
        case .spelling, .grammar, .punctuation: .correctness
        case .wordChoice, .clarity: .clarity
        case .style: .style
        }
    }

    public var displayName: String {
        switch self {
        case .spelling: "Spelling"
        case .grammar: "Grammar"
        case .punctuation: "Punctuation"
        case .wordChoice: "Word choice"
        case .clarity: "Clarity"
        case .style: "Style"
        }
    }
}

public enum IssueSeverity: String, Codable, Sendable, CaseIterable, Hashable {
    case correctness
    case clarity
    case style
}

public enum IssueSource: String, Codable, Sendable, Hashable {
    case local
    case ai
    case styleGuide
}

public struct TextIssue: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var range: NSRange
    public var originalText: String
    public var replacements: [String]
    public var message: String
    public var category: IssueCategory
    public var source: IssueSource

    public init(
        id: UUID = UUID(),
        range: NSRange,
        originalText: String,
        replacements: [String],
        message: String,
        category: IssueCategory,
        source: IssueSource
    ) {
        self.id = id
        self.range = range
        self.originalText = originalText
        self.replacements = replacements
        self.message = message
        self.category = category
        self.source = source
    }

    public var fingerprint: String {
        "\(category.rawValue)|\(originalText)|\(replacements.first ?? "")"
    }
}
