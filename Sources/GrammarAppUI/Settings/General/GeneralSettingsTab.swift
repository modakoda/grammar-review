import AppKit
import GrammarModels
import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var store: SettingsStore
    let updater: (any AppUpdater)?
    @ViewState private var loginError: String?
    @ViewState private var loginNeedsApproval = false
    @ViewState private var checksForUpdates = false

    var body: some View {
        Form {
            Section {
                Toggle("Check spelling and grammar as you type", isOn: $store.settings.isEnabled)
                if store.settings.isEnabled, store.isPaused, let until = store.settings.pausedUntil {
                    LabeledContent("Paused until \(until.formatted(date: .abbreviated, time: .shortened))") {
                        Button("Resume") { store.resume() }
                    }
                }
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                if loginNeedsApproval {
                    LabeledContent("Allow Grammar Review under Login Items in System Settings.") {
                        Button("Open Login Items") { LaunchAtLogin.openLoginItemsSettings() }
                    }
                    .font(.callout)
                }
            }

            if let updater {
                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: checksForUpdatesBinding(updater))
                    LabeledContent(AppVersion.current) {
                        Button("Check Now") { updater.checkForUpdates() }
                    }
                }
            }

            BadgeSettingsSection(store: store)
            SuggestionTypesSection(store: store)
        }
        .formStyle(.grouped)
        .onAppear {
            syncLaunchAtLogin()
            checksForUpdates = updater?.automaticallyChecksForUpdates ?? false
        }
    }

    private func checksForUpdatesBinding(_ updater: any AppUpdater) -> Binding<Bool> {
        Binding(
            get: { checksForUpdates },
            set: { enabled in
                updater.automaticallyChecksForUpdates = enabled
                checksForUpdates = enabled
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.settings.launchAtLogin },
            set: { enabled in
                do {
                    try LaunchAtLogin.setEnabled(enabled)
                    loginError = nil
                    store.settings.launchAtLogin = enabled
                } catch {
                    loginError = error.localizedDescription
                }
                loginNeedsApproval = LaunchAtLogin.needsApproval
            }
        )
    }

    private func syncLaunchAtLogin() {
        if let enabled = LaunchAtLogin.isEnabled, enabled != store.settings.launchAtLogin {
            store.settings.launchAtLogin = enabled
        }
        loginNeedsApproval = LaunchAtLogin.needsApproval
    }
}
