import CoreGraphics
import Foundation

public enum RewriteResult: Sendable, Equatable {
    case loading
    case ready(String)
    case failed(String)
}

public enum RewriteScope: Sendable, Equatable {
    case selection
    case sentence
    case paragraph
    case wholeText
}

public struct RewriteState: Sendable, Equatable {
    public var anchor: CGRect
    public var original: String
    public var scope: RewriteScope
    public var tone: RewriteTone?
    public var instruction: String?
    public var result: RewriteResult

    public init(
        anchor: CGRect,
        original: String,
        scope: RewriteScope = .selection,
        tone: RewriteTone?,
        instruction: String? = nil,
        result: RewriteResult
    ) {
        self.anchor = anchor
        self.original = original
        self.scope = scope
        self.tone = tone
        self.instruction = instruction
        self.result = result
    }
}
