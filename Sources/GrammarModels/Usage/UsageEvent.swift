import Foundation

public enum AIPurpose: String, Codable, Sendable, CaseIterable {
    case check
    case rewrite
    case tone
    case compose

    public var displayName: String {
        switch self {
        case .check: "Checks"
        case .rewrite: "Rewrites"
        case .tone: "Tone detection"
        case .compose: "Write with AI"
        }
    }
}

public struct UsageEvent: Sendable, Equatable {
    public var provider: AIProvider
    public var model: String
    public var purpose: AIPurpose
    public var tokens: TokenUsage

    public init(provider: AIProvider, model: String, purpose: AIPurpose, tokens: TokenUsage) {
        self.provider = provider
        self.model = model
        self.purpose = purpose
        self.tokens = tokens
    }
}
