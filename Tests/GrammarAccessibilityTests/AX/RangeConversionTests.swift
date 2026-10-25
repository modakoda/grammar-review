import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("CFRange ↔ NSRange and AXValue conversion")
struct RangeConversionTests {
    @Test func validRangesRoundTrip() throws {
        for range in [NSRange(location: 0, length: 0), NSRange(location: 3, length: 5), NSRange(location: 10_000, length: 1)] {
            let cfRange = try #require(RangeConversion.cfRange(from: range))
            #expect(cfRange.location == range.location)
            #expect(cfRange.length == range.length)
            #expect(RangeConversion.nsRange(from: cfRange) == range)
        }
    }

    @Test func notFoundIsRejected() {
        #expect(RangeConversion.cfRange(from: NSRange(location: NSNotFound, length: 0)) == nil)
        #expect(RangeConversion.nsRange(from: CFRange(location: kCFNotFound, length: 0)) == nil)
    }

    @Test func negativeValuesAreRejected() {
        #expect(RangeConversion.nsRange(from: CFRange(location: -3, length: 2)) == nil)
        #expect(RangeConversion.nsRange(from: CFRange(location: 3, length: -2)) == nil)
        #expect(RangeConversion.cfRange(from: NSRange(location: -1, length: 2)) == nil)
    }

    @Test func overflowingRangeIsRejected() {
        #expect(RangeConversion.nsRange(from: CFRange(location: Int.max - 1, length: 5)) == nil)
    }

    @Test func rangeRoundTripsThroughAXValue() throws {
        let range = NSRange(location: 7, length: 4)
        let value = try #require(AXValueConversion.makeValue(range))
        #expect(AXValueGetType(value) == .cfRange)
        #expect(AXValueConversion.range(value) == range)
    }

    @Test func geometryRoundTripsThroughAXValue() throws {
        let rect = CGRect(x: 10.5, y: 20, width: 300, height: 18)
        #expect(AXValueConversion.rect(try #require(AXValueConversion.makeValue(rect))) == rect)
        #expect(AXValueConversion.point(try #require(AXValueConversion.makeValue(rect.origin))) == rect.origin)
        #expect(AXValueConversion.size(try #require(AXValueConversion.makeValue(rect.size))) == rect.size)
    }

    @Test func wrongAXValueTypeGivesNil() throws {
        let rectValue = try #require(AXValueConversion.makeValue(CGRect(x: 0, y: 0, width: 1, height: 1)))
        #expect(AXValueConversion.range(rectValue) == nil)
        #expect(AXValueConversion.point(rectValue) == nil)
        let rangeValue = try #require(AXValueConversion.makeValue(NSRange(location: 1, length: 1)))
        #expect(AXValueConversion.rect(rangeValue) == nil)
    }

    @Test func cfTypeHelpers() {
        #expect(AXValueConversion.string("hello" as CFString) == "hello")
        #expect(AXValueConversion.string(NSNumber(value: 3)) == nil)
        #expect(AXValueConversion.bool(kCFBooleanTrue) == true)
        #expect(AXValueConversion.bool(NSNumber(value: 0)) == false)
        #expect(AXValueConversion.int(NSNumber(value: 42)) == 42)
        #expect(AXValueConversion.int("42" as CFString) == nil)
        #expect(AXValueConversion.axValue("x" as CFString) == nil)
        #expect(AXValueConversion.isString("x" as CFString))
        #expect(!AXValueConversion.isString(nil))
    }
}
