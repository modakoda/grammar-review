import Foundation
import GrammarModels
import Observation

@Observable
final class LocalServerModel {
    enum ListState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var models: [String] = []
    private(set) var listState: ListState = .idle
    private(set) var testState: APIKeyTestState = .idle

    @ObservationIgnored private let client: LocalServerClient
    @ObservationIgnored private(set) var listTask: Task<Void, Never>?
    @ObservationIgnored private(set) var testTask: Task<Void, Never>?
    @ObservationIgnored private var listedAddress: String?

    init(client: LocalServerClient) {
        self.client = client
    }

    var isTesting: Bool { testState == .testing }

    func refreshModels(address: String) {
        listTask?.cancel()
        if address != listedAddress {
            models = []
            listedAddress = nil
        }
        listState = .loading
        let listModels = client.listModels
        listTask = Task { [weak self] in
            let result: Result<[String], any Error>
            do {
                result = .success(try await listModels(address))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let models):
                self.models = models
                self.listedAddress = address
                self.listState = .loaded
            case .failure(let error):
                self.models = []
                self.listedAddress = nil
                self.listState = .failed(LocalServerMessages.message(for: error))
            }
        }
    }

    func test(address: String, model: String) {
        testTask?.cancel()
        testState = .testing
        let testModel = client.testModel
        testTask = Task { [weak self] in
            let outcome: APIKeyTestState
            do {
                let result = try await testModel(address, model)
                outcome = .succeeded(LocalServerMessages.testSucceeded(model: model, result: result))
            } catch {
                outcome = .failed(LocalServerMessages.message(for: error))
            }
            guard !Task.isCancelled else { return }
            self?.testState = outcome
        }
    }

    func clearTestResult() {
        cancelTest()
        testState = .idle
    }

    func cancelTest() {
        testTask?.cancel()
        testTask = nil
        if testState == .testing { testState = .idle }
    }

    func cancelAll() {
        listTask?.cancel()
        listTask = nil
        if listState == .loading { listState = .idle }
        cancelTest()
    }
}
