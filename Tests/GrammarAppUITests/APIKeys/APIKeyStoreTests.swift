import Foundation
import Security
import Testing
@testable import GrammarAppUI

@Suite struct APIKeyStoreTests {
    @Test func savesTheTrimmedKey() throws {
        let backend = InMemorySecretBackend()
        let store = makeKeyStore(backend: backend)

        try store.setAPIKey("  sk-ant-test-123 \n")
        #expect(backend.secret == "sk-ant-test-123")
        #expect(store.apiKey() == "sk-ant-test-123")
        #expect(store.source() == .keychain)
    }

    @Test func nilOrBlankDeletesTheKey() throws {
        let backend = InMemorySecretBackend()
        let store = makeKeyStore(backend: backend)

        try store.setAPIKey("sk-ant-1")
        try store.setAPIKey(nil)
        #expect(backend.secret == nil)
        #expect(store.apiKey() == nil)

        try store.setAPIKey("sk-ant-2")
        try store.setAPIKey(" \t\n")
        #expect(backend.secret == nil)
        #expect(store.apiKey() == nil)
        #expect(store.source() == .none)
    }

    @Test func cachesTheKeyAfterTheFirstRead() {
        let backend = InMemorySecretBackend(secret: "sk-ant-cached")
        let store = makeKeyStore(backend: backend)

        for _ in 0..<10 {
            #expect(store.apiKey() == "sk-ant-cached")
        }
        #expect(backend.reads == 1)
    }

    @Test func cachesAMissingKeyToo() {
        let backend = InMemorySecretBackend()
        let store = makeKeyStore(backend: backend)

        #expect(store.apiKey() == nil)
        #expect(store.apiKey() == nil)
        #expect(store.source() == .none)
        #expect(backend.reads == 1)
    }

    @Test func savingUpdatesTheCacheWithoutReading() throws {
        let backend = InMemorySecretBackend(secret: "old")
        let store = makeKeyStore(backend: backend)
        #expect(store.apiKey() == "old")

        try store.setAPIKey("new")
        #expect(store.apiKey() == "new")
        #expect(backend.reads == 1)
    }

    @Test func invalidateCacheReadsAgain() {
        let backend = InMemorySecretBackend(secret: "first")
        let store = makeKeyStore(backend: backend)
        #expect(store.apiKey() == "first")

        backend.secret = "edited in Keychain Access"
        #expect(store.apiKey() == "first")
        store.invalidateCache()
        #expect(store.apiKey() == "edited in Keychain Access")
        #expect(backend.reads == 2)
    }

    @Test func fallsBackToTheEnvironmentVariable() {
        let store = makeKeyStore(environment: ["ANTHROPIC_API_KEY": "  sk-ant-env \n"])
        #expect(store.apiKey() == "sk-ant-env")
        #expect(store.source() == .environment)

        let blank = makeKeyStore(environment: ["ANTHROPIC_API_KEY": "   "])
        #expect(blank.apiKey() == nil)
        #expect(blank.source() == .none)
    }

    @Test func keychainWinsOverTheEnvironment() {
        let store = makeKeyStore(
            backend: InMemorySecretBackend(secret: "sk-ant-keychain"),
            environment: ["ANTHROPIC_API_KEY": "sk-ant-env"]
        )
        #expect(store.apiKey() == "sk-ant-keychain")
        #expect(store.source() == .keychain)
    }

    @Test func deletingTheSavedKeyRevealsTheEnvironmentKey() throws {
        let store = makeKeyStore(
            backend: InMemorySecretBackend(secret: "sk-ant-keychain"),
            environment: ["ANTHROPIC_API_KEY": "sk-ant-env"]
        )
        try store.setAPIKey("")
        #expect(store.apiKey() == "sk-ant-env")
    }

    @Test func lockedKeychainIsRetriedLater() {
        let backend = InMemorySecretBackend(secret: "sk-ant-locked")
        backend.readError = KeychainError(status: errSecInteractionNotAllowed)
        let clock = LockedClock()
        let store = makeKeyStore(backend: backend, clock: clock)

        #expect(store.apiKey() == nil)
        #expect(store.apiKey() == nil)
        #expect(backend.reads == 1)

        backend.readError = nil
        clock.advance(by: APIKeyStore.lockedRetryInterval + 1)
        #expect(store.apiKey() == "sk-ant-locked")
        #expect(backend.reads == 2)
    }

    @Test func otherReadErrorsAreRememberedUntilInvalidated() {
        let backend = InMemorySecretBackend(secret: "sk-ant-denied")
        backend.readError = KeychainError(status: errSecAuthFailed)
        let clock = LockedClock()
        let store = makeKeyStore(backend: backend, clock: clock)

        #expect(store.apiKey() == nil)
        clock.advance(by: 3600)
        #expect(store.apiKey() == nil)
        #expect(backend.reads == 1)

        backend.readError = nil
        store.invalidateCache()
        #expect(store.apiKey() == "sk-ant-denied")
    }

    @Test func writeErrorsPropagateAndKeepTheCache() {
        let backend = InMemorySecretBackend(secret: "sk-ant-kept")
        let store = makeKeyStore(backend: backend)
        #expect(store.apiKey() == "sk-ant-kept")

        backend.writeError = KeychainError(status: errSecNotAvailable)
        #expect(throws: KeychainError(status: errSecNotAvailable)) {
            try store.setAPIKey("sk-ant-new")
        }
        #expect(throws: KeychainError.self) {
            try store.setAPIKey(nil)
        }
        #expect(store.apiKey() == "sk-ant-kept")
    }

    @Test func keychainErrorsHaveReadableDescriptions() {
        let description = KeychainError(status: errSecItemNotFound).localizedDescription
        #expect(description.hasPrefix("Keychain: "))
        #expect(description.count > "Keychain: ".count)
    }

    @Test func everyProviderHasItsOwnKeyAndEnvironmentVariable() {
        let backend = InMemorySecretBackend()
        let store = APIKeyStore(backend: backend, environment: { ["OPENAI_API_KEY": "sk-env"] }, environmentVariable: "OPENAI_API_KEY")
        #expect(store.apiKey() == "sk-env" && store.source() == .environment)
        let noFallback = APIKeyStore(backend: backend, environment: { ["ANTHROPIC_API_KEY": "sk-ant"] }, environmentVariable: "")
        #expect(noFallback.apiKey() == nil, "a store without an environment variable never reads the environment")
        #expect(KeychainStore.account(for: .claude) == "anthropic-api-key")
        #expect(KeychainStore.account(for: .cloud("openai")) == "openai-api-key")
        #expect(APIKeyStore.store(for: .claude) === APIKeyStore.shared)
        let xai = APIKeyStore.store(for: .cloud("xai"))
        #expect(xai === APIKeyStore.store(for: .cloud("xai")), "one store per provider")
        #expect(xai !== APIKeyStore.store(for: .cloud("openai")))
    }

    @Test func keychainItemIdentity() {
        #expect(KeychainStore.service == "com.grammarreview.app")
        #expect(KeychainStore.account == "anthropic-api-key")
        #expect(KeychainStore.environmentVariable == "ANTHROPIC_API_KEY")
    }
}
