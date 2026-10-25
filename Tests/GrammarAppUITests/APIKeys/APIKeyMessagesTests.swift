import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct APIKeyMessagesTests {
    @Test func rewriteErrors() {
        #expect(APIKeyMessages.message(for: RewriteError.missingAPIKey) == "Enter an API key first.")
        #expect(APIKeyMessages.message(for: RewriteError.invalidAPIKey).contains("rejected"))
        #expect(APIKeyMessages.message(for: RewriteError.textTooLong) == "The test request was too long.")
        #expect(APIKeyMessages.message(for: RewriteError.failed("You're offline")) == "You're offline")
        #expect(APIKeyMessages.message(for: RewriteError.failed("  ")) == "The test failed.")
    }

    @Test func otherErrorsUseTheirDescription() {
        let error = URLError(.notConnectedToInternet)
        #expect(APIKeyMessages.message(for: error) == error.localizedDescription)
    }

    @Test func successNamesTheModel() {
        #expect(APIKeyMessages.success(model: "claude-haiku-5-5") == "The key works with Claude Haiku 5.5.")
        #expect(APIKeyMessages.success(model: "custom-model") == "The key works with custom-model.")
    }

    @Test func modelChoicesIncludeACustomSavedModel() {
        #expect(ModelChoice.options(including: "claude-haiku-5-5").map(\.id) == AIModelOption.all.map(\.id))
        let custom = ModelChoice.options(including: "claude-future-9")
        #expect(custom.count == AIModelOption.all.count + 1)
        #expect(custom.last?.id == "claude-future-9")
    }
}
