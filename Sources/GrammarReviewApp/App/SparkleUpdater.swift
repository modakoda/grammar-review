import AppKit
import GrammarAppUI
import GrammarModels
import Sparkle

final class SparkleUpdater: AppUpdater {
    private let controller: SPUStandardUpdaterController
    private let reminders: UpdateReminders

    init?(configuration: UpdaterConfiguration) {
        guard configuration.isEnabled else { return nil }
        let reminders = UpdateReminders()
        self.reminders = reminders
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: reminders)
        do {
            try controller.updater.start()
        } catch {
            Log.app.error("Updates are off: Sparkle didn't start: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var pendingUpdateVersion: String? { reminders.pendingVersion }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }
}

private final class UpdateReminders: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    var pendingVersion: String?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !state.userInitiated {
            pendingVersion = update.displayVersionString
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingVersion = nil
    }
}
