import Foundation
import GrammarModels
import os
@testable import GrammarEngine

enum MockReply: Sendable {
    case response(status: Int, headers: [String: String] = [:], body: Data)
    case failure(URLError.Code)

    static func json(_ status: Int, _ body: String, headers: [String: String] = [:]) -> MockReply {
        .response(status: status, headers: headers, body: Data(body.utf8))
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest, Data) -> MockReply
    private static let handlers = OSAllocatedUnfairLock<[String: Handler]>(initialState: [:])

    static func register(host: String, handler: @escaping Handler) {
        handlers.withLock { $0[host] = handler }
    }

    static func unregister(host: String) {
        _ = handlers.withLock { $0.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host(),
              let handler = Self.handlers.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request, Self.body(of: request)) {
        case .response(let status, let headers, let body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

struct RecordedRequest: Sendable {
    var request: URLRequest
    var body: Data

    var path: String { request.url?.path() ?? "" }
    func header(_ name: String) -> String? { request.value(forHTTPHeaderField: name) }
    var json: [String: Any] { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:] }
}

final class MockServer: Sendable {
    let host: String
    let session: URLSession
    private let log: OSAllocatedUnfairLock<[RecordedRequest]>

    init(respond: @escaping @Sendable (_ attempt: Int, _ request: RecordedRequest) -> MockReply) {
        let host = "mock-\(UUID().uuidString.lowercased()).test"
        let log = OSAllocatedUnfairLock<[RecordedRequest]>(initialState: [])
        MockURLProtocol.register(host: host) { request, body in
            let recorded = RecordedRequest(request: request, body: body)
            let attempt = log.withLock { requests in
                requests.append(recorded)
                return requests.count
            }
            return respond(attempt, recorded)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        self.host = host
        self.log = log
        self.session = URLSession(configuration: configuration)
    }

    deinit { MockURLProtocol.unregister(host: host) }

    var baseURL: URL { URL(string: "https://\(host)")! }
    var requests: [RecordedRequest] { log.withLock { $0 } }

    func client() -> ClaudeClient {
        ClaudeClient(session: session, baseURL: baseURL, retryDelay: .zero)
    }

    func localClient() -> ChatCompletionsClient {
        ChatCompletionsClient(session: session)
    }
}

func messageBody(text: String, stopReason: String = "end_turn", extraBlocks: String = "") -> String {
    let escaped = JSONValue.string(text).serialized
    return """
    {"id":"msg_test","type":"message","role":"assistant","model":"claude-haiku-5-5",\
    "content":[{"type":"thinking","thinking":"","signature":"sig"},\(extraBlocks){"type":"text","text":\(escaped)}],\
    "stop_reason":"\(stopReason)","usage":{"input_tokens":12,"output_tokens":34}}
    """
}

func editsJSON(_ edits: [AIEdit]) -> String {
    JSONValue.object([("edits", .array(edits.map { edit in
        .object([
            ("context_before", .string(edit.contextBefore)),
            ("original", .string(edit.original)),
            ("replacement", .string(edit.replacement)),
            ("explanation", .string(edit.explanation)),
            ("category", .string(edit.category.rawValue)),
        ])
    }))]).serialized
}

struct MockSpellChecker: SpellChecking {
    var words: [String: [String]] = ["teh": ["the", "tech"]]

    func misspellings(in text: String, language: String?, resolver: LanguageResolver, settings: AppSettings) async -> [TextIssue] {
        var issues: [TextIssue] = []
        let ns = text as NSString
        for (word, guesses) in words {
            let regex = try! NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b")
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                issues.append(TextIssue(range: match.range, originalText: word, replacements: guesses,
                                        message: "Possible spelling mistake.", category: .spelling, source: .local))
            }
        }
        return issues.sorted { $0.range.location < $1.range.location }
    }

    func learnWord(_ word: String) {}
}

final class MockAIService: GrammarAIService {
    private struct State {
        var calls: [String] = []
        var languages: [String?] = []
        var goals: [WritingGoals] = []
        var endpoints: [AIEndpoint] = []
        var inFlight = 0
        var maxInFlight = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let handler: @Sendable (String) async -> Result<[AIEdit], AIError>

    init(handler: @escaping @Sendable (String) async -> Result<[AIEdit], AIError> = { _ in .success([]) }) {
        self.handler = handler
    }

    var calls: [String] { state.withLock { $0.calls } }
    var languages: [String?] { state.withLock { $0.languages } }
    var goals: [WritingGoals] { state.withLock { $0.goals } }
    var endpoints: [AIEndpoint] { state.withLock { $0.endpoints } }
    var maxInFlight: Int { state.withLock { $0.maxInFlight } }

    func proofread(paragraph: String, language: String?, goals: WritingGoals, endpoint: AIEndpoint) async -> Result<[AIEdit], AIError> {
        state.withLock { state in
            state.calls.append(paragraph)
            state.languages.append(language)
            state.goals.append(goals)
            state.endpoints.append(endpoint)
            state.inFlight += 1
            state.maxInFlight = max(state.maxInFlight, state.inFlight)
        }
        let result = await handler(paragraph)
        state.withLock { $0.inFlight -= 1 }
        return result
    }
}

final class Flag: Sendable {
    private let value = OSAllocatedUnfairLock<Bool?>(initialState: nil)
    func set(_ newValue: Bool) { value.withLock { $0 = newValue } }
    var get: Bool? { value.withLock { $0 } }
}

func makeEngine(
    ai: MockAIService = MockAIService(),
    spell: MockSpellChecker = MockSpellChecker(),
    key: String? = "sk-test",
    keyCalledOnMain: Flag? = nil,
    keyboard: KeyboardLanguages = KeyboardLanguages(),
    harper: (any HarperLinting)? = nil
) -> HybridGrammarEngine {
    HybridGrammarEngine(
        apiKeyProvider: { _ in
            keyCalledOnMain?.set(Thread.isMainThread)
            return key
        },
        spellChecker: spell,
        harper: harper,
        harperLocator: HarperLocator(environment: [:], home: "/Users/test", isExecutable: { $0 == "/opt/homebrew/bin/harper-ls" }),
        aiService: ai,
        backends: AIBackends(
            claude: ClaudeClient(baseURL: URL(string: "https://unused.invalid")!, retryDelay: .zero),
            local: ChatCompletionsClient()
        ),
        keyboardLanguages: { keyboard }
    )
}

func testSettings(aiDelay: Double = 0, configure: (inout AppSettings) -> Void = { _ in }) -> AppSettings {
    var settings = AppSettings()
    settings.aiDelay = aiDelay
    settings.languageMode = .fixed("en")
    configure(&settings)
    return settings
}

func collect(_ stream: AsyncStream<CheckResult>) async -> [CheckResult] {
    var results: [CheckResult] = []
    for await result in stream { results.append(result) }
    return results
}

func edit(_ original: String, _ replacement: String, before: String = "", _ category: IssueCategory = .grammar, _ explanation: String = "Fix.") -> AIEdit {
    AIEdit(original: original, replacement: replacement, contextBefore: before, explanation: explanation, category: category)
}

func issue(_ location: Int, _ text: String, _ category: IssueCategory = .spelling, source: IssueSource = .local, replacements: [String] = []) -> TextIssue {
    TextIssue(range: NSRange(location: location, length: (text as NSString).length), originalText: text,
              replacements: replacements, message: "m", category: category, source: source)
}

func substring(_ text: String, _ range: NSRange) -> String {
    (text as NSString).substring(with: range)
}

func completionBody(content: String, finishReason: String = "stop") -> String {
    let escaped = JSONValue.string(content).serialized
    return """
    {"id":"chatcmpl-test","object":"chat.completion","model":"qwen3-30b-a3b",\
    "choices":[{"index":0,"message":{"role":"assistant","content":\(escaped)},"finish_reason":"\(finishReason)"}],\
    "usage":{"prompt_tokens":12,"completion_tokens":34}}
    """
}
