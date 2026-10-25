import CoreGraphics
import Foundation
import Testing
@testable import GrammarAccessibility

final class FakeLayout: TextLayoutQuerying {
    enum LineSupport {
        case correct
        case unsupported
        case broken
    }

    static let origin = CGPoint(x: 100, y: 200)
    static let characterWidth: CGFloat = 10
    static let lineHeight: CGFloat = 20

    let text: NSString
    var lineSupport: LineSupport
    private(set) var boundsCalls = 0
    private(set) var lineCalls = 0
    private(set) var rangeCalls = 0
    private var positions: [(line: Int, column: Int)] = []
    private var lineRanges: [NSRange] = []

    init(_ text: String, columns: Int, lineSupport: LineSupport = .correct) {
        self.text = text as NSString
        self.lineSupport = lineSupport
        var line = 0
        var column = 0
        for index in 0..<self.text.length {
            if column == columns {
                line += 1
                column = 0
            }
            positions.append((line, column))
            if LineSplitter.isLineBreak(self.text.character(at: index)) {
                line += 1
                column = 0
            } else {
                column += 1
            }
        }
        let lineCount = (positions.last?.line ?? 0) + 1
        lineRanges = (0..<lineCount).map { line in
            let indices = positions.indices.filter { positions[$0].line == line }
            guard let first = indices.first, let last = indices.last else { return NSRange(location: 0, length: 0) }
            return NSRange(location: first, length: last - first + 1)
        }
    }

    func characterRect(_ index: Int) -> CGRect {
        let (line, column) = positions[index]
        let width = LineSplitter.isLineBreak(text.character(at: index)) ? 0 : Self.characterWidth
        return CGRect(
            x: Self.origin.x + CGFloat(column) * Self.characterWidth,
            y: Self.origin.y + CGFloat(line) * Self.lineHeight,
            width: width,
            height: Self.lineHeight
        )
    }

    static func rect(line: Int, columns: Range<Int>) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(columns.lowerBound) * characterWidth,
            y: origin.y + CGFloat(line) * lineHeight,
            width: CGFloat(columns.count) * characterWidth,
            height: lineHeight
        )
    }

    func bounds(for range: NSRange) -> CGRect? {
        boundsCalls += 1
        guard range.length > 0, NSMaxRange(range) <= text.length else { return nil }
        return (range.location..<NSMaxRange(range)).map(characterRect).reduce(CGRect.null) { $0.union($1) }
    }

    func line(forIndex index: Int) -> Int? {
        lineCalls += 1
        guard index >= 0, index < text.length else { return nil }
        switch lineSupport {
        case .correct: return positions[index].line
        case .unsupported: return nil
        case .broken: return 0
        }
    }

    func range(forLine line: Int) -> NSRange? {
        rangeCalls += 1
        switch lineSupport {
        case .correct: return lineRanges.indices.contains(line) ? lineRanges[line] : nil
        case .unsupported: return nil
        case .broken: return NSRange(location: 0, length: text.length)
        }
    }
}

@Suite("Splitting ranges into per-line rects")
struct LineSplitterTests {
    private func rects(_ layout: FakeLayout, _ range: NSRange) -> [CGRect] {
        LineSplitter.lineRects(for: range, text: layout.text, layout: layout)
    }

    @Test(arguments: [FakeLayout.LineSupport.correct, .unsupported, .broken])
    func singleLineRange(support: FakeLayout.LineSupport) {
        let layout = FakeLayout("The quick brown fox", columns: 100, lineSupport: support)
        #expect(rects(layout, NSRange(location: 4, length: 5)) == [FakeLayout.rect(line: 0, columns: 4..<9)])
    }

