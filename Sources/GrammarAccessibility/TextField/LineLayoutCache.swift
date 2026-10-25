import ApplicationServices
import CoreGraphics
import Foundation

nonisolated final class LineLayoutCache {
    static let maxEntries = 4_000

    var lineForIndex: [Int: Int] = [:]
    var rangeForLine: [Int: NSRange] = [:]
    var referenceLineHeight: CGFloat?
    var supportsLineQueries: Bool?

    init() {}

    func invalidate() {
        lineForIndex.removeAll(keepingCapacity: true)
        rangeForLine.removeAll(keepingCapacity: true)
        referenceLineHeight = nil
    }

    fileprivate func trimIfNeeded() {
        if lineForIndex.count + rangeForLine.count > Self.maxEntries { invalidate() }
    }
}

nonisolated struct CachingLayoutQuerier<Base: TextLayoutQuerying>: TextLayoutQuerying {
    let base: Base
    let cache: LineLayoutCache

    func bounds(for range: NSRange) -> CGRect? {
        base.bounds(for: range)
    }

    func line(forIndex index: Int) -> Int? {
        if let cached = cache.lineForIndex[index] { return cached }
        guard let line = base.line(forIndex: index) else { return nil }
        cache.trimIfNeeded()
        cache.lineForIndex[index] = line
        return line
    }

    func range(forLine line: Int) -> NSRange? {
        if let cached = cache.rangeForLine[line] { return cached }
        guard let range = base.range(forLine: line) else { return nil }
        cache.trimIfNeeded()
        cache.rangeForLine[line] = range
        return range
    }

    func referenceLineHeight(at index: Int) -> CGFloat? {
        if let cached = cache.referenceLineHeight { return cached }
        let height = base.referenceLineHeight(at: index)
        cache.referenceLineHeight = height
        return height
    }
}
