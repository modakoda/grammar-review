import Foundation
import GrammarModels

enum RewriteGoal {
    case tone(RewriteTone)
    case instruction(String)

    static func message(for error: any Error, feature: String = "use rewrites") -> String {
        switch error as? RewriteError {
        case .missingAPIKey: "Add an Anthropic API key in Settings to \(feature)."
        case .invalidAPIKey: "Your Anthropic API key was rejected. Check it in Settings."
        case .textTooLong: "The selection is too long to rewrite."
        case .failed(let message): message
        case nil: error.localizedDescription
        }
    }
}
