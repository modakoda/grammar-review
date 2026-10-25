import Foundation
import GrammarModels
import os

protocol HarperLinting: Sendable {
    func lint(_ text: String, configuration: HarperConfiguration, executable: String) async throws -> [HarperLint]
}

enum HarperError: Error, Equatable {
    case launchFailed(String)
    case stopped
    case timedOut
    case backingOff
    case server(String)
}

actor HarperClient: HarperLinting {
    static let shared = HarperClient()

    static let startTimeout: Duration = .seconds(5)
    static let configurationTimeout: Duration = .seconds(1)
    static let lintTimeout: Duration = .seconds(3)
    static let retryInterval: TimeInterval = 60
    static let maxLints = 100

    private enum Pending: Hashable, Sendable {
        case response(Int)
        case diagnostics(String)
        case configuration
    }

    private struct Connection {
        var process: Process
        var input: FileHandle
        var executable: String
        var generation: Int
    }

    private var connection: Connection?
    private var configuration: HarperConfiguration?
    private var generation = 0
    private var nextRequestID = 1
    private var nextDocument = 1
    private var failure: (executable: String, date: Date)?
    private var pending: [Pending: CheckedContinuation<Data, any Error>] = [:]
    private var timeouts: [Pending: Task<Void, Never>] = [:]
    private var isBusy = false
    private var queue: [CheckedContinuation<Void, Never>] = []

    func lint(_ text: String, configuration: HarperConfiguration, executable: String) async throws -> [HarperLint] {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        do {
            try await prepare(executable: executable, configuration: configuration)
            return try await lintDocument(text)
        } catch let error as HarperError {
            switch error {
            case .launchFailed, .stopped, .timedOut:
                Log.engine.error("Harper failed (\(String(describing: error), privacy: .public)); retrying in \(Self.retryInterval, privacy: .public) s")
                stop()
                failure = (executable, Date())
            case .backingOff, .server:
                break
            }
            throw error
        }
    }

    private func prepare(executable: String, configuration: HarperConfiguration) async throws {
        if let connection, connection.executable != executable { stop() }
        if connection == nil {
            if let failure, failure.executable == executable, Date().timeIntervalSince(failure.date) < Self.retryInterval {
                throw HarperError.backingOff
            }
            try launch(executable)
            self.configuration = configuration
            let id = takeRequestID()
            _ = try await wait(for: .response(id), timeout: Self.startTimeout) {
                try send(LSPOutgoing.request(id: id, method: "initialize", params: Self.initializeParams))
            }
            try await waitForConfiguration {
                try send(LSPOutgoing.notification(method: "initialized", params: .object([])))
            }
            failure = nil
        } else if self.configuration != configuration {
            self.configuration = configuration
            try await waitForConfiguration {
                try send(LSPOutgoing.notification(method: "workspace/didChangeConfiguration", params: .object([("settings", configuration.settings)])))
            }
        }
    }

    private func waitForConfiguration(after send: () throws -> Void) async throws {
        do {
            _ = try await wait(for: .configuration, timeout: Self.configurationTimeout, after: send)
        } catch HarperError.timedOut {
            Log.engine.debug("harper-ls didn't ask for its configuration")
        }
    }

    private func lintDocument(_ text: String) async throws -> [HarperLint] {
        let uri = "untitled:grammar-review-\(nextDocument)"
        nextDocument += 1
        defer {
            try? send(LSPOutgoing.notification(method: "textDocument/didClose", params: .object([("textDocument", LSPOutgoing.document(uri))])))
        }
        let document = JSONValue.object([
            ("uri", .string(uri)), ("languageId", .string("plaintext")), ("version", .int(1)), ("text", .string(text)),
        ])
        let published = try await wait(for: .diagnostics(uri), timeout: Self.lintTimeout) {
            try send(LSPOutgoing.notification(method: "textDocument/didOpen", params: .object([("textDocument", document)])))
        }
        guard let diagnostics = try? JSONDecoder().decode(LSPNotification<LSPPublishDiagnostics>.self, from: published).params.diagnostics else {
            throw HarperError.server("Unreadable diagnostics")
        }
        let lines = LSPLineIndex(text)
        let ns = text as NSString
        var lints: [HarperLint] = []
        for diagnostic in diagnostics.prefix(Self.maxLints) {
            let actions = try await codeActions(for: diagnostic, uri: uri)
            if let lint = HarperLint(diagnostic: diagnostic, actions: actions, uri: uri, lines: lines, text: ns) {
                lints.append(lint)
            }
        }
        return lints
    }

    private func codeActions(for diagnostic: LSPDiagnostic, uri: String) async throws -> [LSPCodeAction] {
        let id = takeRequestID()
        let params = JSONValue.object([
            ("textDocument", LSPOutgoing.document(uri)),
            ("range", diagnostic.range.json),
            ("context", .object([("diagnostics", .array([diagnostic.json]))])),
        ])
        let response = try await wait(for: .response(id), timeout: Self.lintTimeout) {
            try send(LSPOutgoing.request(id: id, method: "textDocument/codeAction", params: params))
        }
        return (try? JSONDecoder().decode(LSPResponse<[LSPCodeAction]>.self, from: response))?.result ?? []
    }

    private func launch(_ executable: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--stdio"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)

        generation += 1
        let generation = generation
        let (chunks, continuation) = AsyncStream<Data>.makeStream()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }
        process.terminationHandler = { _ in continuation.finish() }
        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            continuation.finish()
            throw HarperError.launchFailed(error.localizedDescription)
        }
        connection = Connection(process: process, input: input.fileHandleForWriting, executable: executable, generation: generation)
        Task { [weak self] in
            var decoder = LSPFrameDecoder()
            for await chunk in chunks {
                for message in decoder.append(chunk) {
                    await self?.received(message, generation: generation)
                }
            }
            await self?.ended(generation: generation)
        }
    }

    private func received(_ data: Data, generation: Int) {
        guard generation == connection?.generation,
              let message = try? JSONDecoder().decode(LSPIncoming.self, from: data) else { return }
        switch (message.id, message.method) {
        case let (id?, method?):
            answer(id, method: method, request: data)
        case let (.int(id), nil):
            if let error = message.error {
                resolve(.response(id), with: .failure(HarperError.server(error.message)))
            } else {
                resolve(.response(id), with: .success(data))
            }
        case (nil, "textDocument/publishDiagnostics"):
            if let uri = try? JSONDecoder().decode(LSPNotification<LSPPublishDiagnostics>.self, from: data).params.uri {
                resolve(.diagnostics(uri), with: .success(data))
            }
        default:
            break
        }
    }

    private func answer(_ id: LSPID, method: String, request: Data) {
        guard method == "workspace/configuration" else {
            try? send(LSPOutgoing.response(id: id, result: .null))
            return
        }
        let count = (try? JSONDecoder().decode(LSPNotification<LSPConfigurationParams>.self, from: request))?.params.items.count ?? 1
        let settings = (configuration ?? HarperConfiguration(dialect: .american)).settings
        try? send(LSPOutgoing.response(id: id, result: .array(Array(repeating: settings, count: count))))
        resolve(.configuration, with: .success(Data()))
    }

    private func ended(generation: Int) {
        guard connection?.generation == generation, let executable = connection?.executable else { return }
        Log.engine.error("harper-ls stopped; retrying in \(Self.retryInterval, privacy: .public) s")
        connection = nil
        configuration = nil
        failure = (executable, Date())
        failAll(.stopped)
    }

    private func stop() {
        guard let connection else { return }
        self.connection = nil
        configuration = nil
        try? connection.input.close()
        connection.process.terminate()
        failAll(.stopped)
    }

    private func send(_ message: JSONValue) throws {
        guard let connection else { throw HarperError.stopped }
        do {
            try connection.input.write(contentsOf: LSPFrameDecoder.frame(message.data))
        } catch {
            throw HarperError.stopped
        }
    }

    private func wait(for key: Pending, timeout: Duration, after send: () throws -> Void) async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolve(key, with: .failure(HarperError.stopped))
                pending[key] = continuation
                timeouts[key] = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    await self?.resolve(key, with: .failure(HarperError.timedOut))
                }
                do {
                    try send()
                } catch {
                    resolve(key, with: .failure(error))
                    return
                }
                if Task.isCancelled { resolve(key, with: .failure(CancellationError())) }
            }
        } onCancel: {
            Task { await self.resolve(key, with: .failure(CancellationError())) }
        }
    }

    private func resolve(_ key: Pending, with result: Result<Data, any Error>) {
        timeouts.removeValue(forKey: key)?.cancel()
        pending.removeValue(forKey: key)?.resume(with: result)
    }

    private func failAll(_ error: HarperError) {
        for key in Array(pending.keys) { resolve(key, with: .failure(error)) }
    }

    private func takeRequestID() -> Int {
        defer { nextRequestID += 1 }
        return nextRequestID
    }

    private func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }
        await withCheckedContinuation { queue.append($0) }
    }

    private func release() {
        if queue.isEmpty {
            isBusy = false
        } else {
            queue.removeFirst().resume()
        }
    }

    private static let initializeParams = JSONValue.object([
        ("processId", .int(Int(ProcessInfo.processInfo.processIdentifier))),
        ("rootUri", .null),
        ("clientInfo", .object([("name", .string("Grammar Review"))])),
        ("capabilities", .object([
            ("general", .object([("positionEncodings", .array([.string("utf-16")]))])),
            ("workspace", .object([("configuration", .bool(true))])),
            ("textDocument", .object([
                ("publishDiagnostics", .object([])),
                ("codeAction", .object([("codeActionLiteralSupport", .object([
                    ("codeActionKind", .object([("valueSet", .array([.string("quickfix")]))])),
                ]))])),
            ])),
        ])),
    ])
}
