import Foundation
import GrammarModels
import os
@testable import GrammarAppUI

@MainActor
func withTemporaryDefaults<T>(_ body: (UserDefaults) async throws -> T) async rethrows -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GrammarAppUITests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let suiteName = directory.appendingPathComponent("settings").path
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    return try await body(defaults)
}

@MainActor
final class TestClock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

final class InMemorySecretBackend: SecretBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var _secret: String?
    private var _reads = 0
    private var _readError: KeychainError?
    private var _writeError: KeychainError?

    init(secret: String? = nil) {
        _secret = secret
    }

    var secret: String? {
        get { lock.withLock { _secret } }
        set { lock.withLock { _secret = newValue } }
    }

    var reads: Int { lock.withLock { _reads } }

    var readError: KeychainError? {
        get { lock.withLock { _readError } }
        set { lock.withLock { _readError = newValue } }
    }

    var writeError: KeychainError? {
        get { lock.withLock { _writeError } }
        set { lock.withLock { _writeError = newValue } }
    }

    func read() throws -> String? {
        try lock.withLock {
            _reads += 1
            if let _readError { throw _readError }
            return _secret
        }
    }

    func write(_ secret: String) throws {
        try lock.withLock {
            if let _writeError { throw _writeError }
            _secret = secret
        }
    }

    func delete() throws {
        try lock.withLock {
            if let _writeError { throw _writeError }
            _secret = nil
        }
    }
}

final class LockedClock: Sendable {
    private let state: OSAllocatedUnfairLock<Date>

    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        state = OSAllocatedUnfairLock(initialState: now)
    }

    var now: Date { state.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        state.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

func makeKeyStore(
    backend: InMemorySecretBackend = InMemorySecretBackend(),
    environment: [String: String] = [:],
    clock: LockedClock = LockedClock()
) -> APIKeyStore {
    APIKeyStore(backend: backend, environment: { environment }, now: { clock.now })
}

extension Calendar {
    static func fixed(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }
}

final class FakeValidator: Sendable {
    private let state = OSAllocatedUnfairLock<[String]>(initialState: [])
    let error: RewriteError?

    init(error: RewriteError? = nil) {
        self.error = error
    }

    var calls: [String] { state.withLock { $0 } }

    var validate: APIKeyValidator {
        { [self] key, model in
            state.withLock { $0.append("\(key)|\(model)") }
            if let error { throw error }
        }
    }
}
