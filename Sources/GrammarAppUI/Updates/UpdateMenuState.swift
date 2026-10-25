import Foundation

enum UpdateMenuState: Equatable {
    case unavailable
    case checking
    case ready
    case updateAvailable(String)

    init(updater: (any AppUpdater)?) {
        guard let updater else {
            self = .unavailable
            return
        }
        if let version = updater.pendingUpdateVersion {
            self = .updateAvailable(version)
        } else {
            self = updater.canCheckForUpdates ? .ready : .checking
        }
    }
}
