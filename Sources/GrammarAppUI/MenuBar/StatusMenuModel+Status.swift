import Foundation
import GrammarModels

extension StatusMenuModel {
    static func effectiveStatus(reported: MenuBarStatus, settings: AppSettings, now: Date) -> MenuBarStatus {
        if reported == .needsPermission { return .needsPermission }
        if !settings.isActive(at: now) { return .paused }
        switch reported {
        case .paused:
            return .active
        case .aiUnavailable where !settings.aiEnabled:
            return .active
        default:
            return reported
        }
    }

    static func symbolName(for status: MenuBarStatus) -> String {
        switch status {
        case .active: "text.badge.checkmark"
        case .paused: "pause.circle"
        case .disabledForApp: "text.badge.minus"
        case .needsPermission, .windowsHidden: "exclamationmark.triangle"
        case .aiUnavailable: "text.badge.xmark"
        }
    }

    static func statusLine(
        for status: MenuBarStatus,
        settings: AppSettings,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        switch status {
        case .active:
            return "Checking is on"
        case .paused:
            guard settings.isEnabled else { return "Checking is off" }
            guard let until = settings.pausedUntil, until > now else { return "Paused" }
            return "Paused until \(pauseEndDescription(until, now: now, calendar: calendar, locale: locale))"
        case let .disabledForApp(app):
            return "Checking is off in \(app)"
        case .needsPermission:
            return "Accessibility permission needed — Grant…"
        case .windowsHidden:
            return "macOS is hiding text fields — log out or restart"
        case let .aiUnavailable(reason):
            return "AI unavailable: \(reason)"
        }
    }

    static func tooltip(
        for status: MenuBarStatus,
        settings: AppSettings,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let line = statusLine(for: status, settings: settings, now: now, calendar: calendar, locale: locale)
        let cleaned = status == .needsPermission ? "Accessibility permission needed" : line
        return "Grammar Review — \(cleaned)"
    }

    static func pauseEndDescription(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if date == SettingsStore.startOfNextDay(after: now, calendar: calendar) {
            return "tomorrow"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.setLocalizedDateFormatFromTemplate("jmm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEEjmm")
        }
        return formatter.string(from: date)
    }
}
