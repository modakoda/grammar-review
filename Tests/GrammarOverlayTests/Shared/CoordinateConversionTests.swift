import CoreGraphics
import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct CoordinateConversionTests {
    let window = CGRect(x: 100, y: 200, width: 400, height: 300)

    @Test func globalToWindowLocal() {
        let global = CGRect(x: 150, y: 260, width: 40, height: 18)
        #expect(CoordinateConversion.toWindow(global, windowFrame: window) == CGRect(x: 50, y: 60, width: 40, height: 18))
        #expect(CoordinateConversion.toWindow(CGPoint(x: 100, y: 500), windowFrame: window) == CGPoint(x: 0, y: 300))
    }

    @Test func windowLocalToGlobalRoundTrips() {
        let global = CGRect(x: 123.5, y: 456.25, width: 40, height: 18)
        let local = CoordinateConversion.toWindow(global, windowFrame: window)
        #expect(CoordinateConversion.toScreen(local, windowFrame: window) == global)
    }

    @Test func globalToFlippedWindowLocal() {
        let topLeft = CGRect(x: 100, y: 480, width: 40, height: 20)
        #expect(CoordinateConversion.toFlippedWindow(topLeft, windowFrame: window) == CGRect(x: 0, y: 0, width: 40, height: 20))
        let bottom = CGRect(x: 110, y: 200, width: 40, height: 20)
        #expect(CoordinateConversion.toFlippedWindow(bottom, windowFrame: window) == CGRect(x: 10, y: 280, width: 40, height: 20))
    }

    @Test func clampedMovesAndShrinksIntoBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(CGRect(x: 90, y: -5, width: 20, height: 20).clamped(into: bounds) == CGRect(x: 80, y: 0, width: 20, height: 20))
        #expect(CGRect(x: 10, y: 10, width: 300, height: 20).clamped(into: bounds) == CGRect(x: 0, y: 10, width: 100, height: 20))
    }

    @Test func geometryPredicates() {
        #expect(!CGRect.null.hasFiniteGeometry)
        #expect(!CGRect.infinite.hasFiniteGeometry)
        #expect(!CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1).hasFiniteGeometry)
        #expect(!CGRect(x: 0, y: 0, width: 10, height: 0).isDrawable)
        #expect(CGRect(x: 0, y: 0, width: 10, height: 1).isDrawable)
        #expect(CGRect(x: 0, y: 0, width: 10, height: 10).containsInclusive(CGPoint(x: 10, y: 10)))
        #expect(CGRect(x: 0, y: 0, width: 10, height: 10).distance(to: CGPoint(x: 13, y: 14)) == 5)
    }
}
