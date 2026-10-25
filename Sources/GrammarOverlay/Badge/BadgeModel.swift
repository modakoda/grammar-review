import Foundation
import GrammarModels
import Observation

@Observable
final class BadgeModel {
    var appearance = BadgeAppearance(glyph: .checkmark, tint: .success, tooltip: "")
}
