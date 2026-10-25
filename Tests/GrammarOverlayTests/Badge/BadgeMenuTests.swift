import AppKit
import GrammarModels
import Testing
@testable import GrammarOverlay

@MainActor
@Suite struct BadgeMenuTests {
    private final class Recorder {
        var placements: [String] = []
        var spacings: [Double] = []
        var openedSettings = 0
    }

    private func actions(_ recorder: Recorder) -> OverlayActions {
        OverlayActions(
            accept: { _, _ in }, ignore: { _ in }, restore: { _ in }, addToDictionary: { _ in }, fixAll: {},
            openSettings: {}, disableForCurrentApp: {},
            setBadgePlacement: { placement, kind in recorder.placements.append("\(placement.rawValue) for \(kind.rawValue)") },
            setBadgeSpacing: { recorder.spacings.append($0) },
            openBadgeSettings: { recorder.openedSettings += 1 },
            toggleSuggestions: {}, requestRewrite: { _ in }, rephraseSentence: { _ in }, rewriteText: { _, _ in },
            requestInstructionRewrite: { _ in }, acceptRewrite: { _ in }, cancelRewrite: {},
            requestCompose: { _, _ in }, acceptCompose: { _ in }, cancelCompose: {}
        )
    }

    private func item(_ title: String, in menu: NSMenu?) -> NSMenuItem? {
        menu?.items.first { $0.title == title }
    }

    private func click(_ item: NSMenuItem?) {
        guard let item, let action = item.action, let target = item.target as? NSObject else {
            Issue.record("the item does nothing")
            return
        }
        _ = target.perform(action, with: item)
    }

    @Test func listsEveryPlacementInGroupsAndTicksTheCurrentOne() {
        let menu = BadgeMenu.make(kind: .input, placement: .below, spacing: 8, actions: actions(Recorder()))
        #expect(menu.items.map { $0.isSeparatorItem ? "—" : $0.title } == [
            "Badge in Input fields",
            "Automatic", "—",
            "Inside, bottom right", "Inside, top right", "Inside, bottom left", "Inside, top left", "—",
            "Right of the field", "Left of the field", "Above the field", "Below the field", "—",
            "Distance from the Field", "—",
            "Badge Settings…",
        ])
        let placements = menu.items.filter { item in BadgePlacement.allCases.contains { $0.displayName == item.title } }
        #expect(placements.count == BadgePlacement.allCases.count)
        #expect(placements.filter { $0.state == .on }.map(\.title) == ["Below the field"])
        #expect(item("Automatic", in: menu)?.toolTip == "Left of the field, so it doesn't cover what you type.")
    }

    @Test func choicesAreMadeForThatKindOfField() {
        let recorder = Recorder()
        let menu = BadgeMenu.make(kind: .textArea, placement: .automatic, spacing: 8, actions: actions(recorder))
        #expect(item("Automatic", in: menu)?.toolTip == BadgePlacement.automatic.detail(for: .textArea))
        click(item("Left of the field", in: menu))
        click(item("Badge Settings…", in: menu))

        let distance = item("Distance from the Field", in: menu)
        #expect(distance?.isEnabled == true)
        #expect(distance?.submenu?.items.map(\.title) == ["4 pt", "8 pt", "12 pt", "16 pt", "24 pt", "32 pt", "40 pt"])
        #expect(distance?.submenu?.items.filter { $0.state == .on }.map(\.title) == ["8 pt"])
        click(item("40 pt", in: distance?.submenu))

        #expect(recorder.placements == ["left for textArea"])
        #expect(recorder.spacings == [40])
        #expect(recorder.openedSettings == 1)
    }

    @Test func aBadgeInsideTheFieldHasNoDistance() {
        let menu = BadgeMenu.make(kind: .input, placement: .insideTopLeft, spacing: 8, actions: actions(Recorder()))
        #expect(item("Distance from the Field", in: menu)?.isEnabled == false)
    }

    @Test func distancesAreInRangeAndIncludeTheCurrentOne() {
        #expect(BadgeMenu.spacingSteps.allSatisfy(AppSettings.badgeSpacingRange.contains))
        #expect(BadgeMenu.spacingSteps.contains(AppSettings.defaultBadgeSpacing))
        #expect(BadgeMenu.spacingOptions(current: 8) == BadgeMenu.spacingSteps)
        #expect(BadgeMenu.spacingOptions(current: 13) == [4, 8, 12, 13, 16, 24, 32, 40])
    }
}
