import Foundation
import GrammarModels
import os

final class ChatCompletionsClient: Sendable {
    static let minimumTimeout: TimeInterval = 60
    static let testTimeout: TimeInterval = 120

    let session: URLSession
    let minimumTimeout: TimeInterval

    init(session: URLSession = ChatCompletionsClient.makeDefaultSession(), minimumTimeout: TimeInterval = ChatCompletionsClient.minimumTimeout) {
        self.session = session
        self.minimumTimeout = minimumTimeout
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = minimumTimeout
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func createMessage(
        _ request: MessageRequest,
        baseURL: URL,
        apiKey: String? = nil,
        style: CloudService.RequestStyle = .standard
    ) async -> Result<MessageResponse, AIError> {
        var urlRequest = URLRequest(url: baseURL.appending(path: "chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if let apiKey { urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization") }
        urlRequest.httpBody = Self.chatBody(request, style: style).data
        urlRequest.timeoutInterval = max(request.timeout, minimumTimeout)
        return await send(urlRequest).flatMap(Self.decodeCompletion)
    }

    func listModels(baseURL: URL, apiKey: String? = nil) async -> Result<[String], AIError> {
        var urlRequest = URLRequest(url: baseURL.appending(path: "models"))
        if let apiKey { urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization") }
        urlRequest.timeoutInterval = 15
        return await send(urlRequest).flatMap(Self.decodeModels)
    }

    static func chatBody(_ request: MessageRequest, style: CloudService.RequestStyle = .standard) -> JSONValue {
        var system = request.system
        if let schema = request.outputSchema, style.structuredOutput != .jsonSchema {
            system += "\n\n" + schemaInstruction(schema)
        }
        var body: [(String, JSONValue)] = [
            ("model", .string(request.model)),
            ("messages", .array([
                .object([("role", .string(style.systemRole)), ("content", .string(system))]),
                .object([("role", .string("user")), ("content", .string(request.userText))]),
            ])),
            (style.outputLimit == .maxCompletionTokens ? "max_completion_tokens" : "max_tokens", .int(request.maxTokens)),
            ("stream", .bool(false)),
        ]
        if let effort = style.reasoningEffort {
            body.append(("reasoning_effort", .string(effort)))
        }
        if let schema = request.outputSchema {
            switch style.structuredOutput {
            case .jsonSchema:
                body.append(("response_format", .object([
                    ("type", .string("json_schema")),
                    ("json_schema", .object([
                        ("name", .string("response")),
                        ("strict", .bool(true)),
                        ("schema", schema),
                    ])),
                ])))
            case .jsonObject:
                body.append(("response_format", .object([("type", .string("json_object"))])))
            case .none:
                break
            }
        }
        return .object(body)
    }

    static func schemaInstruction(_ schema: JSONValue) -> String {
        """
        Reply with a single JSON object and nothing else: no prose, no code fences. It must match \
        this JSON Schema exactly:
        \(schema.serialized)
        """
    }

    private func send(_ urlRequest: URLRequest) async -> Result<Data, AIError> {
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
                Log.engine.error("Chat completions request failed: \(String(describing: mapped), privacy: .public)")
            }
            return .failure(mapped)
        }

        switch response.statusCode {
        case 200..<300:
            return .success(data)
        case 401:
            return .failure(.invalidAPIKey)
        case 400, 403:
            let message = Self.errorMessage(in: data)
            if message?.localizedCaseInsensitiveContains("api key") == true { return .failure(.invalidAPIKey) }
            Log.engine.error("Chat completions HTTP \(response.statusCode, privacy: .public): \(message ?? "", privacy: .private)")
            return .failure(.http(status: response.statusCode, message: message))
        case 429 where Self.isQuotaExhausted(data):
            return .failure(.http(status: 429, message: Self.errorMessage(in: data)))
        case 429, 502, 503, 529:
            Log.engine.info("Chat completions server busy (HTTP \(response.statusCode, privacy: .public))")
            return .failure(.busy)
        default:
            let message = Self.errorMessage(in: data)
            Log.engine.error("Chat completions HTTP \(response.statusCode, privacy: .public): \(message ?? "", privacy: .private)")
            return .failure(.http(status: response.statusCode, message: message))
        }
    }

    static func map(_ error: any Error) -> AIError {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .network(String(describing: error)) }
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timedOut
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost,
             .notConnectedToInternet, .dataNotAllowed:
            return .serverUnreachable
        default:
            return .network(urlError.localizedDescription)
        }
    }

    static func decodeCompletion(_ data: Data) -> Result<MessageResponse, AIError> {
        guard let wire = try? JSONDecoder().decode(WireCompletion.self, from: data),
              let choice = wire.choices.first else {
            return .failure(.invalidResponse)
        }
        let stopReason: String? = switch choice.finishReason {
        case "length": "max_tokens"
        case "content_filter": "refusal"
        case nil: nil
        default: "end_turn"
        }
        let text = stripReasoning(choice.message?.content ?? "")
        let usage = wire.usage.map { usage in
            let prompt = usage.promptTokens ?? 0
            let cached = min(prompt, usage.cachedTokens ?? 0)
            return TokenUsage(input: prompt - cached, output: usage.completionTokens ?? 0, cacheRead: cached)
        }
        return .success(MessageResponse(text: text, stopReason: stopReason, model: wire.model, usage: usage))
    }

    static func stripReasoning(_ text: String) -> String {
        guard let open = text.range(of: "<think>") else { return text }
        guard let close = text.range(of: "</think>", range: open.upperBound..<text.endIndex) else {
            return String(text[..<open.lowerBound])
        }
        return stripReasoning(String(text[..<open.lowerBound]) + String(text[close.upperBound...]))
    }

    static func decodeModels(_ data: Data) -> Result<[String], AIError> {
        guard let wire = try? JSONDecoder().decode(WireModels.self, from: data) else {
            return .failure(.invalidResponse)
        }
        let ids = wire.data.map { $0.id.hasPrefix("models/") ? String($0.id.dropFirst("models/".count)) : $0.id }
            .filter { !$0.localizedCaseInsensitiveContains("embed") }
        return .success(ids.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    static func isQuotaExhausted(_ data: Data) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let error = object["error"] as? [String: Any] else { return false }
        let markers = [error["type"] as? String, error["code"] as? String, error["status"] as? String].compactMap { $0?.lowercased() }
        return markers.contains { $0.contains("quota") || $0.contains("exhausted") || $0.contains("spend_limit") || $0.contains("billing") }
    }

    static func errorMessage(in data: Data) -> String? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let error = object["error"] as? [String: Any] { return error["message"] as? String }
        return object["error"] as? String ?? object["message"] as? String
    }

    private struct WireCompletion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String?
            }

            var message: Message?
            var finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        struct Usage: Decodable {
            var promptTokens: Int?
            var completionTokens: Int?
            var promptTokensDetails: [String: Int?]?

            var cachedTokens: Int? { promptTokensDetails?["cached_tokens"] ?? nil }

            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case promptTokensDetails = "prompt_tokens_details"
            }
        }

        var choices: [Choice]
        var model: String?
        var usage: Usage?
    }

    private struct WireModels: Decodable {
        struct Model: Decodable {
            var id: String
        }

        var data: [Model]
    }
}
