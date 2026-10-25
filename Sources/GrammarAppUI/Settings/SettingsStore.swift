import Foundation
import GrammarModels
import Observation
import os

@Observable
public final class SettingsStore {
    public nonisolated static let defaultsKey = "settings.v1"

    public var settings: AppSettings {
        get { storage }
        set { commit(newValue) }
    }

    @ObservationIgnored public var onChange: ((AppSettings) -> Void)?

    private var storage: AppSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var pauseExpiryTask: Task<Void, Never>?

    private nonisolated let box: OSAllocatedUnfairLock<AppSettings>

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, now: { Date() })
    }

    init(defaults: UserDefaults, now: @escaping () -> Date) {
        self.defaults = defaults
        self.now = now
        let initial = SettingsPersistence.normalized(SettingsPersistence.load(from: defaults), now: now())
        storage = initial
        box = OSAllocatedUnfairLock(initialState: initial)
        schedulePauseExpiry()
    }

    public nonisolated var snapshot: AppSettings {
        box.withLock { $0 }
    }

    public func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = storage
        mutate(&copy)
        commit(copy)
    }

    public var isPaused: Bool {
        guard let pausedUntil = settings.pausedUntil else { return false }
        return pausedUntil > now()
    }

    public var isActive: Bool {
        settings.isActive(at: now())
    }

    public func pause(for duration: TimeInterval) {
        let until = now().addingTimeInterval(duration)
        update { $0.pausedUntil = until }
    }

    public func pauseUntilTomorrow() {
        let until = Self.startOfNextDay(after: now(), calendar: .current)
        update { $0.pausedUntil = until }
    }

    public func resume() {
        update {
            $0.pausedUntil = nil
            $0.isEnabled = true
        }
    }

    public func expirePauseIfNeeded() {
        guard let pausedUntil = storage.pausedUntil, pausedUntil <= now() else { return }
        update { $0.pausedUntil = nil }
    }

    public func setApp(_ bundleID: String, disabled: Bool) {
        update {
            if disabled {
                $0.disabledBundleIDs.insert(bundleID)
            } else {
                $0.disabledBundleIDs.remove(bundleID)
            }
        }
    }

    public func restoreDefaultDisabledApps() {
        update { $0.disabledBundleIDs = AppSettings.defaultDisabledBundleIDs }
    }

    public func setGoals(_ goals: WritingGoals, forApp bundleID: String) {
        update { $0.appGoals[bundleID] = goals.isNone ? nil : goals }
    }

    public func addToDictionary(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !storage.isInPersonalDictionary(trimmed) else { return }
        update { _ = $0.personalDictionary.insert(trimmed) }
    }

    public func removeFromDictionary(_ word: String) {
        update { settings in
            settings.personalDictionary = settings.personalDictionary.filter {
                $0.caseInsensitiveCompare(word) != .orderedSame
            }
        }
    }

    nonisolated static func startOfNextDay(after date: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(24 * 60 * 60)
    }

    private func commit(_ newValue: AppSettings) {
        guard newValue != storage else { return }
        let pauseChanged = newValue.pausedUntil != storage.pausedUntil
        storage = newValue
        box.withLock { $0 = newValue }
        SettingsPersistence.save(newValue, to: defaults)
        if pauseChanged {
            schedulePauseExpiry()
        }
        onChange?(newValue)
    }

    private func schedulePauseExpiry() {
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        guard let pausedUntil = storage.pausedUntil else { return }
        let delay = max(pausedUntil.timeIntervalSince(now()), 0)
        pauseExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(250), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.pauseTimerFired()
        }
    }

    private func pauseTimerFired() {
        pauseExpiryTask = nil
        guard let pausedUntil = storage.pausedUntil else { return }
        if pausedUntil <= now() {
            update { $0.pausedUntil = nil }
        } else {
            schedulePauseExpiry()
        }
    }
}
