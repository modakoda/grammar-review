import Foundation
import GrammarModels
import os
import Security

nonisolated protocol SecretBackend: Sendable {
    func read() throws -> String?
    func write(_ secret: String) throws
    func delete() throws
}

nonisolated final class APIKeyStore: Sendable {
    static let shared = APIKeyStore(
        backend: KeychainBackend(service: KeychainStore.service, account: KeychainStore.account, label: "Anthropic"),
        environment: { ProcessInfo.processInfo.environment }
    )

    static let webSearch = APIKeyStore(
        backend: KeychainBackend(service: KeychainStore.service, account: KeychainStore.webSearchAccount, label: "Brave Search"),
        environment: { ProcessInfo.processInfo.environment },
        environmentVariable: KeychainStore.webSearchEnvironmentVariable
    )

    private static let stores = OSAllocatedUnfairLock<[String: APIKeyStore]>(initialState: [:])

    static func store(for provider: AIProvider) -> APIKeyStore {
        if provider == .claude { return shared }
        return stores.withLock { stores in
            if let existing = stores[provider.rawValue] { return existing }
            let service = provider.cloudService
            let store = APIKeyStore(
                backend: KeychainBackend(
                    service: KeychainStore.service,
                    account: KeychainStore.account(for: provider),
                    label: service?.name ?? provider.rawValue
                ),
                environment: { ProcessInfo.processInfo.environment },
                environmentVariable: service?.environmentVariable ?? ""
            )
            stores[provider.rawValue] = store
            return store
        }
    }

    static func invalidateAllCaches() {
        shared.invalidateCache()
        webSearch.invalidateCache()
        for store in stores.withLock({ Array($0.values) }) { store.invalidateCache() }
    }

    private enum Cache: Sendable {
        case empty
        case loaded(String?, expiry: Date?)
    }

    static let lockedRetryInterval: TimeInterval = 30

    private let backend: any SecretBackend
    private let environment: @Sendable () -> [String: String]
    private let environmentVariable: String
    private let now: @Sendable () -> Date
    private let cache = OSAllocatedUnfairLock<Cache>(initialState: .empty)

    init(
        backend: any SecretBackend,
        environment: @escaping @Sendable () -> [String: String],
        environmentVariable: String = KeychainStore.environmentVariable,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.environment = environment
        self.environmentVariable = environmentVariable
        self.now = now
    }

    func apiKey() -> String? {
        savedKey() ?? environmentKey()
    }

    func source() -> APIKeySource {
        if savedKey() != nil { return .keychain }
        if environmentKey() != nil { return .environment }
        return .none
    }

    func setAPIKey(_ key: String?) throws {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            try backend.delete()
            cache.withLock { $0 = .loaded(nil, expiry: nil) }
        } else {
            try backend.write(trimmed)
            cache.withLock { $0 = .loaded(trimmed, expiry: nil) }
        }
    }

    func invalidateCache() {
        cache.withLock { $0 = .empty }
    }

    private func savedKey() -> String? {
        let current = now()
        let cached: String?? = cache.withLock { state in
            if case let .loaded(value, expiry) = state, expiry.map({ $0 > current }) ?? true {
                return .some(value)
            }
            return .none
        }
        if let cached { return cached }

        let value: String?
        let expiry: Date?
        do {
            value = try backend.read()
            expiry = nil
        } catch let error as KeychainError where error.status == errSecInteractionNotAllowed {
            Log.app.error("Keychain is locked; retrying in \(Self.lockedRetryInterval, privacy: .public) s")
            value = nil
            expiry = current.addingTimeInterval(Self.lockedRetryInterval)
        } catch {
            Log.app.error("Could not read the API key from the Keychain: \(error.localizedDescription, privacy: .public)")
            value = nil
            expiry = nil
        }
        cache.withLock { $0 = .loaded(value, expiry: expiry) }
        return value
    }

    private func environmentKey() -> String? {
        guard !environmentVariable.isEmpty else { return nil }
        let value = environment()[environmentVariable]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
