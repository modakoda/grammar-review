import Foundation

public enum WritingAudience: String, Codable, Sendable, CaseIterable, Identifiable {
    case general
    case knowledgeable
    case expert

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .general: "General"
        case .knowledgeable: "Knowledgeable"
        case .expert: "Expert"
        }
    }

    public var detail: String {
        switch self {
        case .general: "Easy for anyone to read."
        case .knowledgeable: "Readers who know the subject."
        case .expert: "Specialists; jargon is fine."
        }
    }
}

public enum WritingDomain: String, Codable, Sendable, CaseIterable, Identifiable {
    case general
    case email
    case business
    case academic
    case technical
    case casual
    case creative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .general: "General"
        case .email: "Email"
        case .business: "Business"
        case .academic: "Academic"
        case .technical: "Technical"
        case .casual: "Casual"
        case .creative: "Creative"
        }
    }

    public var detail: String {
        switch self {
        case .general: "No particular conventions."
        case .email: "Clear subject, greeting, ask and sign-off."
        case .business: "Reports, proposals and work documents."
        case .academic: "Papers and essays: precise, hedged claims."
        case .technical: "Documentation and specs: exact and consistent."
        case .casual: "Chats and posts: relaxed rules."
        case .creative: "Stories and copy: voice over rules."
        }
    }
}

public enum WritingIntent: String, Codable, Sendable, CaseIterable, Identifiable {
    case unspecified
    case inform
    case describe
    case convince
    case tellAStory

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .unspecified: "Any"
        case .inform: "Inform"
        case .describe: "Describe"
        case .convince: "Convince"
        case .tellAStory: "Tell a story"
        }
    }
}

public struct WritingGoals: Codable, Sendable, Hashable {
    public var style: WritingStyle
    public var audience: WritingAudience
    public var domain: WritingDomain
    public var intent: WritingIntent

    public init(
        style: WritingStyle = .neutral,
        audience: WritingAudience = .general,
        domain: WritingDomain = .general,
        intent: WritingIntent = .unspecified
    ) {
        self.style = style
        self.audience = audience
        self.domain = domain
        self.intent = intent
    }

    public static let none = WritingGoals()

    public var isNone: Bool { self == .none }

    public var summary: String {
        var parts: [String] = []
        if style != .neutral { parts.append(style.displayName) }
        if audience != .general { parts.append(audience.displayName) }
        if domain != .general { parts.append(domain.displayName) }
        if intent != .unspecified { parts.append(intent.displayName) }
        return parts.isEmpty ? "No goals" : parts.joined(separator: " · ")
    }

    private enum CodingKeys: String, CodingKey {
        case style, audience, domain, intent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = (try? c.decodeIfPresent(WritingStyle.self, forKey: .style)) ?? .neutral
        audience = (try? c.decodeIfPresent(WritingAudience.self, forKey: .audience)) ?? .general
        domain = (try? c.decodeIfPresent(WritingDomain.self, forKey: .domain)) ?? .general
        intent = (try? c.decodeIfPresent(WritingIntent.self, forKey: .intent)) ?? .unspecified
    }
}
