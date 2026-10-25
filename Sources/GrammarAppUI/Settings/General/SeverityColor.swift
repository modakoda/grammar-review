import GrammarModels
import SwiftUI

enum SeverityColor {
    static func color(for severity: IssueSeverity) -> Color {
        switch severity {
        case .correctness: .red
        case .clarity: .blue
        case .style: .purple
        }
    }
}
