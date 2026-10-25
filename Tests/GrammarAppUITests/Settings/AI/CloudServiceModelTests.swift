import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct CloudServiceModelTests {
    private static let result = LocalModelTestResult(duration: .milliseconds(1_200), suggestionCount: 2)

    private func makeModel(
        key: String? = "sk-proj-test",
        validate: @escaping (CloudService, String, String) async throws -> Void = { _, _, _ in },
        models: @escaping (CloudService, String) async throws -> [String] = { _, _ in ["gpt-6-astra", "gpt-6-luna"] },
        test: @escaping (CloudService, String, String) async throws -> LocalModelTestResult = { _, _, _ in CloudServiceModelTests.result }
    ) -> CloudServiceModel {
        let client = CloudServiceClient(validateKey: validate, listModels: models, testModel: test)
        return CloudServiceModel(service: .openAI, client: client, keyStore: makeKeyStore(backend: InMemorySecretBackend(secret: key)))
    }

    @Test func listsTheServicesModelsWithTheSavedKey() async {
        var keys: [String] = []
        let model = makeModel(models: { _, key in
            keys.append(key)
            return ["gpt-6-astra", "gpt-6-luna"]
        })
        #expect(model.hasKey)
        model.refreshModels()
        #expect(model.listState == .loading)
        await model.listTask?.value
        #expect(model.listState == .loaded)
        #expect(model.liveModels == ["gpt-6-astra", "gpt-6-luna"])
        #expect(keys == ["sk-proj-test"])
    }

    @Test func withoutAKeyThereIsNothingToListOrTest() {
        var calls = 0
        let model = makeModel(key: nil, models: { _, _ in
            calls += 1
            return []
        })
        #expect(!model.hasKey)
        model.refreshModels()
        #expect(model.listState == .idle && model.liveModels.isEmpty)
        model.test(model: "gpt-6-luna")
        #expect(model.testState == .failed("Save your OpenAI API key first."))
        #expect(calls == 0)
    }

    @Test func aListFailureShowsTheReasonAndClearsTheList() async {
        var fail = false
        let model = makeModel(models: { _, _ in
            if fail { throw RewriteError.failed("Invalid OpenAI API key") }
            return ["gpt-6-luna"]
        })
        model.refreshModels()
        await model.listTask?.value
        #expect(model.liveModels == ["gpt-6-luna"])

        fail = true
        model.refreshModels()
        await model.listTask?.value
        #expect(model.listState == .failed("Invalid OpenAI API key"))
        #expect(model.liveModels.isEmpty)
    }

    @Test func testingAModelReportsTheResultOrTheReason() async {
        var tested: [String] = []
        let model = makeModel(test: { service, model, key in
            tested.append("\(service.id) \(model) \(key)")
            return Self.result
        })
        model.test(model: "gpt-6-luna")
        #expect(model.isTesting)
        await model.testTask?.value
        #expect(model.testState == .succeeded(LocalServerMessages.testSucceeded(model: "gpt-6-luna", result: Self.result)))
        #expect(tested == ["openai gpt-6-luna sk-proj-test"])

        let failing = makeModel(test: { _, _, _ in throw RewriteError.failed("OpenAI rate limit or quota reached") })
        failing.test(model: "gpt-6-luna")
        await failing.testTask?.value
        #expect(failing.testState == .failed("OpenAI rate limit or quota reached"))
        failing.clearTestResult()
        #expect(failing.testState == .idle)
    }

    @Test func theKeyIsCheckedWithThisService() async {
        var checked: [String] = []
        let model = makeModel(validate: { service, key, model in checked.append("\(service.id) \(key) \(model)") })
        model.keyModel.draft = " sk-proj-new "
        model.keyModel.test(model: "gpt-6-luna")
        await model.keyModel.testTask?.value
        #expect(checked == ["openai sk-proj-new gpt-6-luna"])
    }

    @Test func cancellingStopsALoadingList() {
        let model = makeModel(models: { _, _ in
            try await Task.sleep(for: .seconds(30))
            return []
        })
        model.refreshModels()
        model.cancelAll()
        #expect(model.listState == .idle)
        #expect(model.liveModels.isEmpty)
    }
}
