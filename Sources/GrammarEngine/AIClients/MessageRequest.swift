import Foundation
import GrammarModels

struct MessageRequest: Sendable {
    var model: String
    var maxTokens: Int
    var system: String
    var userText: String
    var effort: String
    var outputSchema: JSONValue?
    var timeout: TimeInterval
    var purpose: AIPurpose = .check
}

struct MessageResponse: Sendable, Equatable {
    var text: String
    var stopReason: String?
    var model: String?
    var usage: TokenUsage?
}
