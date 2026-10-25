import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct LocalServerAddressTests {
    @Test(arguments: [
        ("http://localhost:1234/v1", "http://localhost:1234/v1"),
        ("localhost:1234", "http://localhost:1234/v1"),
        ("  http://localhost:11434/  ", "http://localhost:11434/v1"),
        ("http://127.0.0.1:8080/v1/", "http://127.0.0.1:8080/v1"),
        ("http://localhost:1234/v1/chat/completions", "http://localhost:1234/v1"),
        ("http://localhost:1234/v1/models", "http://localhost:1234/v1"),
        ("https://studio.example.com/api/v1?x=1", "https://studio.example.com/api/v1"),
        ("mac-studio.local:1234", "http://mac-studio.local:1234/v1"),
    ])
    func normalizesWhatTheUserTyped(input: String, expected: String) {
        #expect(LocalServerAddress.baseURL(from: input)?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "ftp://localhost:21", "http://", "file:///tmp/x"])
    func rejectsWhatIsNotAServer(input: String) {
        #expect(LocalServerAddress.baseURL(from: input) == nil)
    }

    @Test(arguments: LocalServerPreset.all)
    func presetsAreAddressesAsWritten(preset: LocalServerPreset) {
        #expect(LocalServerAddress.baseURL(from: preset.url)?.absoluteString == preset.url)
    }

    @Test func theDefaultServerIsLMStudio() {
        #expect(AppSettings().localServerURL == LocalServerPreset.lmStudio.url)
        #expect(LocalServerPreset.all.first == .lmStudio)
    }
}
