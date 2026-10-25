import Foundation
import GrammarModels
import os

enum HarperProbe {
    static let timeout: Duration = .seconds(5)

    static func installation(customPath: String, locator: HarperLocator = HarperLocator()) async -> HarperInstallation {
        switch locator.locate(customPath: customPath) {
        case .missing:
            return .notFound
        case .invalid(let path):
            return .unusable(path: path, reason: "There's no harper-ls program at this path.")
        case .found(let path):
            guard let output = await run(path, arguments: ["--version"]) else {
                return .unusable(path: path, reason: "harper-ls didn't start. Reinstall it, or choose another copy.")
            }
            return .found(path: path, version: version(fromOutput: output))
        }
    }

    static func version(fromOutput output: String) -> String {
        let words = output.trimmedWhitespace.split(whereSeparator: \.isWhitespace)
        return words.last { $0.first?.isNumber == true }.map(String.init) ?? "unknown"
    }

    private static func run(_ executable: String, arguments: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let outcome = OSAllocatedUnfairLock<CheckedContinuation<Bool, Never>?>(initialState: nil)
        let exited = await withCheckedContinuation { continuation in
            outcome.withLock { $0 = continuation }
            process.terminationHandler = { process in
                outcome.withLock { $0.take() }?.resume(returning: process.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                outcome.withLock { $0.take() }?.resume(returning: false)
                return
            }
            Task {
                try? await Task.sleep(for: timeout)
                guard let continuation = outcome.withLock({ $0.take() }) else { return }
                process.terminate()
                continuation.resume(returning: false)
            }
        }
        guard exited else { return nil }
        return String(bytes: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}
