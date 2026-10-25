import ApplicationServices
import CoreGraphics
import Foundation

nonisolated enum LineSplitter {
    static let maxLines = 200
    static let multiLineFactor: CGFloat = 1.6
    static let probeWindow = 8

    static func lineRects(for range: NSRange, text: NSString?, layout: some TextLayoutQuerying) -> [CGRect] {
        guard range.location != NSNotFound, range.location >= 0, range.length > 0 else { return [] }
        if let text, NSMaxRange(range) > text.length { return [] }

        guard let segments = lineSegments(for: range, layout: layout) else {
            return splitByCharacters(range, text: text, layout: layout)
        }
        var rects: [CGRect] = []
        for segment in segments {
            guard let segment = trimmed(segment, in: text),
                  let rect = layout.bounds(for: segment), isUsableRect(rect)
            else { continue }
            if segment.length > 1, let lineHeight = layout.referenceLineHeight(at: segment.location),
               rect.height > lineHeight * multiLineFactor {
                rects += splitByCharacters(segment, text: text, layout: layout)
            } else {
                rects.append(rect)
            }
            if rects.count >= maxLines { break }
        }
        return rects
    }

    static func lineSegments(for range: NSRange, layout: some TextLayoutQuerying) -> [NSRange]? {
        guard let firstLine = layout.line(forIndex: range.location),
              let lastLine = layout.line(forIndex: NSMaxRange(range) - 1),
              lastLine >= firstLine
        else { return nil }
        if firstLine == lastLine { return [range] }

        var segments: [NSRange] = []
        for line in firstLine...min(lastLine, firstLine + maxLines - 1) {
            guard let lineRange = layout.range(forLine: line) else { return nil }
            let part = NSIntersectionRange(lineRange, range)
            if part.length > 0 { segments.append(part) }
        }
        return segments.isEmpty ? nil : segments
    }

    static func splitByCharacters(_ range: NSRange, text: NSString?, layout: some TextLayoutQuerying) -> [CGRect] {
        var rects: [CGRect] = []
        for hardLine in hardLineSegments(of: range, in: text) {
            var start = hardLine.location
            let end = NSMaxRange(hardLine)
            while start < end, rects.count < maxLines {
                guard let (firstIndex, firstRect) = firstMeasurableCharacter(from: start, before: end, layout: layout) else { break }
                let last = lastIndexOnLine(of: firstRect, from: firstIndex, before: end, layout: layout)
                let lineRange = NSRange(location: firstIndex, length: last - firstIndex + 1)
                let segment = trimmed(lineRange, in: text) ?? lineRange
                if let rect = lineRect(for: segment, firstCharacter: firstRect, layout: layout) {
                    rects.append(rect)
                }
                start = last + 1
            }
        }
        return rects
    }

    static func lastIndexOnLine(of first: CGRect, from start: Int, before end: Int, layout: some TextLayoutQuerying) -> Int {
        var low = start
        var high = end - 1
        guard high > low else { return low }
        if let (index, rect) = measurable(at: high, above: low, layout: layout) {
            if RectGeometry.onSameLine(first, rect) { return high }
            high = index
        } else {
            return high
        }
        while high - low > 1 {
            let mid = low + (high - low) / 2
            if let (index, rect) = measurable(at: mid, above: low, layout: layout) {
                if RectGeometry.onSameLine(first, rect) { low = mid } else { high = index }
            } else {
                low = mid
            }
        }
        return low
    }

    private static func firstMeasurableCharacter(from start: Int, before end: Int, layout: some TextLayoutQuerying) -> (Int, CGRect)? {
        var index = start
        while index < end, index - start < 64 {
            if let rect = characterRect(at: index, layout: layout) { return (index, rect) }
            index += 1
        }
        return nil
    }

    private static func measurable(at index: Int, above floor: Int, layout: some TextLayoutQuerying) -> (Int, CGRect)? {
        var candidate = index
        while candidate > floor, index - candidate < probeWindow {
            if let rect = characterRect(at: candidate, layout: layout) { return (candidate, rect) }
            candidate -= 1
        }
        return nil
    }

    private static func characterRect(at index: Int, layout: some TextLayoutQuerying) -> CGRect? {
        guard let rect = layout.bounds(for: NSRange(location: index, length: 1)), isUsableCharacterRect(rect) else { return nil }
        return rect
    }

    private static func lineRect(for segment: NSRange, firstCharacter: CGRect, layout: some TextLayoutQuerying) -> CGRect? {
        if let rect = layout.bounds(for: segment), isUsableRect(rect), rect.height <= firstCharacter.height * multiLineFactor {
            return rect
        }
        if segment.length == 1 { return isUsableRect(firstCharacter) ? firstCharacter : nil }
        if let last = characterRect(at: NSMaxRange(segment) - 1, layout: layout), RectGeometry.onSameLine(firstCharacter, last) {
            let union = firstCharacter.union(last)
            return isUsableRect(union) ? union : nil
        }
        return nil
    }

    static func hardLineSegments(of range: NSRange, in text: NSString?) -> [NSRange] {
        guard let text else { return [range] }
        var segments: [NSRange] = []
        var segmentStart = range.location
        for index in range.location..<NSMaxRange(range) where isLineBreak(text.character(at: index)) {
            if index > segmentStart { segments.append(NSRange(location: segmentStart, length: index - segmentStart)) }
            segmentStart = index + 1
        }
        if NSMaxRange(range) > segmentStart {
            segments.append(NSRange(location: segmentStart, length: NSMaxRange(range) - segmentStart))
        }
        return segments
    }

    static func trimmed(_ segment: NSRange, in text: NSString?) -> NSRange? {
        guard let text else { return segment }
        var end = NSMaxRange(segment)
        while end > segment.location, isLineBreak(text.character(at: end - 1)) { end -= 1 }
        guard end > segment.location else { return nil }
        var withoutSpaces = end
        while withoutSpaces > segment.location, isHorizontalWhitespace(text.character(at: withoutSpaces - 1)) { withoutSpaces -= 1 }
        if withoutSpaces > segment.location { end = withoutSpaces }
        return NSRange(location: segment.location, length: end - segment.location)
    }

    static func isLineBreak(_ c: unichar) -> Bool {
        c == 0x0A || c == 0x0D || c == 0x0B || c == 0x0C || c == 0x85 || c == 0x2028 || c == 0x2029
    }

    static func isHorizontalWhitespace(_ c: unichar) -> Bool {
        c == 0x20 || c == 0x09 || c == 0xA0 || c == 0x3000
    }

    static func isUsableRect(_ rect: CGRect) -> Bool {
        RectGeometry.isFinite(rect) && rect.size.width > 0 && rect.size.height > 0
    }

    static func isUsableCharacterRect(_ rect: CGRect) -> Bool {
        RectGeometry.isFinite(rect) && rect.size.width >= 0 && rect.size.height > 0
    }
}
