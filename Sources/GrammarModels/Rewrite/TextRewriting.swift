import Foundation

public enum RewriteError: Error, Sendable, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case textTooLong
    case failed(String)
}

public protocol TextRewriting: AnyObject, Sendable {
    func rewrite(_ text: String, tone: RewriteTone, settings: AppSettings) async throws -> String

    func rewrite(_ text: String, instruction: String, settings: AppSettings) async throws -> String

    func validateAPIKey(_ key: String, model: String) async throws
}
