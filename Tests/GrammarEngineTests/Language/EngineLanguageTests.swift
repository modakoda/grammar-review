import AppKit
import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite(.timeLimit(.minutes(1))) struct EngineLanguageTests {
    private func check(_ text: String, mode: LanguageMode, keyboard: KeyboardLanguages) async -> (results: [CheckResult], ai: MockAIService) {
        let ai = MockAIService()
        let engine = makeEngine(ai: ai, keyboard: keyboard)
        let settings = testSettings { $0.languageMode = mode }
        return (await collect(engine.check(CheckRequest(text: text, bundleID: nil, settings: settings))), ai)
    }

    @Test func keyboardModeChecksInTheLayoutsLanguage() async {
        let (results, ai) = await check(LanguageTests.english, mode: .keyboard, keyboard: LanguageTests.lithuanianUser(typingOn: "lt"))
        #expect(results.map(\.language) == ["lt", "lt"])
        #expect(ai.languages == ["lt"])
    }

    @Test func lithuanianIsNotCheckedAsCzech() async {
        let (results, ai) = await check(LanguageTests.lithuanian, mode: .automatic, keyboard: LanguageTests.lithuanianUser(typingOn: "lt"))
        #expect(results.last?.language == "lt")
        #expect(ai.languages == ["lt"])
    }
}
