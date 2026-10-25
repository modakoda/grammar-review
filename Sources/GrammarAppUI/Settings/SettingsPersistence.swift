import Foundation
import GrammarModels
import Observation
import os

nonisolated enum SettingsPersistence {
    static func load(from defaults: UserDefaults) -> AppSettings {
        guard let data = defaults.data(forKey: SettingsStore.defaultsKey) else { return AppSettings() }
        return decode(data)
    }

    static func decode(_ data: Data) -> AppSettings {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            Log.app.error("Saved settings could not be decoded, salvaging what can be read: \(error.localizedDescription, privacy: .public)")
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return AppSettings()
        }
        var usable: [String: Any] = [:]
        for (key, value) in object {
            guard
                let single = try? JSONSerialization.data(withJSONObject: [key: value]),
                (try? decoder.decode(AppSettings.self, from: single)) != nil
            else {
                Log.app.error("Dropping unreadable setting \(key, privacy: .public)")
                continue
            }
            usable[key] = value
        }
        guard
            let merged = try? JSONSerialization.data(withJSONObject: usable),
            let settings = try? decoder.decode(AppSettings.self, from: merged)
        else {
            return AppSettings()
        }
        return settings
    }

    static func encode(_ settings: AppSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(settings)
    }

    static func save(_ settings: AppSettings, to defaults: UserDefaults) {
        do {
            defaults.set(try encode(settings), forKey: SettingsStore.defaultsKey)
        } catch {
            Log.app.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func normalized(_ settings: AppSettings, now: Date) -> AppSettings {
        var settings = settings
        if let pausedUntil = settings.pausedUntil, pausedUntil <= now {
            settings.pausedUntil = nil
        }
        return settings
    }
}