    @Test(arguments: [FakeLayout.LineSupport.correct, .unsupported, .broken])
    func wrappedRangeGivesOneRectPerLine(support: FakeLayout.LineSupport) {
        let layout = FakeLayout("aaaaaaaaaabbbbbbbbbbcccccccccc", columns: 10, lineSupport: support)
        #expect(rects(layout, NSRange(location: 5, length: 20)) == [
            FakeLayout.rect(line: 0, columns: 5..<10),
            FakeLayout.rect(line: 1, columns: 0..<10),
            FakeLayout.rect(line: 2, columns: 0..<5),
        ])
    }

    @Test(arguments: [FakeLayout.LineSupport.correct, .unsupported])
    func hardLineBreaksAreNotUnderlined(support: FakeLayout.LineSupport) {
        let layout = FakeLayout("hello\nworld", columns: 100, lineSupport: support)
        #expect(rects(layout, NSRange(location: 0, length: 11)) == [
            FakeLayout.rect(line: 0, columns: 0..<5),
            FakeLayout.rect(line: 1, columns: 0..<5),
        ])
    }

    @Test(arguments: [FakeLayout.LineSupport.correct, .unsupported])
    func spaceAtSoftWrapIsTrimmed(support: FakeLayout.LineSupport) {
        let layout = FakeLayout("hello world again", columns: 6, lineSupport: support)
        #expect(rects(layout, NSRange(location: 0, length: 11)) == [
            FakeLayout.rect(line: 0, columns: 0..<5),
            FakeLayout.rect(line: 1, columns: 0..<5),
        ])
    }

    @Test func whitespaceOnlyRangeIsKept() {
        let layout = FakeLayout("a  b", columns: 100)
        #expect(rects(layout, NSRange(location: 1, length: 2)) == [FakeLayout.rect(line: 0, columns: 1..<3)])
    }

    @Test func rangeOfOnlyALineBreakHasNoRects() {
        let layout = FakeLayout("hello\nworld", columns: 100)
        #expect(rects(layout, NSRange(location: 5, length: 1)).isEmpty)
    }

    @Test func emptyRangeHasNoRects() {
        let layout = FakeLayout("hello", columns: 100)
        #expect(rects(layout, NSRange(location: 2, length: 0)).isEmpty)
        #expect(layout.boundsCalls == 0)
    }

    @Test func invalidRangesHaveNoRects() {
        let layout = FakeLayout("hello", columns: 100)
        #expect(rects(layout, NSRange(location: 3, length: 10)).isEmpty)
        #expect(rects(layout, NSRange(location: NSNotFound, length: 1)).isEmpty)
    }

    @Test func singleLineCostsOneBoundsQueryOnceCached() {
        let layout = FakeLayout(String(repeating: "x", count: 500), columns: 1_000)
        let cached = CachingLayoutQuerier(base: layout, cache: LineLayoutCache())
        let range = NSRange(location: 10, length: 300)
        _ = LineSplitter.lineRects(for: range, text: layout.text, layout: cached)
        #expect(layout.boundsCalls == 2)
        let afterFirst = layout.boundsCalls
        #expect(LineSplitter.lineRects(for: range, text: layout.text, layout: cached) == [FakeLayout.rect(line: 0, columns: 10..<310)])
        #expect(layout.boundsCalls == afterFirst + 1)
        #expect(layout.rangeCalls == 0)
    }

    @Test func characterFallbackUsesBinarySearch() {
        let layout = FakeLayout(String(repeating: "x", count: 1_000), columns: 100, lineSupport: .unsupported)
        let result = rects(layout, NSRange(location: 0, length: 1_000))
        #expect(result.count == 10)
        #expect(result.allSatisfy { $0.width == 1_000 && $0.height == FakeLayout.lineHeight })
        #expect(layout.boundsCalls < 150)
    }

    @Test func lineQueriesAreCachedPerTextVersion() {
        let layout = FakeLayout("aaaaaaaaaabbbbbbbbbbcccccccccc", columns: 10)
        let cache = LineLayoutCache()
        let cached = CachingLayoutQuerier(base: layout, cache: cache)
        let range = NSRange(location: 5, length: 20)

        let first = LineSplitter.lineRects(for: range, text: layout.text, layout: cached)
        let (lineCalls, rangeCalls) = (layout.lineCalls, layout.rangeCalls)
        #expect(lineCalls > 0 && rangeCalls > 0)

        let second = LineSplitter.lineRects(for: range, text: layout.text, layout: cached)
        #expect(second == first)
        #expect(layout.lineCalls == lineCalls)
        #expect(layout.rangeCalls == rangeCalls)

        cache.invalidate()
        _ = LineSplitter.lineRects(for: range, text: layout.text, layout: cached)
        #expect(layout.lineCalls > lineCalls)
    }

    @Test func referenceLineHeightIsCached() {
        let layout = FakeLayout("hello world", columns: 100)
        let cache = LineLayoutCache()
        let cached = CachingLayoutQuerier(base: layout, cache: cache)
        #expect(cached.referenceLineHeight(at: 0) == FakeLayout.lineHeight)
        let calls = layout.boundsCalls
        #expect(cached.referenceLineHeight(at: 6) == FakeLayout.lineHeight)
        #expect(layout.boundsCalls == calls)
    }

    @Test func worksWithoutText() {
        let layout = FakeLayout("aaaaaaaaaabbbbbbbbbb", columns: 10, lineSupport: .unsupported)
        let result = LineSplitter.lineRects(for: NSRange(location: 5, length: 10), text: nil, layout: layout)
        #expect(result == [FakeLayout.rect(line: 0, columns: 5..<10), FakeLayout.rect(line: 1, columns: 0..<5)])
    }

    @Test func pipelineAsUsedByTheHandle() {
        let layout = FakeLayout("aaaaaaaaaabbbbbbbbbbcccccccccc", columns: 10)
        let visibleField = CGRect(x: 100, y: 210, width: 200, height: 40)
        let axRects = LineSplitter.lineRects(for: NSRange(location: 5, length: 20), text: layout.text, layout: layout)
        let screen = RectGeometry.screenRects(fromAX: axRects, visibleField: visibleField, primaryHeight: 1_000)
        let top = visibleField.minY - RectGeometry.clipTolerance
        let bottom = visibleField.maxY + RectGeometry.clipTolerance
        #expect(screen == [
            CGRect(x: 150, y: 1_000 - 220, width: 50, height: 220 - top),
            CGRect(x: 100, y: 1_000 - 240, width: 100, height: 20),
            CGRect(x: 100, y: 1_000 - bottom, width: 50, height: bottom - 240),
        ])
    }

    @Test func hardLineSegmentsAndTrimming() {
        let text = "ab\r\ncd \n" as NSString
        #expect(LineSplitter.hardLineSegments(of: NSRange(location: 0, length: text.length), in: text) == [
            NSRange(location: 0, length: 2),
            NSRange(location: 4, length: 3),
        ])
        #expect(LineSplitter.trimmed(NSRange(location: 4, length: 4), in: text) == NSRange(location: 4, length: 2))
        #expect(LineSplitter.trimmed(NSRange(location: 7, length: 1), in: text) == nil)
    }
}
