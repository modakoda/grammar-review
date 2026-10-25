import Foundation
import GrammarModels
import Observation

@Observable
final class CardModel {
    var issue: TextIssue?
    var offersRewrite = true
}
