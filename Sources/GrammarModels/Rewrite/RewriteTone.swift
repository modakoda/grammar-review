import Foundation

public enum RewriteTone: String, Codable, Sendable, CaseIterable, Identifiable {
    case improve
    case rephrase
    case concise
    case simplify
    case expand
    case professional
    case formal
    case informal
    case friendly
    case confident
    case diplomatic
    case persuasive
    case academic

    public enum Group: String, Sendable, CaseIterable, Identifiable {
        case edit
        case tone

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .edit: "Edit"
            case .tone: "Tone"
            }
        }

        public var tones: [RewriteTone] { RewriteTone.allCases.filter { $0.group == self } }
    }

    public var id: String { rawValue }

    public var group: Group {
        switch self {
        case .improve, .rephrase, .concise, .simplify, .expand: .edit
        case .professional, .formal, .informal, .friendly, .confident, .diplomatic, .persuasive, .academic: .tone
        }
    }

    public var displayName: String {
        switch self {
        case .improve: "Improve"
        case .rephrase: "Rephrase"
        case .concise: "Concise"
        case .simplify: "Simplify"
        case .expand: "Expand"
        case .professional: "Professional"
        case .formal: "Formal"
        case .informal: "Informal"
        case .friendly: "Friendly"
        case .confident: "Confident"
        case .diplomatic: "Diplomatic"
        case .persuasive: "Persuasive"
        case .academic: "Academic"
        }
    }

    public var detail: String {
        switch self {
        case .improve: "Fix mistakes and make it clearer, in the same tone."
        case .rephrase: "Say it another way, with the same meaning and tone."
        case .concise: "Shorter and more direct, keeping every point."
        case .simplify: "Plain words and short sentences."
        case .expand: "More detail and smoother flow, without new facts."
        case .professional: "Polished and courteous, ready for work."
        case .formal: "No slang or contractions; precise and reserved."
        case .informal: "Relaxed and everyday, with contractions."
        case .friendly: "Warm and conversational."
        case .confident: "Direct, without hedging or apologies."
        case .diplomatic: "Tactful and constructive; softens criticism."
        case .persuasive: "Compelling, with a clear ask."
        case .academic: "Objective and precise, for papers and reports."
        }
    }
}
