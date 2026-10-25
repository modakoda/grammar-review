import Foundation

public enum WritingStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case neutral
    case professional
    case formal
    case informal
    case friendly
    case confident
    case concise
    case simple

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .neutral: "Neutral"
        case .professional: "Professional"
        case .formal: "Formal"
        case .informal: "Informal"
        case .friendly: "Friendly"
        case .confident: "Confident"
        case .concise: "Concise"
        case .simple: "Simple"
        }
    }

    public var detail: String {
        switch self {
        case .neutral: "Fix mistakes; keep your own style."
        case .professional: "Polished and courteous, ready for work."
        case .formal: "No slang or contractions; precise and reserved."
        case .informal: "Relaxed and everyday, with contractions."
        case .friendly: "Warm and conversational."
        case .confident: "Direct, without hedging or apologies."
        case .concise: "Shorter, without filler or repetition."
        case .simple: "Plain words and short sentences."
        }
    }
}
