import CoreGraphics
import Testing
@testable import GrammarOverlay

@Suite struct ScreenChooserTests {
    @Test func picksTheScreenContainingTheRect() {
        let rect = CGRect(x: 2000, y: 400, width: 100, height: 20)
        #expect(ScreenChooser.screen(for: rect, among: [primaryScreen, rightScreen]) == rightScreen)
    }

    @Test func picksTheScreenWithTheLargestOverlap() {
        let rect = CGRect(x: 1400, y: 400, width: 200, height: 20)
        #expect(ScreenChooser.screen(for: rect, among: [primaryScreen, rightScreen]) == rightScreen)
        let mostlyLeft = CGRect(x: 1300, y: 400, width: 200, height: 20)
        #expect(ScreenChooser.screen(for: mostlyLeft, among: [primaryScreen, rightScreen]) == primaryScreen)
    }

    @Test func zeroAreaRectUsesTheScreenContainingItsCentre() {
        let caret = CGRect(x: 1600, y: 300, width: 0, height: 18)
        #expect(ScreenChooser.screen(for: caret, among: [primaryScreen, rightScreen]) == rightScreen)
    }

    @Test func offScreenRectUsesTheNearestScreen() {
        let farRight = CGRect(x: 5000, y: 300, width: 10, height: 10)
        #expect(ScreenChooser.screen(for: farRight, among: [primaryScreen, rightScreen]) == rightScreen)
        let farLeft = CGRect(x: -900, y: 300, width: 10, height: 10)
        #expect(ScreenChooser.screen(for: farLeft, among: [primaryScreen, rightScreen]) == primaryScreen)
    }

    @Test func noScreensGivesNil() {
        #expect(ScreenChooser.screen(for: CGRect(x: 0, y: 0, width: 10, height: 10), among: []) == nil)
    }

    @Test func nonFiniteRectFallsBackToTheFirstScreen() {
        #expect(ScreenChooser.screen(for: .null, among: [rightScreen, primaryScreen]) == rightScreen)
    }
}
