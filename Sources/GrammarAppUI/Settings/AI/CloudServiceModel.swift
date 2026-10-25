import Foundation
import GrammarModels
import Observation

@Observable
final class CloudServiceModel {
    let service: CloudService
    let keyModel: APIKeyEditorModel
    private(set) var liveModels: [String] = []
    private(set) var listState: LocalServerModel.ListState = .idle
    private(set) var testState: APIKeyTestState = .idle

    @ObservationIgnored private let client: CloudServiceClient
    @ObservationIgnored private let keyStore: APIKeyStore
    @ObservationIgnored private(set) var listTask: Task<Void, Never>?
    @ObservationIgnored private(set) var testTask: Task<Void, Never>?

    init(service: CloudService, client: CloudServiceClient, keyStore: APIKeyStore) {
        self.service = service
        self.client = client
        self.keyStore = keyStore
        keyModel = APIKeyEditorModel(keyStore: keyStore) { key, model in
            try await client.validateKey(service, key, model)
        }
    }

    var isTesting: Bool { testState == .testing }

    var hasKey: Bool { keyModel.source != .none }

    func refreshModels() {
        listTask?.cancel()
        guard let key = keyStore.apiKey() else {
            liveModels = []
            listState = .idle
            return
        }
        listState = .loading
        let listModels = client.listModels
        let service = service
        listTask = Task { [weak self] in
            let result: Result<[String], any Error>
            do {
                result = .success(try await listModels(service, key))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let models):
                self.liveModels = models
                self.listState = .loaded
            case .failure(let error):
                self.liveModels = []
                self.listState = .failed(LocalServerMessages.message(for: error))
            }
        }
    }

    func test(model: String) {
        testTask?.cancel()
        guard let key = keyStore.apiKey() else {
            testState = .failed("Save your \(service.name) API key first.")
            return
        }
        testState = .testing
        let testModel = client.testModel
        let service = service
        testTask = Task { [weak self] in
            let outcome: APIKeyTestState
            do {
                let result = try await testModel(service, model, key)
                outcome = .succeeded(LocalServerMessages.testSucceeded(model: model, result: result))
            } catch {
                outcome = .failed(LocalServerMessages.message(for: error))
            }
            guard !Task.isCancelled else { return }
            self?.testState = outcome
        }
    }

    func clearTestResult() {
        testTask?.cancel()
        testTask = nil
        testState = .idle
    }

    func cancelAll() {
        listTask?.cancel()
        listTask = nil
        if listState == .loading { listState = .idle }
        keyModel.cancelTest()
        clearTestResult()
    }
}

@MainActor
final class CloudServiceModels {
    private let client: CloudServiceClient
    private var models: [String: CloudServiceModel] = [:]

    init(client: CloudServiceClient) {
        self.client = client
    }

    func model(for service: CloudService) -> CloudServiceModel {
        if let existing = models[service.id] { return existing }
        let model = CloudServiceModel(service: service, client: client, keyStore: APIKeyStore.store(for: .cloud(service.id)))
        models[service.id] = model
        return model
    }

    func refreshKeys() {
        for model in models.values { model.keyModel.refresh() }
    }

    func cancelAll() {
        for model in models.values { model.cancelAll() }
    }
}
