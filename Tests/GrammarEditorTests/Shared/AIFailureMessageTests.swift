import Foundation
import GrammarModels
import Testing
@testable import GrammarEditor

@MainActor
@Suite struct AIFailureMessageTests {
    @Test func aMissingKeyNamesTheFeatureThatNeedsIt() {
        #expect(AIFailureMessage.message(for: RewriteError.missingAPIKey) == "Add an Anthropic API key in Settings to use rewrites.")
        #expect(AIFailureMessage.message(for: RewriteError.missingAPIKey, feature: "write with AI") == "Add an Anthropic API key in Settings to write with AI.")
    }

    @Test func otherFailuresSayWhatWentWrong() {
        #expect(AIFailureMessage.message(for: RewriteError.invalidAPIKey) == "Your Anthropic API key was rejected. Check it in Settings.")
        #expect(AIFailureMessage.message(for: RewriteError.textTooLong) == "This text is too long to rewrite at once. Select a part of it.")
        #expect(AIFailureMessage.message(for: RewriteError.failed("Claude is busy — try again shortly")) == "Claude is busy — try again shortly")
        let offline = URLError(.notConnectedToInternet)
        #expect(AIFailureMessage.message(for: offline) == offline.localizedDescription)
    }
}
