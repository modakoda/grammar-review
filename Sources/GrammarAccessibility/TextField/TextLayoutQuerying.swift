import ApplicationServices
import CoreGraphics
import Foundation

nonisolated protocol TextLayoutQuerying {
    func bounds(for range: NSRange) -> CGRect?
    func line(forIndex index: Int) -> Int?
    func range(forLine line: Int) -> NSRange?
    func referenceLineHeight(at index: Int) -> CGFloat?
}

nonisolated extension TextLayoutQuerying {
    func referenceLineHeight(at index: Int) -> CGFloat? {
        guard let rect = bounds(for: NSRange(location: index, length: 1)),
              LineSplitter.isUsableCharacterRect(rect)
        else { return nil }
        return rect.height
    }
}
