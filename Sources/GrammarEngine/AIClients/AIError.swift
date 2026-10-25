import Foundation
import GrammarModels

enum AIError: Error, Sendable, Equatable {
    case invalidAPIKey
    case busy
    case offline
    case serverUnreachable
    case timedOut
    case cancelled
    case refused
    case truncated
    case invalidResponse
    case http(status: Int, message: String?)
    case network(String)

    func userMessage(for provider: AIProvider) -> String {
        switch provider {
        case .claude: claudeMessage
        case .cloud: cloudMessage(name: provider.assistantName, service: provider.cloudService?.name ?? provider.assistantName)
        case .local: localMessage
        }
    }

    func userMessage(for endpoint: AIEndpoint) -> String {
        if case .cloud(let service, _, _) = endpoint { return userMessage(forService: service) }
        return userMessage(for: endpoint.provider)
    }

    func userMessage(forService service: CloudService) -> String {
        cloudMessage(name: service.assistantName, service: service.name)
    }

    private func cloudMessage(name: String, service: String) -> String {
        switch self {
        case .invalidAPIKey: "Invalid \(service) API key"
        case .busy: "\(name) is busy — try again shortly"
        case .offline: "You're offline"
        case .serverUnreachable, .network: "Couldn't reach \(service)"
        case .timedOut: "\(name) took too long to respond"
        case .cancelled: "Cancelled"
        case .refused: "\(name) declined to check this text"
        case .truncated: "\(name)'s answer was cut off"
        case .invalidResponse: "\(name)'s answer wasn't in the expected format"
        case .http(let status, let message):
            switch status {
            case 402: "Billing problem — check your \(service) account"
            case 403: "Your \(service) key can't use this model"
            case 404: "\(service) doesn't have this model. Check the model in Settings → AI."
            case 413: "Text is too long for \(name)"
            case 429: "\(service) rate limit or quota reached"
            default:
                if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                    "\(service) error: \(message.prefix(160))"
                } else {
                    "\(service) request failed (HTTP \(status))"
                }
            }
        }
    }

    private var claudeMessage: String {
        switch self {
        case .invalidAPIKey: "Invalid API key"
        case .busy: "Claude is busy — try again shortly"
        case .offline: "You're offline"
        case .serverUnreachable, .network: "Couldn't reach Claude"
        case .timedOut: "Claude took too long to respond"
        case .cancelled: "Cancelled"
        case .refused: "Claude declined to check this text"
        case .truncated: "Claude's answer was cut off"
        case .invalidResponse: "Unexpected response from Claude"
        case .http(let status, let message):
            switch status {
            case 400 where message?.localizedCaseInsensitiveContains("credit balance") == true:
                "Your Anthropic credit balance is too low"
            case 400 where message?.localizedCaseInsensitiveContains("API usage limits") == true:
                "You've reached the spend limit set in the Claude Console"
            case 400 where message?.localizedCaseInsensitiveContains("anthropic-workspace-id") == true:
                "This API key isn't scoped to a workspace. Create one for a single workspace."
            case 402: "Billing problem — check your Anthropic account"
            case 404: "This model isn't available for your API key"
            case 413: "Text is too long for Claude"
            case 429: "Your Anthropic organization reached its monthly usage limit"
            default:
                if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                    "Claude error: \(message.prefix(160))"
                } else if status == 403 {
                    "Your API key isn't allowed to use this model"
                } else {
                    "Claude request failed (HTTP \(status))"
                }
            }
        }
    }

    private var localMessage: String {
        switch self {
        case .invalidAPIKey: "The local server rejected the request"
        case .busy: "The local server is busy — try again shortly"
        case .offline: "You're offline"
        case .serverUnreachable: "Can't reach the local AI server. Is it running?"
        case .network: "Couldn't reach the local AI server"
        case .timedOut: "The local model took too long to respond"
        case .cancelled: "Cancelled"
        case .refused: "The local model declined to check this text"
        case .truncated: "The local model's answer was cut off"
        case .invalidResponse: "The local model's answer wasn't in the expected format"
        case .http(let status, let message):
            switch status {
            case 404: "The local server doesn't have this model. Check the model name in Settings → AI."
            default:
                if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                    "Local server error: \(message.prefix(160))"
                } else {
                    "Local server request failed (HTTP \(status))"
                }
            }
        }
    }

    var stopsBatch: Bool {
        switch self {
        case .invalidAPIKey, .offline, .serverUnreachable, .cancelled: true
        default: false
        }
    }

    var displayPriority: Int {
        switch self {
        case .invalidAPIKey: 5
        case .offline, .serverUnreachable: 4
        case .http: 3
        case .busy: 2
        case .cancelled: -1
        default: 1
        }
    }
}
