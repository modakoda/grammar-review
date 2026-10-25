import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ChatCompletionsClientTests {
    private func check(_ server: MockServer, model: String = "qwen3-30b-a3b") async -> Result<MessageResponse, AIError> {
        let request = CheckPrompt.request(paragraph: "I has a cat.", language: "en", model: model)
        return await server.localClient().createMessage(request, baseURL: server.baseURL.appending(path: "v1"))
    }

    @Test func sendsAnOpenAIChatCompletion() async throws {
        let server = MockServer { _, _ in .json(200, completionBody(content: #"{"edits":[]}"#)) }
        _ = try await check(server).get()
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/chat/completions")
        #expect(request.request.httpMethod == "POST")
        #expect(request.header("content-type") == "application/json")
        #expect(request.header("x-api-key") == nil)
        #expect(request.header("authorization") == nil)
        #expect(request.request.timeoutInterval >= ChatCompletionsClient.minimumTimeout)

        let json = request.json
        #expect(json["model"] as? String == "qwen3-30b-a3b")
        #expect(json["stream"] as? Bool == false)
        #expect((json["max_tokens"] as? Int ?? 0) > 0)
        #expect(json["temperature"] == nil, "sampling is left to the model's preset")
        #expect(json["output_config"] == nil && json["system"] == nil, "no Anthropic-only fields")
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user"])
        #expect(messages[0]["content"] as? String == CheckPrompt.system)
        #expect((messages[1]["content"] as? String)?.contains("<text_to_check>\nI has a cat.\n</text_to_check>") == true)

        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["strict"] as? Bool == true)
        #expect((schema["schema"] as? [String: Any])?["required"] as? [String] == ["edits"])
    }

    @Test func decodesTheAnswer() async throws {
        let edits = editsJSON([edit("has", "have", before: "I ")])
        let server = MockServer { _, _ in .json(200, completionBody(content: edits)) }
        let response = try await check(server).get()
        #expect(response.text == edits)
        #expect(response.stopReason == "end_turn")
        #expect(response.model == "qwen3-30b-a3b")
        #expect(try CheckPrompt.parse(response).get().map(\.replacement) == ["have"])
    }

    @Test func finishReasonsMapToStopReasons() {
        func stopReason(_ finish: String) -> String? {
            try? ChatCompletionsClient.decodeCompletion(Data(completionBody(content: "x", finishReason: finish).utf8)).get().stopReason
        }
        #expect(stopReason("length") == "max_tokens")
        #expect(stopReason("content_filter") == "refusal")
        #expect(stopReason("stop") == "end_turn")
        #expect(ChatCompletionsClient.decodeCompletion(Data(#"{"choices":[]}"#.utf8)) == .failure(.invalidResponse))
        #expect(ChatCompletionsClient.decodeCompletion(Data("not json".utf8)) == .failure(.invalidResponse))
    }

    @Test func reasoningIsStrippedFromTheAnswer() {
        #expect(ChatCompletionsClient.stripReasoning("<think>{maybe}</think>\n{\"edits\":[]}") == "\n{\"edits\":[]}")
        #expect(ChatCompletionsClient.stripReasoning("<think>a</think>x<think>b</think>y") == "xy")
        #expect(ChatCompletionsClient.stripReasoning("<think>never finished") == "")
        #expect(ChatCompletionsClient.stripReasoning("No thinking here.") == "No thinking here.")
    }

    @Test(arguments: [URLError.Code.cannotConnectToHost, .cannotFindHost, .networkConnectionLost])
    func connectionFailuresMeanTheServerIsNotRunning(code: URLError.Code) async {
        let server = MockServer { _, _ in .failure(code) }
        #expect(await check(server) == .failure(.serverUnreachable))
        #expect(AIError.serverUnreachable.userMessage(for: .local) == "Can't reach the local AI server. Is it running?")
        #expect(AIError.serverUnreachable.stopsBatch)
    }

    @Test func busyAndTimeoutsAreNotRetried() async {
        let busy = MockServer { _, _ in .json(503, #"{"error":"Model is loading"}"#) }
        #expect(await check(busy) == .failure(.busy))
        #expect(busy.requests.count == 1)
        let slow = MockServer { _, _ in .failure(.timedOut) }
        #expect(await check(slow) == .failure(.timedOut))
        #expect(AIError.timedOut.userMessage(for: .local) == "The local model took too long to respond")
    }

    @Test func serverErrorsKeepTheirMessage() async {
        let notFound = MockServer { _, _ in .json(404, #"{"error":{"message":"model 'nope' not found","type":"api_error"}}"#) }
        let result = await check(notFound, model: "nope")
        #expect(result == .failure(.http(status: 404, message: "model 'nope' not found")))
        #expect(AIError.http(status: 404, message: nil).userMessage(for: .local) == "The local server doesn't have this model. Check the model name in Settings → AI.")

        let tooLong = MockServer { _, _ in .json(400, #"{"error":"Context length exceeded"}"#) }
        let error = await check(tooLong)
        #expect(error == .failure(.http(status: 400, message: "Context length exceeded")))
        #expect(AIError.http(status: 400, message: "Context length exceeded").userMessage(for: .local) == "Local server error: Context length exceeded")
        #expect(AIError.http(status: 500, message: nil).userMessage(for: .local) == "Local server request failed (HTTP 500)")
    }

    @Test func listsModelsWithoutEmbeddingModels() async throws {
        let server = MockServer { _, _ in
            .json(200, #"{"object":"list","data":[{"id":"qwen3:30b-a3b","object":"model"},{"id":"nomic-embed-text"},{"id":"Gemma-3-27b"},{"id":"llama3.3:70b"}]}"#)
        }
        let models = try await server.localClient().listModels(baseURL: server.baseURL.appending(path: "v1")).get()
        #expect(models == ["Gemma-3-27b", "llama3.3:70b", "qwen3:30b-a3b"])
        #expect(server.requests.first?.path == "/v1/models")
        #expect(server.requests.first?.request.httpMethod == "GET")
    }
}
