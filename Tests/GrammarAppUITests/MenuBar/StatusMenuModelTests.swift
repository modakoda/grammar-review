import AppKit
import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct StatusMenuModelTests {
    let calendar = Calendar.fixed("UTC")
    let locale = Locale(identifier: "en_GB")
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10))! }

    private func line(_ status: MenuBarStatus, _ settings: AppSettings = AppSettings()) -> String {
        StatusMenuModel.statusLine(for: status, settings: settings, now: now, calendar: calendar, locale: locale)
    }

    @Test func statusLineForEachStatus() {
        #expect(line(.active) == "Checking is on")
        #expect(line(.disabledForApp("Xcode")) == "Checking is off in Xcode")
        #expect(line(.needsPermission) == "Accessibility permission needed — Grant…")
        #expect(line(.windowsHidden) == "macOS is hiding text fields — log out or restart")
        #expect(line(.aiUnavailable("Add an API key")) == "AI unavailable: Add an API key")
    }

    @Test func statusLineWhenTurnedOff() {
        var settings = AppSettings()
        settings.isEnabled = false
        settings.pausedUntil = now.addingTimeInterval(600)
        #expect(line(.paused, settings) == "Checking is off")
    }

    @Test func statusLineWhenPausedUntilLaterToday() {
        var settings = AppSettings()
        settings.pausedUntil = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 14, minute: 30))
        #expect(line(.paused, settings) == "Paused until 14:30")
    }

    @Test func statusLineWhenPausedUntilTomorrow() {
        var settings = AppSettings()
        settings.pausedUntil = SettingsStore.startOfNextDay(after: now, calendar: calendar)
        #expect(line(.paused, settings) == "Paused until tomorrow")
    }

    @Test func statusLineWhenPausedForLonger() {
        var settings = AppSettings()
        settings.pausedUntil = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 9, minute: 5))
        let text = line(.paused, settings)
        #expect(text.hasPrefix("Paused until "))
        #expect(text.contains("Wed"))
        #expect(text.contains("09:05"))
    }

    @Test func statusLineWhenPauseAlreadyEnded() {
        var settings = AppSettings()
        settings.pausedUntil = now.addingTimeInterval(-1)
        #expect(line(.paused, settings) == "Paused")
    }

    @Test func tooltipNamesTheApp() {
        let tooltip = StatusMenuModel.tooltip(for: .active, settings: AppSettings(), now: now, calendar: calendar, locale: locale)
        #expect(tooltip == "Grammar Review — Checking is on")
        let permission = StatusMenuModel.tooltip(for: .needsPermission, settings: AppSettings(), now: now)
        #expect(permission == "Grammar Review — Accessibility permission needed")
        let hidden = StatusMenuModel.tooltip(for: .windowsHidden, settings: AppSettings(), now: now)
        #expect(hidden == "Grammar Review — macOS is hiding text fields — log out or restart")
    }

    @Test func symbolForEachStatus() {
        #expect(StatusMenuModel.symbolName(for: .active) == "text.badge.checkmark")
        #expect(StatusMenuModel.symbolName(for: .paused) == "pause.circle")
        #expect(StatusMenuModel.symbolName(for: .needsPermission) == "exclamationmark.triangle")
        #expect(StatusMenuModel.symbolName(for: .aiUnavailable("x")) == "text.badge.xmark")
        #expect(StatusMenuModel.symbolName(for: .disabledForApp("Notes")) == "text.badge.minus")
        #expect(StatusMenuModel.symbolName(for: .windowsHidden) == "exclamationmark.triangle")
        for status: MenuBarStatus in [.active, .paused, .needsPermission, .windowsHidden, .aiUnavailable("x"), .disabledForApp("x")] {
            #expect(NSImage(systemSymbolName: StatusMenuModel.symbolName(for: status), accessibilityDescription: nil) != nil)
        }
    }

    @Test func settingsChangesShowUpBeforeTheCoordinatorReports() {
        var off = AppSettings()
        off.isEnabled = false
        #expect(StatusMenuModel.effectiveStatus(reported: .active, settings: off, now: now) == .paused)

        var paused = AppSettings()
        paused.pausedUntil = now.addingTimeInterval(60)
        #expect(StatusMenuModel.effectiveStatus(reported: .aiUnavailable("Offline"), settings: paused, now: now) == .paused)

        #expect(StatusMenuModel.effectiveStatus(reported: .paused, settings: AppSettings(), now: now) == .active)
    }

    @Test func missingPermissionAlwaysWins() {
        var off = AppSettings()
        off.isEnabled = false
        #expect(StatusMenuModel.effectiveStatus(reported: .needsPermission, settings: off, now: now) == .needsPermission)
    }

    @Test func hiddenWindowsShowUnlessPaused() {
        #expect(StatusMenuModel.effectiveStatus(reported: .windowsHidden, settings: AppSettings(), now: now) == .windowsHidden)
        var off = AppSettings()
        off.isEnabled = false
        #expect(StatusMenuModel.effectiveStatus(reported: .windowsHidden, settings: off, now: now) == .paused)
    }

    @Test func aiUnavailableIsHiddenWhileAIIsOff() {
        var aiOff = AppSettings()
        aiOff.aiEnabled = false
        #expect(StatusMenuModel.effectiveStatus(reported: .aiUnavailable("Add an API key"), settings: aiOff, now: now) == .active)
        #expect(StatusMenuModel.effectiveStatus(reported: .aiUnavailable("Add an API key"), settings: AppSettings(), now: now)
            == .aiUnavailable("Add an API key"))
        #expect(StatusMenuModel.effectiveStatus(reported: .disabledForApp("Xcode"), settings: AppSettings(), now: now)
            == .disabledForApp("Xcode"))
    }

    private func items(
        _ status: MenuBarStatus = .active,
        settings: AppSettings = AppSettings(),
        app: FrontmostAppInfo? = FrontmostAppInfo(bundleID: "com.apple.Safari", name: "Safari"),
        updates: UpdateMenuState = .ready
    ) -> [StatusMenuItem] {
        StatusMenuModel.items(
            status: status, settings: settings, frontmostApp: app, updates: updates, now: now, calendar: calendar, locale: locale
        )
    }

    private func item(_ title: String, in items: [StatusMenuItem]) -> StatusMenuItem? {
        items.first { $0.title == title }
    }

    @Test func menuLayout() {
        let titles = items().map { $0.isSeparator ? "—" : $0.title }
        #expect(titles == [
            "Checking is on", "—",
            "Enabled", "Pause", "AI Suggestions", "Language", "Disable in Safari", "Writing Goals in Safari", "—",
            "Open Editor…", "Show Suggestions", "Rewrite Selection or Sentence", "Write with AI…", "—",
            "Settings…", "Check for Updates…", "Setup Guide…", "—",
            "Quit Grammar Review",
        ])
    }

    @Test func checkForUpdates() {
        #expect(item("Check for Updates…", in: items())?.command == .checkForUpdates)
        let checking = item("Check for Updates…", in: items(updates: .checking))
        #expect(checking != nil && checking?.command == nil)
        let found = items(updates: .updateAvailable("0.2.0"))
        #expect(item("Update to Version 0.2.0…", in: found)?.command == .checkForUpdates)
        #expect(item("Check for Updates…", in: found) == nil)
        let none = items(updates: .unavailable)
        #expect(!none.contains { $0.command == .checkForUpdates || $0.title.contains("Update") })
        #expect(none.map(\.title).suffix(4) == ["Settings…", "Setup Guide…", "", "Quit Grammar Review"])
    }

    @Test func statusLineIsInformationalUnlessPermissionIsMissing() {
        let normal = items()[0]
        #expect(normal.command == nil)
        #expect(!normal.isEnabled)

        let permission = items(.needsPermission)[0]
        #expect(permission.title == "Accessibility permission needed — Grant…")
        #expect(permission.command == .showOnboarding)

        let hidden = items(.windowsHidden)[0]
        #expect(hidden.title == "macOS is hiding text fields — log out or restart")
        #expect(hidden.command == nil)
    }

    @Test func togglesReflectSettings() {
        var settings = AppSettings()
        settings.aiEnabled = false
        let menu = items(settings: settings)
        #expect(item("Enabled", in: menu)?.isOn == true)
        #expect(item("Enabled", in: menu)?.command == .toggleEnabled)
        #expect(item("AI Suggestions", in: menu)?.isOn == false)
        #expect(item("AI Suggestions", in: menu)?.command == .toggleAI)
    }

    @Test func pauseSubmenu() throws {
        let submenu = try #require(item("Pause", in: items())?.submenu)
        #expect(submenu.map(\.title) == ["For 30 Minutes", "For 1 Hour", "Until Tomorrow", "", "Resume"])
        #expect(submenu[0].command == .pause(30 * 60))
        #expect(submenu[1].command == .pause(60 * 60))
        #expect(submenu[2].command == .pauseUntilTomorrow)
        #expect(submenu[4].command == nil)
        #expect(item("Pause", in: items())?.isOn == false)
    }

    @Test func resumeIsAvailableWhilePaused() throws {
        var settings = AppSettings()
        settings.pausedUntil = now.addingTimeInterval(600)
        let pause = try #require(item("Pause", in: items(.paused, settings: settings)))
        #expect(pause.isOn == true)
        #expect(pause.submenu?.last?.command == .resume)
    }

    @Test func pausingIsUnavailableWhileTurnedOff() throws {
        var settings = AppSettings()
        settings.isEnabled = false
        let submenu = try #require(item("Pause", in: items(.paused, settings: settings))?.submenu)
        #expect(submenu.prefix(3).allSatisfy { $0.command == nil })
        #expect(submenu.last?.command == .resume)
    }

    @Test func languageSubmenu() throws {
        var settings = AppSettings()
        settings.languageMode = .fixed("lt")
        let menu = StatusMenuModel.items(
            status: .active,
            settings: settings,
            frontmostApp: nil,
            keyboard: KeyboardLanguages(current: "lt", enabled: ["en", "lt"]),
            preferredLanguages: ["en-LT", "lt-LT"],
            now: now,
            calendar: calendar,
            locale: locale
        )
        let submenu = try #require(item("Language", in: menu)?.submenu)
        #expect(submenu.map(\.title) == [
            "Detect from Text", "Match Keyboard (Lithuanian)", "", "English", "Lithuanian", "", "Other Languages…",
        ])
        #expect(submenu.map(\.isOn) == [false, false, nil, false, true, nil, nil])
        #expect(submenu[0].command == .setLanguageMode(.automatic))
        #expect(submenu[1].command == .setLanguageMode(.keyboard))
        #expect(submenu[3].command == .setLanguageMode(.fixed("en")))
        #expect(submenu[4].command == .setLanguageMode(.fixed("lt")))
        #expect(submenu.last?.command == .openLanguageSettings)
    }

    @Test func languageSubmenuListsAFixedLanguageTheUserDoesntOtherwiseUse() throws {
        var settings = AppSettings()
        settings.languageMode = .fixed("de-DE")
        let submenu = try #require(item("Language", in: items(settings: settings))?.submenu)
        #expect(submenu.map(\.title) == ["Detect from Text", "Match Keyboard", "", "German (Germany)", "", "Other Languages…"])
        #expect(submenu[3].isOn == true)
        #expect(item("Language", in: items())?.submenu?.first?.isOn == true)
    }

    @Test func frontmostAppToggle() {
        let disable = item("Disable in Safari", in: items())
        #expect(disable?.command == .setAppDisabled(bundleID: "com.apple.Safari", disabled: true))

        let terminal = FrontmostAppInfo(bundleID: "com.apple.Terminal", name: "Terminal")
        let enable = item("Enable in Terminal", in: items(app: terminal))
        #expect(enable?.command == .setAppDisabled(bundleID: "com.apple.Terminal", disabled: false))

        let none = items(app: nil)
        #expect(!none.contains { $0.title.hasPrefix("Disable in") || $0.title.hasPrefix("Enable in") })
    }

    @Test func writingGoalsForTheFrontmostApp() throws {
        let menu = try #require(item("Writing Goals in Safari", in: items())?.submenu)
        #expect(item("Writing Goals in Safari", in: items())?.isOn == nil, "no checkmark without goals")
        #expect(menu.first?.title == "Style" && menu.first?.command == nil, "group titles are disabled")
        #expect(menu.first { $0.title == "Neutral" }?.isOn == true)
        #expect(menu.first { $0.title == "Formal" }?.command == .setAppGoals(bundleID: "com.apple.Safari", goals: WritingGoals(style: .formal)))
        #expect(!menu.contains { $0.title == "Clear Goals" })
        #expect(menu.last?.command == .openGoalsSettings)

        var settings = AppSettings()
        settings.appGoals["com.apple.Safari"] = WritingGoals(style: .formal, audience: .expert)
        let withGoals = try #require(item("Writing Goals in Safari", in: items(settings: settings)))
        #expect(withGoals.isOn == true)
        let submenu = try #require(withGoals.submenu)
        #expect(submenu.first { $0.title == "Expert" }?.isOn == true)
        #expect(submenu.first { $0.title == "Email" }?.command
            == .setAppGoals(bundleID: "com.apple.Safari", goals: WritingGoals(style: .formal, audience: .expert, domain: .email)))
        #expect(submenu.first { $0.title == "Clear Goals" }?.command == .setAppGoals(bundleID: "com.apple.Safari", goals: .none))

        let terminal = FrontmostAppInfo(bundleID: "com.apple.Terminal", name: "Terminal")
        #expect(item("Writing Goals in Terminal", in: items(app: terminal)) == nil)
    }

    @Test func shortcutsAndCommands() {
        let menu = items()
        let show = item("Show Suggestions", in: menu)
        #expect(show?.command == .showSuggestions)
        #expect(show?.keyEquivalent == "g")
        #expect(show?.modifiers == [.control, .option])

        let rewrite = item("Rewrite Selection or Sentence", in: menu)
        #expect(rewrite?.command == .rewriteSelection)
        #expect(rewrite?.keyEquivalent == "r")
        #expect(rewrite?.modifiers == [.control, .option])

        let write = item("Write with AI…", in: menu)
        #expect(write?.command == .writeWithAI)
        #expect(write?.keyEquivalent == "w")
        #expect(write?.modifiers == [.control, .option])

        let editor = item("Open Editor…", in: menu)
        #expect(editor?.command == .openEditor)
        #expect(editor?.keyEquivalent == "e")
        #expect(editor?.modifiers == [.control, .option])

        #expect(item("Settings…", in: menu)?.command == .openSettings)
        #expect(item("Settings…", in: menu)?.keyEquivalent == ",")
        #expect(item("Settings…", in: menu)?.modifiers == .command)
        #expect(item("Setup Guide…", in: menu)?.command == .showOnboarding)
        #expect(item("Quit Grammar Review", in: menu)?.command == .quit)
        #expect(item("Quit Grammar Review", in: menu)?.keyEquivalent == "q")
    }
}
