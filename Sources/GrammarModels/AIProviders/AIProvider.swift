import Foundation

public enum AIProvider: Sendable, Hashable, CaseIterable, Identifiable {
    case claude
    case cloud(String)
    case local

    public static var allCases: [AIProvider] {
        [.claude] + CloudService.all.map { .cloud($0.id) } + [.local]
    }

    public var rawValue: String {
        switch self {
        case .claude: "claude"
        case .local: "local"
        case .cloud(let id): id
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "claude": self = .claude
        case "local": self = .local
        default:
            guard CloudService.find(rawValue) != nil else { return nil }
            self = .cloud(rawValue)
        }
    }

    public var id: String { rawValue }

    public var cloudService: CloudService? {
        if case .cloud(let id) = self { CloudService.find(id) } else { nil }
    }

    public var usesAPIKey: Bool {
        switch self {
        case .claude, .cloud: true
        case .local: false
        }
    }

    public var displayName: String {
        switch self {
        case .claude: "Claude (Anthropic API)"
        case .cloud(let id): CloudService.find(id).map { "\($0.name) (API key)" } ?? id
        case .local: "Local model (LM Studio, Ollama…)"
        }
    }

    public var assistantName: String {
        switch self {
        case .claude: "Claude"
        case .cloud(let id): CloudService.find(id)?.assistantName ?? id
        case .local: "The local model"
        }
    }
}

extension AIProvider: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let provider = AIProvider(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown AI provider \(raw)"))
        }
        self = provider
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
