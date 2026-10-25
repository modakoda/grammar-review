import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

private let installedHarper: String? = {
    if case .found(let path) = HarperLocator().locate(customPath: "") { return path }
    return nil
}()

@Suite(.timeLimit(.minutes(1))) struct HarperClientTests {
    @Test func aServerThatExitsFailsFastAndIsNotRestartedRightAway() async {
        let client = HarperClient()
        let american = HarperConfiguration(dialect: .american)
        await #expect(throws: HarperError.stopped) {
            try await client.lint("This is an test.", configuration: american, executable: "/usr/bin/false")
        }
        await #expect(throws: HarperError.backingOff) {
            try await client.lint("This is an test.", configuration: american, executable: "/usr/bin/false")
        }
    }

    @Test func aMissingProgramCannotBeLaunched() async {
        let client = HarperClient()
        await #expect {
            try await client.lint("Text.", configuration: HarperConfiguration(dialect: .american), executable: "/nonexistent/harper-ls")
        } throws: { error in
            if case .launchFailed = error as? HarperError { return true }
            return false
        }
    }

    @Test(.enabled(if: installedHarper != nil, "harper-ls is not installed"))
    func lintsWithTheInstalledHarper() async throws {
        let executable = try #require(installedHarper)
        let client = HarperClient()
        let text = "First line is fine.\r\nThis is an test of the the checker 😀. Their going to the store."
        let lints = try await client.lint(text, configuration: HarperConfiguration(dialect: .american), executable: executable)

        let byText = Dictionary(lints.map { (substring(text, $0.range), $0) }, uniquingKeysWith: { first, _ in first })
        #expect(byText["an"]?.replacements == ["a"])
        #expect(byText["an"]?.kind == "Miscellaneous")
        #expect(byText["the the"]?.replacements.first == "the")
        #expect(byText["Their"]?.replacements.first == "They're")
        #expect(!lints.contains { $0.rule == "SpellCheck" })

        let again = try await client.lint("It work good, dont it?", configuration: HarperConfiguration(dialect: .british), executable: executable)
        #expect(!again.contains { $0.rule == "SpellCheck" })
        let clean = try await client.lint("Everything here is fine.", configuration: HarperConfiguration(dialect: .british), executable: executable)
        #expect(clean.isEmpty)
    }

    @Test(.enabled(if: installedHarper != nil, "harper-ls is not installed"))
    func aCancelledLintLeavesTheServerUsable() async throws {
        let executable = try #require(installedHarper)
        let client = HarperClient()
        let configuration = HarperConfiguration(dialect: .american)
        let cancelled = Task { try await client.lint("This is an test.", configuration: configuration, executable: executable) }
        cancelled.cancel()
        _ = try? await cancelled.value
        let lints = try await client.lint("This is an test.", configuration: configuration, executable: executable)
        #expect(lints.map(\.replacements) == [["a"]])
    }

    @Test(.enabled(if: installedHarper != nil, "harper-ls is not installed"))
    func theProbeReportsTheVersion() async throws {
        let executable = try #require(installedHarper)
        guard case .found(let path, let version) = await HarperProbe.installation(customPath: executable) else {
            Issue.record("harper-ls was not usable")
            return
        }
        #expect(path == executable)
        #expect(version.first?.isNumber == true)
        #expect(await HarperProbe.installation(customPath: "/nonexistent") == .unusable(path: "/nonexistent", reason: "There's no harper-ls program at this path."))
    }
}
