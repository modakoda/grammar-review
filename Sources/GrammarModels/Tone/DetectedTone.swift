import Foundation

public enum DetectedTone: String, Codable, Sendable, CaseIterable, Identifiable {
    case confident
    case friendly
    case formal
    case informal
    case optimistic
    case appreciative
    case respectful
    case direct
    case enthusiastic
    case curious
    case encouraging
    case empathetic
    case diplomatic
    case joyful
    case neutral
    case analytical
    case unassuming
    case apologetic
    case urgent
    case concerned
    case worried
    case assertive
    case disapproving
    case accusatory
    case egocentric
    case sad
    case angry

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public var emoji: String {
        switch self {
        case .confident: "😎"
        case .friendly: "🤗"
        case .formal: "🎩"
        case .informal: "😌"
        case .optimistic: "🌤️"
        case .appreciative: "🙏"
        case .respectful: "🤝"
        case .direct: "🎯"
        case .enthusiastic: "🤩"
        case .curious: "🤔"
        case .encouraging: "👍"
        case .empathetic: "💛"
        case .diplomatic: "🕊️"
        case .joyful: "😄"
        case .neutral: "😐"
        case .analytical: "🧐"
        case .unassuming: "🙂"
        case .apologetic: "😅"
        case .urgent: "⏰"
        case .concerned: "😟"
        case .worried: "😰"
        case .assertive: "✊"
        case .disapproving: "😒"
        case .accusatory: "👉"
        case .egocentric: "🪞"
        case .sad: "😢"
        case .angry: "😠"
        }
    }

    public var mayLandBadly: Bool {
        switch self {
        case .disapproving, .accusatory, .egocentric, .angry, .worried: true
        default: false
        }
    }
}
