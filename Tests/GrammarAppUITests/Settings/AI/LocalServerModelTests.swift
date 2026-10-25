import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct LocalServerModelTests {
    private static func client(
        models: @escaping (String) async throws -> [String] = { _ in ["gemma-3-27b", "qwen3-30b-a3b"] },
        test: @escaping (String, String) async throws -> LocalModelTestResult = { _, _ in
            LocalModelTestResult(duration: .milliseconds(2_430), suggestionCount: 2)
        }
    ) -> LocalServerClient {
        LocalServerClient(listModels: models, testModel: test)
    }

    @Test func listsTheServersModels() async {
        let model = LocalServerModel(client: Self.client())
        model.refreshModels(address: "http://localhost:1234/v1")
        #expect(model.listState == .loading)
        await model.listTask?.value
        #expect(model.listState == .loaded)
        #expect(model.models == ["gemma-3-27b", "qwen3-30b-a3b"])
    }

    @Test func listFailuresShowTheReasonAndClearTheList() async {
        var fail = false
        let model = LocalServerModel(client: Self.client(models: { _ in
            if fail { throw RewriteError.failed("Can't reach the local AI server. Is it running?") }
            return ["gemma-3-27b"]
        }))
        model.refreshModels(address: "http://localhost:1234/v1")
        await model.listTask?.value
        #expect(model.models == ["gemma-3-27b"])

        fail = true
        model.refreshModels(address: "http://localhost:1234/v1")
        await model.listTask?.value
        #expect(model.listState == .failed("Can't reach the local AI server. Is it running?"))
        #expect(model.models.isEmpty)
    }

    @Test func aNewAddressDropsTheOldList() async {
        let model = LocalServerModel(client: Self.client())
        model.refreshModels(address: "http://localhost:1234/v1")
        await model.listTask?.value
        model.refreshModels(address: "http://localhost:11434/v1")
        #expect(model.models.isEmpty, "the old server's models don't belong to the new one")
        model.cancelAll()
        #expect(model.listState == .idle)
    }

    @Test func testReportsTimeAndQuality() async {
        let model = LocalServerModel(client: Self.client())
        model.test(address: "localhost:1234", model: "gemma-3-27b")
        #expect(model.isTesting)
        await model.testTask?.value
        let result = LocalModelTestResult(duration: .milliseconds(2_430), suggestionCount: 2)
        #expect(model.testState == .succeeded(LocalServerMessages.testSucceeded(model: "gemma-3-27b", result: result)))
        #expect(LocalServerMessages.testSucceeded(model: "gemma-3-27b", result: result, locale: Locale(identifier: "en_US"))
            == "gemma-3-27b works: it checked a test sentence in 2.4 s.")
        #expect(LocalServerMessages.testSucceeded(model: "gemma-3-27b", result: result, locale: Locale(identifier: "lt_LT"))
            == "gemma-3-27b works: it checked a test sentence in 2,4 s.")

        let weak = LocalServerModel(client: Self.client(test: { _, _ in LocalModelTestResult(duration: .seconds(1), suggestionCount: 0) }))
        weak.test(address: "localhost:1234", model: "tiny")
        await weak.testTask?.value
        guard case .succeeded(let message) = weak.testState else {
            Issue.record("expected success, got \(weak.testState)")
            return
        }
        #expect(message.hasPrefix("tiny answered in 1"))
        #expect(message.hasSuffix(" s but missed the mistakes in the test sentence. A larger model may catch more."))
    }

    @Test func testFailuresShowTheEnginesReason() async {
        let model = LocalServerModel(client: Self.client(test: { _, _ in
            throw RewriteError.failed("The local server doesn't have this model. Check the model name in Settings → AI.")
        }))
        model.test(address: "localhost:1234", model: "nope")
        await model.testTask?.value
        #expect(model.testState == .failed("The local server doesn't have this model. Check the model name in Settings → AI."))
        model.clearTestResult()
        #expect(model.testState == .idle)
    }
}
