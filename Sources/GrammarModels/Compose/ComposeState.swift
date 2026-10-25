import CoreGraphics
import Foundation

public struct ComposeState: Sendable, Equatable {
    public var anchor: CGRect
    public var request: String
    public var replacesSelection: Bool
    public var hasContext: Bool
    public var result: RewriteResult?

    public init(anchor: CGRect, request: String = "", replacesSelection: Bool, hasContext: Bool, result: RewriteResult? = nil) {
        self.anchor = anchor
        self.request = request
        self.replacesSelection = replacesSelection
        self.hasContext = hasContext
        self.result = result
    }
}
