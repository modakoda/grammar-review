import CoreGraphics
import Foundation
import GrammarModels

extension TextFieldHandle {
    func anchor(for range: NSRange) -> CGRect {
        let anchor = rects(for: range).reduce(CGRect.null) { $0.union($1) }
        return anchor.isNull ? (frame() ?? .zero) : anchor
    }
}
