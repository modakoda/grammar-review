import CoreGraphics
import Foundation

@MainActor
public protocol TextFieldHandle: AnyObject {
    var processID: pid_t { get }
    var bundleID: String? { get }
    var appName: String? { get }
    var isSecure: Bool { get }
    var isSingleLine: Bool { get }

    func readText() -> String?
    func selectedRange() -> NSRange?
    func frame() -> CGRect?
    func rects(for range: NSRange) -> [CGRect]
    @discardableResult
    func replace(_ range: NSRange, with replacement: String) -> Bool
    @discardableResult
    func select(_ range: NSRange) -> Bool
    func isSameField(as other: any TextFieldHandle) -> Bool
}
