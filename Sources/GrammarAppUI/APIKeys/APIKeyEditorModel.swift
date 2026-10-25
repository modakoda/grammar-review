import Foundation
import GrammarModels
import Observation

enum APIKeyTestState: Equatable {
    case idle
    case testing
    case succeeded(String)
    case failed(String)
}

@Observable
final class APIKeyEditorModel {
    var draft = "" {
        didSet {
            if draft != oldValue, testState != .testing { testState = .idle }
        }
    }

    private(set) var source: APIKeySource
    private(set) var testState: APIKeyTestState = .idle
    private(set) var saveError: String?

    @ObservationIgnored private let keyStore: APIKeyStore
    @ObservationIgnored private let validate: APIKeyValidator
    @ObservationIgnored private(set) var testTask: Task<Void, Never>?

    init(keyStore: APIKeyStore = .shared, validate: @escaping APIKeyValidator) {
        self.keyStore = keyStore
        self.validate = validate
        source = keyStore.source()
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedDraft.isEmpty }

    var canTest: Bool { canSave || source != .none }

    var isTesting: Bool { testState == .testing }

    @discardableResult
    func save() -> Bool {
        guard canSave else { return false }
        do {
            try keyStore.setAPIKey(trimmedDraft)
            draft = ""
            saveError = nil
            source = keyStore.source()
            return true
        } catch {
            saveError = APIKeyMessages.message(for: error)
            return false
        }
    }

    func remove() {
        do {
            try keyStore.setAPIKey(nil)
            saveError = nil
            testState = .idle
        } catch {
            saveError = APIKeyMessages.message(for: error)
        }
        source = keyStore.source()
    }

    func refresh() {
        source = keyStore.source()
    }

    func test(model: String) {
        testTask?.cancel()
        let key = canSave ? trimmedDraft : keyStore.apiKey()
        guard let key else {
            testState = .failed(APIKeyMessages.message(for: RewriteError.missingAPIKey))
            return
        }
        testState = .testing
        let validate = validate
        testTask = Task { [weak self] in
            let outcome: APIKeyTestState
            do {
                try await validate(key, model)
                outcome = .succeeded(APIKeyMessages.success(model: model))
            } catch {
                outcome = .failed(APIKeyMessages.message(for: error))
            }
            guard !Task.isCancelled else { return }
            self?.testState = outcome
        }
    }

    func cancelTest() {
        testTask?.cancel()
        testTask = nil
        if testState == .testing { testState = .idle }
    }
}
