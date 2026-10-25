import Foundation

public enum ToneIntensity: String, Codable, Sendable, CaseIterable, Comparable {
    case slight
    case moderate
    case strong

    private var rank: Int {
        switch self {
        case .slight: 0
        case .moderate: 1
        case .strong: 2
        }
    }

    public static func < (lhs: ToneIntensity, rhs: ToneIntensity) -> Bool { lhs.rank < rhs.rank }
}

public struct ToneScore: Sendable, Equatable, Identifiable {
    public var tone: DetectedTone
    public var intensity: ToneIntensity

    public var id: DetectedTone { tone }

    public init(tone: DetectedTone, intensity: ToneIntensity) {
        self.tone = tone
        self.intensity = intensity
    }
}

public enum Sentiment: String, Codable, Sendable, CaseIterable {
    case positive
    case neutral
    case negative

    public var displayName: String {
        switch self {
        case .positive: "Positive"
        case .neutral: "Neutral"
        case .negative: "Negative"
        }
    }
}

public struct ToneReport: Sendable, Equatable {
    public var tones: [ToneScore]
    public var sentiment: Sentiment
    public var summary: String

    public init(tones: [ToneScore], sentiment: Sentiment, summary: String) {
        self.tones = tones
        self.sentiment = sentiment
        self.summary = summary
    }
}
