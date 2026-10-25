import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct SettingsStoreTests {
    @Test func startsWithDefaultsWhenNothingIsSaved() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            #expect(store.settings == AppSettings())
            #expect(store.snapshot == AppSettings())
        }
    }

    @Test func roundTripsThroughUserDefaults() async {
        await withTemporaryDefaults { defaults in
            let clock = TestClock()
            let store = SettingsStore(defaults: defaults, now: { clock.now })
            store.update {
                $0.isEnabled = false
                $0.pausedUntil = clock.now.addingTimeInterval(3600)
                $0.aiEnabled = false
                $0.aiProvider = .cloud("openai")
                $0.cloudModels = ["openai": "gpt-5", "xai": "grok-4"]
                $0.aiModel = "claude-opus-5-5"
                $0.localServerURL = "http://localhost:11434/v1"
                $0.localModel = "qwen3:30b-a3b"
                $0.aiDelay = 2.25
                $0.maxAICharacters = 12_000
                $0.languageMode = .fixed("lt")
                $0.enabledCategories = [.spelling, .style]
                $0.disabledBundleIDs = ["com.example.app"]
                $0.personalDictionary = ["Kažinauskas", "SwiftUI"]
                $0.styleGuide = [StyleRule(term: "utilize", replacement: "use", note: "Plain words.", matchCase: true)]
                $0.harperEnabled = false
                $0.harperPath = "~/bin/harper-ls"
                $0.showBadge = false
                $0.inputBadgePlacement = .below
                $0.textAreaBadgePlacement = .insideTopLeft
                $0.badgeSpacing = 12
                $0.editorGoals = WritingGoals(style: .formal, audience: .expert)
                $0.appGoals = ["com.apple.mail": WritingGoals(style: .professional, domain: .email)]
                $0.launchAtLogin = true
                $0.hasCompletedOnboarding = true
            }

            let reloaded = SettingsStore(defaults: defaults, now: { clock.now })
            #expect(reloaded.settings == store.settings)
            #expect(reloaded.settings.languageMode == .fixed("lt"))
            #expect(reloaded.settings.personalDictionary.contains("Kažinauskas"))
            #expect(reloaded.settings.badgePlacement(for: .input) == .below)
            #expect(reloaded.settings.badgePlacement(for: .textArea) == .insideTopLeft)
            #expect(reloaded.settings.badgeSpacing == 12)
            #expect(reloaded.settings.goals(forApp: "com.apple.mail").domain == .email)
            #expect(reloaded.settings.aiProvider == .cloud("openai"))
            #expect(reloaded.settings.cloudModel(for: .openAI) == "gpt-5")
            #expect(reloaded.settings.cloudModel(for: .gemini) == CloudService.gemini.defaultModel)
        }
    }

    @Test func cloudProvidersAreSavedByTheirID() async throws {
        try await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.update { $0.aiProvider = .cloud("mistral") }
            let data = try #require(defaults.data(forKey: SettingsStore.defaultsKey))
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["aiProvider"] as? String == "mistral")
        }
    }

    @Test func theEditorStyleSavedBeforeGoalsBecomesTheEditorsGoals() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"editorStyle": "confident"}"#.utf8), forKey: SettingsStore.defaultsKey)
            let store = SettingsStore(defaults: defaults)
            #expect(store.settings.editorGoals == WritingGoals(style: .confident))
            #expect(store.settings.appGoals.isEmpty)
        }
    }

    @Test func goalsWithUnknownValuesKeepTheRest() async {
        await withTemporaryDefaults { defaults in
            let json = #"{"editorGoals": {"style": "formal", "audience": "aliens"}, "appGoals": {"com.tinyspeck.slackmacgap": {"domain": "casual"}}}"#
            defaults.set(Data(json.utf8), forKey: SettingsStore.defaultsKey)
            let store = SettingsStore(defaults: defaults)
            #expect(store.settings.editorGoals == WritingGoals(style: .formal))
            #expect(store.settings.goals(forApp: "com.tinyspeck.slackmacgap") == WritingGoals(domain: .casual))
            #expect(store.settings.goals(forApp: "com.apple.mail") == .none)
            #expect(store.settings.goals(forApp: nil) == .none)
        }
    }

    @Test func settingAppGoalsToNoneRemovesTheProfile() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.setGoals(WritingGoals(style: .friendly), forApp: "com.apple.MobileSMS")
            #expect(store.settings.appGoals == ["com.apple.MobileSMS": WritingGoals(style: .friendly)])
            store.setGoals(.none, forApp: "com.apple.MobileSMS")
            #expect(store.settings.appGoals.isEmpty)
        }
    }

    @Test func savesJSONUnderVersionedKey() async throws {
        try await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.settings.showBadge = false

            let data = try #require(defaults.data(forKey: "settings.v1"))
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["showBadge"] as? Bool == false)
            #expect(try JSONDecoder().decode(AppSettings.self, from: data) == store.settings)
        }
    }

    @Test func loadsPartialJSONWithDefaultsForMissingKeys() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"aiEnabled": false, "aiModel": "claude-sonnet-5-5"}"#.utf8), forKey: SettingsStore.defaultsKey)
            let store = SettingsStore(defaults: defaults)

            var expected = AppSettings()
            expected.aiEnabled = false
            expected.aiModel = "claude-sonnet-5-5"
            #expect(store.settings == expected)
            #expect(store.settings.aiProvider == .claude)
            #expect(store.settings.localServerURL == "http://localhost:1234/v1")
            #expect(store.settings.localModel.isEmpty)
        }
    }

    @Test func unknownProviderFallsBackToClaudeAndKeepsTheRest() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"aiProvider": "quantum", "localModel": "gemma-3-27b", "showBadge": false}"#.utf8), forKey: SettingsStore.defaultsKey)
            let settings = SettingsStore(defaults: defaults).settings
            #expect(settings.aiProvider == .claude)
            #expect(settings.localModel == "gemma-3-27b")
            #expect(settings.showBadge == false)
        }
    }

    @Test func keepsTheBadgeSpacingInRange() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"badgeSpacing": 0}"#.utf8), forKey: SettingsStore.defaultsKey)
            #expect(SettingsStore(defaults: defaults).settings.badgeSpacing == AppSettings.badgeSpacingRange.lowerBound)
            defaults.set(Data(#"{"badgeSpacing": 500}"#.utf8), forKey: SettingsStore.defaultsKey)
            #expect(SettingsStore(defaults: defaults).settings.badgeSpacing == AppSettings.badgeSpacingRange.upperBound)
        }
    }

    @Test func readsTheBadgePlacementSavedBeforeThereWereCorners() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"badgePlacement": "inside"}"#.utf8), forKey: SettingsStore.defaultsKey)
            let settings = SettingsStore(defaults: defaults).settings
            #expect(settings.badgePlacement(for: .input) == .insideBottomRight)
            #expect(settings.badgePlacement(for: .textArea) == .insideBottomRight)
        }
    }

    @Test func readsTheOneBadgePlacementSavedBeforeEachKindOfFieldHadItsOwn() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data(#"{"badgePlacement": "right", "textAreaBadgePlacement": "below"}"#.utf8), forKey: SettingsStore.defaultsKey)
            let settings = SettingsStore(defaults: defaults).settings
            #expect(settings.badgePlacement(for: .input) == .right)
            #expect(settings.badgePlacement(for: .textArea) == .below)
        }
    }

    @Test func tellsBadgeOnlyChangesFromTheRest() {
        let settings = AppSettings()
        var moved = settings
        moved.setBadgePlacement(.right, for: .input)
        moved.badgeSpacing = 20
        moved.showBadge = false
        #expect(moved.differsOnlyInBadge(from: settings))
        var recategorised = moved
        recategorised.enabledCategories = [.spelling]
        #expect(!recategorised.differsOnlyInBadge(from: settings))
    }

    @Test func corruptDataFallsBackToDefaults() async {
        await withTemporaryDefaults { defaults in
            defaults.set(Data("not json at all".utf8), forKey: SettingsStore.defaultsKey)
            #expect(SettingsStore(defaults: defaults).settings == AppSettings())

            defaults.set(Data("[1, 2, 3]".utf8), forKey: SettingsStore.defaultsKey)
            #expect(SettingsStore(defaults: defaults).settings == AppSettings())
        }
    }

    @Test func dropsOnlyTheKeysThatCannotBeRead() async {
        await withTemporaryDefaults { defaults in
            let json = #"{"aiEnabled": false, "aiDelay": "slow", "enabledCategories": ["spelling", "tone"], "showBadge": false}"#
            defaults.set(Data(json.utf8), forKey: SettingsStore.defaultsKey)
            let store = SettingsStore(defaults: defaults)

            #expect(store.settings.aiEnabled == false)
            #expect(store.settings.showBadge == false)
            #expect(store.settings.aiDelay == AppSettings().aiDelay)
            #expect(store.settings.enabledCategories == AppSettings().enabledCategories)
        }
    }

    @Test func snapshotMatchesAfterMutation() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.settings.aiModel = "claude-opus-5-5"
            store.addToDictionary("Vilnius")
            #expect(store.snapshot == store.settings)

            let fromBackground = await Task.detached { store.snapshot }.value
            #expect(fromBackground.aiModel == "claude-opus-5-5")
            #expect(fromBackground.personalDictionary == ["Vilnius"])
        }
    }

    @Test func onChangeFiresOncePerRealChange() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            var received: [AppSettings] = []
            store.onChange = { received.append($0) }

            store.settings.isEnabled = true
            store.settings = store.settings
            store.update { _ in }
            store.setApp("com.apple.Terminal", disabled: true)
            #expect(received.isEmpty)

            store.settings.aiEnabled = false
            #expect(received.count == 1)
            #expect(received.last?.aiEnabled == false)

            store.update {
                $0.showBadge = false
                $0.aiDelay = 2
                $0.maxAICharacters = 1000
            }
            #expect(received.count == 2)
            #expect(received.last == store.settings)
        }
    }

    @Test func noOpWritesAreNotPersisted() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.settings.isEnabled = true
            #expect(defaults.data(forKey: SettingsStore.defaultsKey) == nil)
        }
    }

    @Test func pauseForDuration() async {
        await withTemporaryDefaults { defaults in
            let clock = TestClock()
            let store = SettingsStore(defaults: defaults, now: { clock.now })
            var changes = 0
            store.onChange = { _ in changes += 1 }

            store.pause(for: 30 * 60)
            #expect(store.settings.pausedUntil == clock.now.addingTimeInterval(30 * 60))
            #expect(store.isPaused)
            #expect(!store.isActive)
            #expect(store.snapshot.isActive(at: clock.now) == false)
            #expect(changes == 1)
        }
    }

    @Test func pauseUntilTomorrowEndsAtTheNextMidnight() async throws {
        try await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.pauseUntilTomorrow()

            let until = try #require(store.settings.pausedUntil)
            let calendar = Calendar.current
            #expect(until > Date())
            #expect(until.timeIntervalSinceNow <= 25 * 60 * 60)
            #expect(calendar.startOfDay(for: until) == until)
            #expect(!calendar.isDateInToday(until))
        }
    }

    @Test func startOfNextDayAcrossDaylightSavingChange() {
        let calendar = Calendar.fixed("Europe/Vilnius")
        let evening = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 22, minute: 15))!
        let next = SettingsStore.startOfNextDay(after: evening, calendar: calendar)
        #expect(next == calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!)

        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 23, minute: 59))!
        #expect(SettingsStore.startOfNextDay(after: lateNight, calendar: calendar)
            == calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!)
    }

    @Test func resumeClearsThePauseAndTurnsCheckingOn() async {
        await withTemporaryDefaults { defaults in
            let clock = TestClock()
            let store = SettingsStore(defaults: defaults, now: { clock.now })
            store.update {
                $0.isEnabled = false
                $0.pausedUntil = clock.now.addingTimeInterval(600)
            }
            var changes = 0
            store.onChange = { _ in changes += 1 }

            store.resume()
            #expect(store.settings.pausedUntil == nil)
            #expect(store.settings.isEnabled)
            #expect(store.isActive)
            #expect(changes == 1)

            store.resume()
            #expect(changes == 1)
        }
    }

    @Test func expirePauseIfNeededUsesTheClock() async {
        await withTemporaryDefaults { defaults in
            let clock = TestClock()
            let store = SettingsStore(defaults: defaults, now: { clock.now })
            store.pause(for: 60)
            var changes = 0
            store.onChange = { _ in changes += 1 }

            clock.advance(by: 59)
            store.expirePauseIfNeeded()
            #expect(store.settings.pausedUntil != nil)
            #expect(changes == 0)

            clock.advance(by: 1)
            #expect(!store.isPaused)
            store.expirePauseIfNeeded()
            #expect(store.settings.pausedUntil == nil)
            #expect(changes == 1)
        }
    }

    @Test func expiredPauseIsClearedOnLoad() async {
        await withTemporaryDefaults { defaults in
            let clock = TestClock()
            let first = SettingsStore(defaults: defaults, now: { clock.now })
            first.pause(for: 60)

            clock.advance(by: 120)
            let reloaded = SettingsStore(defaults: defaults, now: { clock.now })
            #expect(reloaded.settings.pausedUntil == nil)
            #expect(reloaded.snapshot.pausedUntil == nil)
        }
    }

    @Test func pauseTimerClearsThePauseWhenItEnds() async throws {
        try await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            var received: [AppSettings] = []
            store.onChange = { received.append($0) }

            store.pause(for: 0.2)
            #expect(store.isPaused)

            for _ in 0..<60 where store.settings.pausedUntil != nil {
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(store.settings.pausedUntil == nil)
            #expect(store.snapshot.pausedUntil == nil)
            #expect(received.count == 2)
            #expect(received.last?.pausedUntil == nil)
        }
    }

    @Test func resumingCancelsThePauseTimer() async throws {
        try await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.pause(for: 0.1)
            store.resume()
            var changes = 0
            store.onChange = { _ in changes += 1 }

            try await Task.sleep(for: .milliseconds(500))
            #expect(changes == 0)
        }
    }

    @Test func disablingAndEnablingApps() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.setApp("com.apple.Notes", disabled: true)
            #expect(!store.settings.allowsApp("com.apple.Notes"))

            store.setApp("com.apple.Notes", disabled: false)
            store.setApp("com.apple.Terminal", disabled: false)
            #expect(store.settings.allowsApp("com.apple.Notes"))
            #expect(store.settings.allowsApp("com.apple.Terminal"))

            store.restoreDefaultDisabledApps()
            #expect(store.settings.disabledBundleIDs == AppSettings.defaultDisabledBundleIDs)
        }
    }

    @Test func personalDictionaryHelpers() async {
        await withTemporaryDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            var changes = 0
            store.onChange = { _ in changes += 1 }

            store.addToDictionary("  Kubernetes \n")
            store.addToDictionary("kubernetes")
            store.addToDictionary("   ")
            #expect(store.settings.personalDictionary == ["Kubernetes"])
            #expect(changes == 1)

            store.addToDictionary("Vilnius")
            store.removeFromDictionary("KUBERNETES")
            #expect(store.settings.personalDictionary == ["Vilnius"])
            #expect(changes == 3)
        }
    }
}
