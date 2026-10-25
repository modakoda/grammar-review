import CoreGraphics
import GrammarModels
import Testing
@testable import GrammarAccessibility

@Suite("Rect validation, clipping and flipping")
struct RectGeometryTests {
    let field = CGRect(x: 100, y: 200, width: 400, height: 300)

    @Test func normalRectInsideFieldIsPlausible() {
        #expect(RectGeometry.isPlausible(CGRect(x: 120, y: 220, width: 40, height: 16), field: field))
    }

    @Test(arguments: [
        CGRect(x: 120, y: 220, width: 0, height: 16),
        CGRect(x: 120, y: 220, width: 40, height: 0),
        CGRect(x: 120, y: 220, width: -40, height: 16),
        CGRect(x: CGFloat.nan, y: 220, width: 40, height: 16),
        CGRect(x: 120, y: 220, width: CGFloat.infinity, height: 16),
        CGRect(x: 120, y: 220, width: 40, height: 50_000),
        CGRect(x: 1_000_000, y: 220, width: 40, height: 16),
    ])
    func garbageRectsAreRejected(rect: CGRect) {
        #expect(!RectGeometry.isPlausible(rect, field: field))
        #expect(!RectGeometry.isPlausible(rect, field: nil))
    }

    @Test func rectAtGlobalOriginIsRejectedUnlessFieldIsThere() {
        let origin = CGRect(x: 0, y: 0, width: 40, height: 16)
        #expect(!RectGeometry.isPlausible(origin, field: field))
        #expect(!RectGeometry.isPlausible(origin, field: nil))
        #expect(RectGeometry.isPlausible(origin, field: CGRect(x: 0, y: 0, width: 300, height: 100)))
    }

    @Test func rectFarOutsideFieldIsRejected() {
        #expect(!RectGeometry.isPlausible(CGRect(x: 120, y: 2_000, width: 40, height: 16), field: field))
        #expect(!RectGeometry.isPlausible(CGRect(x: 900, y: 220, width: 40, height: 16), field: field))
    }

    @Test func withoutFieldFrameOnlyGarbageIsRejected() {
        #expect(RectGeometry.isPlausible(CGRect(x: 1_200, y: 900, width: 40, height: 16), field: nil))
    }

    @Test func rectCrossingFieldEdgeIsClipped() throws {
        let clipped = try #require(RectGeometry.clip(CGRect(x: 120, y: 190, width: 40, height: 20), to: field))
        #expect(clipped.minY == field.minY - RectGeometry.clipTolerance)
        #expect(clipped.maxY == 210)
        #expect(clipped.width == 40)
    }

    @Test func rectOutsideFieldClipsToNothing() {
        #expect(RectGeometry.clip(CGRect(x: 120, y: 600, width: 40, height: 20), to: field) == nil)
    }

    @Test func screenRectsAreFlippedToAppKit() {
        let rects = RectGeometry.screenRects(
            fromAX: [CGRect(x: 120, y: 220, width: 40, height: 16)],
            visibleField: field,
            primaryHeight: 1_000
        )
        #expect(rects == [CGRect(x: 120, y: 764, width: 40, height: 16)])
    }

    @Test func screenRectsDropGarbageAndClip() {
        let rects = RectGeometry.screenRects(
            fromAX: [
                CGRect(x: 0, y: 0, width: 50, height: 16),
                CGRect(x: 120, y: 490, width: 40, height: 20),
                CGRect(x: 120, y: 900, width: 40, height: 16),
            ],
            visibleField: field,
            primaryHeight: 1_000
        )
        let bottom = field.maxY + RectGeometry.clipTolerance
        #expect(rects == [CGRect(x: 120, y: 1_000 - bottom, width: 40, height: bottom - 490)])
    }

    @Test func flipMatchesScreenGeometryAndIsItsOwnInverse() {
        let ax = CGRect(x: 10, y: 30, width: 200, height: 50)
        let appKit = ScreenGeometry.flip(ax, primaryHeight: 900)
        #expect(appKit == CGRect(x: 10, y: 820, width: 200, height: 50))
        #expect(ScreenGeometry.flip(appKit, primaryHeight: 900) == ax)
    }

    @Test func secondaryDisplayAboveThePrimaryHasNegativeAXY() {
        let rects = RectGeometry.screenRects(fromAX: [CGRect(x: 50, y: -400, width: 30, height: 20)], visibleField: nil, primaryHeight: 1_000)
        #expect(rects == [CGRect(x: 50, y: 1_380, width: 30, height: 20)])
    }

    @Test func visibleFrameIsClippedToScrollAreaAndWindow() {
        let textView = CGRect(x: 100, y: 0, width: 400, height: 5_000)
        let scrollArea = CGRect(x: 100, y: 200, width: 400, height: 300)
        let window = CGRect(x: 50, y: 150, width: 600, height: 500)
        #expect(RectGeometry.visibleFrame(field: textView, clips: [scrollArea, window]) == .visible(scrollArea))
    }

    @Test func visibleFrameIgnoresBogusAncestors() {
        let frame = RectGeometry.visibleFrame(field: field, clips: [.zero, CGRect(x: 0, y: 0, width: CGFloat.nan, height: 10)])
        #expect(frame == .visible(field))
    }

    @Test func fieldScrolledOutOfItsScrollAreaIsHidden() {
        let scrollArea = CGRect(x: 100, y: 1_000, width: 400, height: 300)
        #expect(RectGeometry.visibleFrame(field: field, clips: [scrollArea]) == .hidden)
    }

    @Test func unusableFieldFrameIsUnknown() {
        #expect(RectGeometry.visibleFrame(field: .zero, clips: []) == .unknown)
    }

    @Test func sameLineDetection() {
        let a = CGRect(x: 0, y: 100, width: 8, height: 16)
        #expect(RectGeometry.onSameLine(a, CGRect(x: 50, y: 102, width: 8, height: 14)))
        #expect(!RectGeometry.onSameLine(a, CGRect(x: 0, y: 116, width: 8, height: 16)))
    }
}
