import Foundation
import GrammarModels

public struct LocalServerClient {
    public var listModels: (_ address: String) async throws -> [String]
    public var testModel: (_ address: String, _ model: String) async throws -> LocalModelTestResult

    public init(
        listModels: @escaping (_ address: String) async throws -> [String],
        testModel: @escaping (_ address: String, _ model: String) async throws -> LocalModelTestResult
    ) {
        self.listModels = listModels
        self.testModel = testModel
    }
}

enum LocalServerMessages {
    static func testSucceeded(model: String, result: LocalModelTestResult, locale: Locale = .current) -> String {
        let seconds = Double(result.duration.components.seconds) + Double(result.duration.components.attoseconds) / 1e18
        let time = "\(seconds.formatted(.number.precision(.fractionLength(1)).locale(locale))) s"
        if result.suggestionCount == 0 {
            return "\(model) answered in \(time) but missed the mistakes in the test sentence. A larger model may catch more."
        }
        return "\(model) works: it checked a test sentence in \(time)."
    }

    static func message(for error: any Error) -> String {
        if case let .failed(reason)? = error as? RewriteError {
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return APIKeyMessages.message(for: error)
    }
}
