import Foundation
import GrammarModels

extension AIError {
    func rewriteError(for endpoint: AIEndpoint) -> any Error {
        switch self {
        case .cancelled: CancellationError()
        case .invalidAPIKey where endpoint.provider == .claude: RewriteError.invalidAPIKey
        default: RewriteError.failed(userMessage(for: endpoint))
        }
    }
}
