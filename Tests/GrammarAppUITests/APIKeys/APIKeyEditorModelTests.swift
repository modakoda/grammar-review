import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct APIKeyEditorModelTests {
    @Test func testingWithoutAnyKeyAsksForOne() {
        let validator = FakeValidator()
        let model = APIKeyEditorModel(keyStore: makeKeyStore(), validate: validator.validate)
        #expect(!model.canTest)

        model.test(model: "claude-haiku-5-5")
        #expect(model.testState == .failed("Enter an API key first."))
        #expect(validator.calls.isEmpty)
    }

    @Test func testsTheTrimmedDraft() async {
        let validator = FakeValidator()
        let model = APIKeyEditorModel(keyStore: makeKeyStore(), validate: validator.validate)
        model.draft = "  sk-ant-draft  "

        model.test(model: "claude-sonnet-5-5")
        #expect(model.testState == .testing)
        await model.testTask?.value
        #expect(validator.calls == ["sk-ant-draft|claude-sonnet-5-5"])
        #expect(model.testState == .succeeded("The key works with Claude Sonnet 5.5."))
    }

    @Test func testsTheSavedKeyWhenTheDraftIsEmpty() async {
        let validator = FakeValidator(error: .invalidAPIKey)
        let keyStore = makeKeyStore(backend: InMemorySecretBackend(secret: "sk-ant-saved"))
        let model = APIKeyEditorModel(keyStore: keyStore, validate: validator.validate)
        #expect(model.source == .keychain)
        #expect(model.canTest)

        model.test(model: "claude-haiku-5-5")
        await model.testTask?.value
        #expect(validator.calls == ["sk-ant-saved|claude-haiku-5-5"])
        #expect(model.testState == .failed(APIKeyMessages.message(for: RewriteError.invalidAPIKey)))
    }

    @Test func editingTheDraftClearsTheResult() async {
        let model = APIKeyEditorModel(keyStore: makeKeyStore(), validate: FakeValidator().validate)
        model.draft = "sk-ant-1"
        model.test(model: "claude-haiku-5-5")
        await model.testTask?.value
        #expect(model.testState != .idle)

        model.draft = "sk-ant-12"
        #expect(model.testState == .idle)
    }

    @Test func saveAndRemove() {
        let backend = InMemorySecretBackend()
        let model = APIKeyEditorModel(keyStore: makeKeyStore(backend: backend), validate: FakeValidator().validate)
        #expect(!model.canSave)

        model.draft = " sk-ant-new \n"
        #expect(model.save())
        #expect(backend.secret == "sk-ant-new")
        #expect(model.draft.isEmpty)
        #expect(model.source == .keychain)

        model.remove()
        #expect(backend.secret == nil)
        #expect(model.source == .none)
    }

    @Test func saveFailureIsShown() {
        let backend = InMemorySecretBackend()
        backend.writeError = KeychainError(status: -25_291)
        let model = APIKeyEditorModel(keyStore: makeKeyStore(backend: backend), validate: FakeValidator().validate)
        model.draft = "sk-ant-x"

        #expect(!model.save())
        #expect(model.saveError?.hasPrefix("Keychain: ") == true)
        #expect(model.draft == "sk-ant-x")
    }
}
