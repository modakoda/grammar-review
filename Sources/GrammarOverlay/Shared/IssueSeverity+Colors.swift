import AppKit
import GrammarModels
import SwiftUI

extension IssueSeverity {
    package var color: Color { Color(nsColor: underlineColor) }
}

extension IssueSeverity {
    package var underlineColor: NSColor {
        switch self {
        case .correctness: .systemRed
        case .clarity: .systemBlue
        case .style: .systemPurple
        }
    }
}
