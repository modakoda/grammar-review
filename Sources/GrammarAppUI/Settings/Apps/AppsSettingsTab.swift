import AppKit
import GrammarModels
import SwiftUI

struct AppsSettingsTab: View {
    @Bindable var store: SettingsStore
    let catalog: AppCatalog
    @ViewState private var selection = Set<String>()
    @ViewState private var runningApps: [AppEntry] = []
    @ViewState private var addError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Grammar Review doesn't read or check text in these apps. Terminals, password managers and code editors are off by default.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(selection: $selection) {
                ForEach(entries) { entry in
                    AppRow(entry: entry, icon: catalog.icon(for: entry))
                        .tag(entry.bundleID)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .onDeleteCommand(perform: removeSelected)

            HStack(spacing: 8) {
                Menu("Add App") {
                    if runningApps.isEmpty {
                        Text("No other apps are running")
                    } else {
                        Section("Running apps") {
                            ForEach(runningApps) { app in
                                Button {
                                    store.setApp(app.bundleID, disabled: true)
                                    refreshRunningApps()
                                } label: {
                                    Label {
                                        Text(app.name)
                                    } icon: {
                                        Image(nsImage: catalog.icon(for: app))
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Choose an App…", action: chooseApps)
                }
                .fixedSize()

                Button("Remove", action: removeSelected)
                    .disabled(selection.isEmpty)

                Spacer()

                Button("Restore Defaults") {
                    store.restoreDefaultDisabledApps()
                    selection = []
                    refreshRunningApps()
                }
            }
            if let addError {
                Text(addError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .onAppear(perform: refreshRunningApps)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            refreshRunningApps()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            refreshRunningApps()
        }
    }

    private var entries: [AppEntry] {
        catalog.entries(for: store.settings.disabledBundleIDs)
    }

    private func refreshRunningApps() {
        runningApps = catalog.runningApps(excluding: store.settings.disabledBundleIDs)
    }

    private func removeSelected() {
        let removed = selection
        store.update { $0.disabledBundleIDs.subtract(removed) }
        selection = []
        refreshRunningApps()
    }

    private func chooseApps() {
        let chosen = AppCatalog.chooseApps()
        addError = chosen.skipped.isEmpty
            ? nil
            : "Couldn't add \(chosen.skipped.joined(separator: ", ")): no bundle identifier."
        guard !chosen.bundleIDs.isEmpty else { return }
        store.update { $0.disabledBundleIDs.formUnion(chosen.bundleIDs) }
        refreshRunningApps()
    }
}

private struct AppRow: View {
    let entry: AppEntry
    let icon: NSImage

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                Text(entry.url == nil ? "\(entry.bundleID) · not installed" : entry.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
