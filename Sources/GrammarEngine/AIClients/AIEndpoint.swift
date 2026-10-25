import Foundation
import GrammarModels

enum AIEndpoint: Sendable, Equatable {
    case claude(model: String, apiKey: String)
    case cloud(service: CloudService, model: String, apiKey: String)
    case local(baseURL: URL, model: String)

    var model: String {
        switch self {
        case .claude(let model, _), .cloud(_, let model, _), .local(_, let model): model
        }
    }

    var provider: AIProvider {
        switch self {
        case .claude: .claude
        case .cloud(let service, _, _): .cloud(service.id)
        case .local: .local
        }
    }

    var cacheID: String {
        switch self {
        case .claude(let model, _): model
        case .cloud(let service, let model, _): "\(service.id)#\(model)"
        case .local(let baseURL, let model): "\(baseURL.absoluteString)#\(model)"
        }
    }
}
