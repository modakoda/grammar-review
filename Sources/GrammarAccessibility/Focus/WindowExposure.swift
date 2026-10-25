import Foundation

nonisolated enum WindowExposure: Equatable, Sendable {
    case exposed
    case hidden
    case unknown

    static func classify(focusedIsApp: Bool, focusedWindowIsApp: Bool?) -> WindowExposure {
        guard focusedIsApp else { return .exposed }
        return switch focusedWindowIsApp {
        case true?: .hidden
        case false?: .exposed
        case nil: .unknown
        }
    }
}

nonisolated struct HiddenWindowsState: Equatable, Sendable {
    static let readingsToChange = 2

    private(set) var isHidden = false
    private var disagreeingReadings = 0

    mutating func record(_ exposure: WindowExposure) -> Bool {
        let hidden: Bool
        switch exposure {
        case .exposed: hidden = false
        case .hidden: hidden = true
        case .unknown: return false
        }
        guard hidden != isHidden else {
            disagreeingReadings = 0
            return false
        }
        disagreeingReadings += 1
        guard disagreeingReadings >= Self.readingsToChange else { return false }
        isHidden = hidden
        disagreeingReadings = 0
        return true
    }

    mutating func reset() -> Bool {
        let wasHidden = isHidden
        self = HiddenWindowsState()
        return wasHidden
    }
}
