import ApplicationServices
import CoreGraphics
import Foundation

nonisolated final class AXLayoutQuerier: TextLayoutQuerying {
    private let element: AXElement
    private let cache: LineLayoutCache
    private(set) var timedOut = false

    init(element: AXElement, cache: LineLayoutCache) {
        self.element = element
        self.cache = cache
    }

    func bounds(for range: NSRange) -> CGRect? {
        guard !timedOut else { return nil }
        return measured { element.bounds(for: range) }.0
    }

    func line(forIndex index: Int) -> Int? {
        guard !timedOut, cache.supportsLineQueries != false else { return nil }
        let (line, error) = measured { element.line(forIndex: index) }
        if error.isUnsupported { cache.supportsLineQueries = false } else if line != nil { cache.supportsLineQueries = true }
        return line
    }

    func range(forLine line: Int) -> NSRange? {
        guard !timedOut, cache.supportsLineQueries != false else { return nil }
        let (range, error) = measured { element.range(forLine: line) }
        if error.isUnsupported { cache.supportsLineQueries = false }
        return range
    }

    private func measured<T>(_ body: () -> (T?, AXError)) -> (T?, AXError) {
        let start = ContinuousClock.now
        let (value, error) = body()
        if error == .cannotComplete, start.duration(to: .now) >= AccessibilityTiming.timeoutDetectionThreshold {
            timedOut = true
        }
        return (value, error)
    }
}
