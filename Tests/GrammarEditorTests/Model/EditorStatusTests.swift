import Foundation
import GrammarModels
import Testing
@testable import GrammarEditor

@MainActor
@Suite struct EditorStatusTests {
    private func status(_ aiStatus: AIStatus, text: String = "Some text.", isChecking: Bool = false) -> EditorStatus {
        EditorStatus(text: text, isChecking: isChecking, aiStatus: aiStatus)
    }

    @Test func blankTextOrAFinishedCheckShowsNothing() {
        #expect(status(.failed("You're offline"), text: " \n", isChecking: true) == .idle)
        #expect(status(.completed) == .idle)
        #expect(status(.pending) == .idle)
        #expect(status(.missingAPIKey, isChecking: true) == .checking, "checking wins over an older notice")
    }

    @Test func aiProblemsAreExplained() {
        #expect(status(.disabled) == .notice("AI suggestions are off, so only spelling is checked.", offersSettings: true))
        #expect(status(.missingAPIKey) == .notice("Add an Anthropic API key in Settings to get grammar and style suggestions.", offersSettings: true))
        #expect(status(.textTooLong) == .notice("This text is too long for AI checks, so only spelling is checked.", offersSettings: false))
        #expect(status(.failed("You're offline")) == .notice("You're offline", offersSettings: true))
    }
}
