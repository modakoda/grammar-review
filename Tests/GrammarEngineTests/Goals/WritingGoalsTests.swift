import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct WritingGoalsTests {
    @Test func summaryListsWhatIsSet() {
        #expect(WritingGoals.none.summary == "No goals")
        #expect(WritingGoals.none.isNone)
        #expect(WritingGoals(style: .formal, audience: .expert, domain: .academic, intent: .convince).summary
            == "Formal · Expert · Academic · Convince")
        #expect(WritingGoals(domain: .email).summary == "Email")
    }
}
