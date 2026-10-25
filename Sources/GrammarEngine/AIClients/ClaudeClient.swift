import Foundation
import GrammarModels
import os

final class ClaudeClient: Sendable {
    static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    static let apiVersion = "2026-10-21"
    static let defaultTimeout: TimeInterval = 20
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    static let modelsWithServerFallback: Set<String> = ["claude-sonnet-5-5", "claude-opus-5-5", "claude-opus-5", "claude-fable-5-1"]

    let session: URLSession
    let baseURL: URL
    let retryDelay: Duration
    let maxRetryDelay: Duration
    private let fallbacksRejected = OSAllocatedUnfairLock(initialState: false)

    init(
        session: URLSession = ClaudeClient.makeDefaultSession(),
        baseURL: URL = ClaudeClient.defaultBaseURL,
        retryDelay: Duration = .seconds(1),
        maxRetryDelay: Duration = .seconds(5)
    ) {
        self.session = session
        self.baseURL = baseURL
        self.retryDelay = retryDelay
        self.maxRetryDelay = maxRetryDelay
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = defaultTimeout
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func createMessage(_ request: MessageRequest, apiKey: String) async -> Result<MessageResponse, AIError> {
        let useFallbacks = Self.modelsWithServerFallback.contains(request.model) && !fallbacksRejected.withLock { $0 }
        let first = await post(
            path: "v1/messages", body: Self.messageBody(request, fallbacks: useFallbacks).data,
            apiKey: apiKey, beta: useFallbacks ? Self.fallbackBeta : nil, timeout: request.timeout
        )
        if useFallbacks, case .failure(.http(400, let message)) = first, Self.mentionsFallbacks(message) {
            fallbacksRejected.withLock { $0 = true }
            Log.engine.info("Server-side fallbacks were rejected; continuing without them")
            let second = await post(
                path: "v1/messages", body: Self.messageBody(request, fallbacks: false).data,
                apiKey: apiKey, beta: nil, timeout: request.timeout
            )
            return second.flatMap(Self.decodeMessage)
        }
        return first.flatMap(Self.decodeMessage)
    }

    func countTokens(model: String, apiKey: String) async -> Result<Void, AIError> {
        let body = JSONValue.object([
            ("model", .string(model)),
            ("messages", .array([.object([("role", .string("user")), ("content", .string("Hi"))])])),
        ])
        return await post(path: "v1/messages/count_tokens", body: body.data, apiKey: apiKey, beta: nil, timeout: Self.defaultTimeout)
            .map { _ in () }
    }

    static func messageBody(_ request: MessageRequest, fallbacks: Bool) -> JSONValue {
        var outputConfig: [(String, JSONValue)] = [("effort", .string(request.effort))]
        if let schema = request.outputSchema {
            outputConfig.append(("format", .object([("type", .string("json_schema")), ("schema", schema)])))
        }
        var body: [(String, JSONValue)] = [
            ("model", .string(request.model)),
            ("max_tokens", .int(request.maxTokens)),
            ("system", .array([.object([
                ("type", .string("text")),
                ("text", .string(request.system)),
                ("cache_control", .object([("type", .string("ephemeral"))])),
            ])])),
            ("messages", .array([.object([("role", .string("user")), ("content", .string(request.userText))])])),
            ("output_config", .object(outputConfig)),
        ]
        if fallbacks { body.append(("fallbacks", .string("default"))) }
        return .object(body)
    }

    private func post(path: String, body: Data, apiKey: String, beta: String?, timeout: TimeInterval) async -> Result<Data, AIError> {
        var urlRequest = URLRequest(url: baseURL.appending(path: path))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if let beta { urlRequest.setValue(beta, forHTTPHeaderField: "anthropic-beta") }
        urlRequest.httpBody = body

        var attempt = 0
        while true {
            attempt += 1
            let data: Data
            let response: HTTPURLResponse
            do {
                let (payload, urlResponse) = try await session.data(for: urlRequest)
                guard let http = urlResponse as? HTTPURLResponse else { return .failure(.invalidResponse) }
                data = payload
                response = http
            } catch {
                let mapped = Self.map(error)
                if mapped != .cancelled {
                    Log.engine.error("Claude request failed: \(String(describing: mapped), privacy: .public)")
                }
                return .failure(mapped)
            }

            switch response.statusCode {
            case 200..<300:
                return .success(data)
            case 401:
                Log.engine.error("Claude rejected the API key (HTTP 401)")
                return .failure(.invalidAPIKey)
            case 429 where Self.isSpendCapReached(data):
                Log.engine.error("Claude organization reached its monthly spend cap")
                return .failure(.http(status: 429, message: Self.errorMessage(in: data)))
            case 429, 500...599:
                Log.engine.info("Claude busy (HTTP \(response.statusCode, privacy: .public)), attempt \(attempt, privacy: .public)")
                guard attempt == 1 else { return .failure(.busy) }
                let delay = Self.retryAfter(response).map { min($0, maxRetryDelay) } ?? retryDelay
                if delay > .zero {
                    do { try await Task.sleep(for: delay) } catch { return .failure(.cancelled) }
                }
                if Task.isCancelled { return .failure(.cancelled) }
            default:
                let message = Self.errorMessage(in: data)
                Log.engine.error("Claude HTTP \(response.statusCode, privacy: .public): \(message ?? "", privacy: .private)")
                return .failure(.http(status: response.statusCode, message: message))
            }
        }
    }

    static func map(_ error: any Error) -> AIError {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .network(String(describing: error)) }
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .network(urlError.localizedDescription)
        }
    }

    static func decodeMessage(_ data: Data) -> Result<MessageResponse, AIError> {
        guard let wire = try? JSONDecoder().decode(WireMessage.self, from: data) else {
            return .failure(.invalidResponse)
        }
        let lastFallback = wire.content.lastIndex { $0.type == "fallback" }
        let answerBlocks = lastFallback.map { wire.content[wire.content.index(after: $0)...] } ?? wire.content[...]
        let text = answerBlocks.filter { $0.type == "text" }.compactMap(\.text).joined()
        let usage = wire.usage.map { usage in
            TokenUsage(
                input: usage.inputTokens ?? 0,
                output: usage.outputTokens ?? 0,
                cacheWrite: usage.cacheCreationInputTokens ?? 0,
                cacheRead: usage.cacheReadInputTokens ?? 0
            )
        }
        return .success(MessageResponse(text: text, stopReason: wire.stopReason, model: wire.model, usage: usage))
    }

    static func errorMessage(in data: Data) -> String? {
        (try? JSONDecoder().decode(WireError.self, from: data))?.error.message
    }

    static func isSpendCapReached(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(WireError.self, from: data))?.error.details?.errorCode == "enforced_spend_limit_reached"
    }

    static func mentionsFallbacks(_ message: String?) -> Bool {
        guard let message = message?.lowercased() else { return false }
        return message.contains("fallback") || message.contains("anthropic-beta")
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "retry-after"),
              let seconds = Double(value.trimmedWhitespace), seconds >= 0 else { return nil }
        return .milliseconds(Int(seconds * 1000))
    }

    private struct WireMessage: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }

        struct Usage: Decodable {
            var inputTokens: Int?
            var outputTokens: Int?
            var cacheCreationInputTokens: Int?
            var cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        var content: [Block]
        var stopReason: String?
        var model: String?
        var usage: Usage?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
            case model
            case usage
        }
    }

    private struct WireError: Decodable {
        struct Detail: Decodable {
            var type: String?
            var message: String?
            var details: Details?
        }

        struct Details: Decodable {
            var errorCode: String?

            enum CodingKeys: String, CodingKey {
                case errorCode = "error_code"
            }
        }

        var error: Detail
    }
}
