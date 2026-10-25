import Foundation

public protocol GrammarChecking: AnyObject, Sendable {
    func check(_ request: CheckRequest) -> AsyncStream<CheckResult>

    func learnWord(_ word: String)
}
