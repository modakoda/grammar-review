import Foundation

public struct PlagiarismSource: Identifiable, Sendable, Equatable {
    public var url: URL
    public var title: String
    public var siteName: String
    public var published: Date?
    public var snippet: String
    public var passages: [NSRange]
    public var similarity: Double

    public var id: String { url.absoluteString }

    public init(url: URL, title: String, siteName: String, published: Date?, snippet: String, passages: [NSRange], similarity: Double) {
        self.url = url
        self.title = title
        self.siteName = siteName
        self.published = published
        self.snippet = snippet
        self.passages = passages
        self.similarity = similarity
    }
}

public struct PlagiarismReport: Sendable, Equatable {
    public var text: String
    public var checkedPassages: [NSRange]
    public var skippedPassages: Int
    public var checkedWords: Int
    public var matchedWords: Int
    public var sources: [PlagiarismSource]

    public init(text: String, checkedPassages: [NSRange], skippedPassages: Int, checkedWords: Int, matchedWords: Int, sources: [PlagiarismSource]) {
        self.text = text
        self.checkedPassages = checkedPassages
        self.skippedPassages = skippedPassages
        self.checkedWords = checkedWords
        self.matchedWords = matchedWords
        self.sources = sources
    }

    public var matchedPassages: [NSRange] {
        var seen = Set<NSRange>()
        return sources.flatMap(\.passages)
            .filter { seen.insert($0).inserted }
            .sorted { $0.location < $1.location }
    }

    public var matchedShare: Double {
        checkedWords == 0 ? 0 : Double(matchedWords) / Double(checkedWords)
    }
}

public struct PlagiarismProgress: Sendable, Equatable {
    public var searched: Int
    public var total: Int

    public init(searched: Int, total: Int) {
        self.searched = searched
        self.total = total
    }
}

public enum PlagiarismError: Error, Sendable, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case usageLimitReached
    case offline
    case tooShort
    case failed(String)

    public var message: String {
        switch self {
        case .missingAPIKey: "Add a Brave Search API key in Settings to check your text against the web."
        case .invalidAPIKey: "Brave Search rejected the API key. Check it in Settings."
        case .rateLimited: "Brave Search is getting too many requests from this key. Wait a moment and try again."
        case .usageLimitReached: "This Brave Search key has used up its plan's searches. Raise the limit in the Brave Search API dashboard."
        case .offline: "You're offline. Connect to the internet to check for plagiarism."
        case .tooShort: "Write a few full sentences (8 words or more) to check them for plagiarism."
        case .failed(let reason): reason
        }
    }

    public var offersSettings: Bool {
        switch self {
        case .missingAPIKey, .invalidAPIKey: true
        case .rateLimited, .usageLimitReached, .offline, .tooShort, .failed: false
        }
    }
}

public protocol PlagiarismChecking: AnyObject, Sendable {
    func checkPlagiarism(_ text: String, progress: @escaping @Sendable (PlagiarismProgress) -> Void) async throws -> PlagiarismReport
}
