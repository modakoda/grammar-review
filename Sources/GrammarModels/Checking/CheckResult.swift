import Foundation

public enum AIStatus: Sendable, Equatable {
    case disabled
    case pending
    case completed
    case missingAPIKey
    case textTooLong
    case failed(String)
}

public struct CheckResult: Sendable, Equatable {
    public var text: String
    public var issues: [TextIssue]
    public var language: String?
    public var aiStatus: AIStatus

    public init(text: String, issues: [TextIssue], language: String?, aiStatus: AIStatus) {
        self.text = text
        self.issues = issues
        self.language = language
        self.aiStatus = aiStatus
    }

    public var isFinal: Bool { aiStatus != .pending }
}
