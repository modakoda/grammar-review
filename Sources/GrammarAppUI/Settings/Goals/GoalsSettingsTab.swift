import AppKit
import GrammarModels
import SwiftUI

struct GoalsSettingsTab: View {
    @Bindable var store: SettingsStore
    let catalog: AppCatalog
    @ViewState private var runningApps: [AppEntry] = []
    @ViewState private var addError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI suggestions in these apps also aim for the goals you set: how the text should sound, who reads it, what kind of writing it is and what it's for. Other apps get mistakes and clear improvements only.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach(entries) { entry in
                    GoalsRow(
                        entry: entry,
                        icon: catalog.icon(for: entry),
                        goals: goalsBinding(entry.bundleID),
                        remove: { store.setGoals(.none, forApp: entry.bundleID) }
                    )
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .overlay {
                if entries.isEmpty {
                    Text("No app has writing goals yet")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Menu("Add App") {
                    if runningApps.isEmpty {
                        Text("No other apps are running")
                    } else {
                        Section("Running apps") {
                            ForEach(runningApps) { app in
                                Button {
                                    add([app.bundleID])
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
                Spacer()
                Text("Tip: set goals for the app you're in from the menu bar icon.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let addError {
                Text(addError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .onAppear(perform: refreshRunningApps)
    }

    private var entries: [AppEntry] {
        catalog.entries(for: Set(store.settings.appGoals.keys))
    }

    private func goalsBinding(_ bundleID: String) -> Binding<WritingGoals> {
        Binding(
            get: { store.settings.appGoals[bundleID] ?? .none },
            set: { goals in store.update { $0.appGoals[bundleID] = goals } }
        )
    }

    private func add(_ bundleIDs: [String]) {
        store.update { settings in
            for bundleID in bundleIDs where settings.appGoals[bundleID] == nil {
                settings.appGoals[bundleID] = WritingGoals.none
            }
        }
        refreshRunningApps()
    }

    private func refreshRunningApps() {
        runningApps = catalog.runningApps(excluding: Set(store.settings.appGoals.keys).union(store.settings.disabledBundleIDs))
    }

    private func chooseApps() {
        let chosen = AppCatalog.chooseApps()
        addError = chosen.skipped.isEmpty
            ? nil
            : "Couldn't add \(chosen.skipped.joined(separator: ", ")): no bundle identifier."
        add(chosen.bundleIDs)
    }
}

private struct GoalsRow: View {
    let entry: AppEntry
    let icon: NSImage
    @Binding var goals: WritingGoals
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(entry.name)
                    .fontWeight(.medium)
                Spacer()
                Button("Remove", action: remove)
                    .buttonStyle(.link)
            }
            HStack(spacing: 8) {
                picker("Style", \.style, WritingStyle.allCases) { $0.displayName }
                picker("Audience", \.audience, WritingAudience.allCases) { $0.displayName }
                picker("Domain", \.domain, WritingDomain.allCases) { $0.displayName }
                picker("Intent", \.intent, WritingIntent.allCases) { $0.displayName }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func picker<Value: Hashable>(
        _ title: String,
        _ keyPath: WritableKeyPath<WritingGoals, Value>,
        _ values: [Value],
        name: @escaping (Value) -> String
    ) -> some View {
        Picker(title, selection: $goals[dynamicMember: keyPath]) {
            ForEach(values, id: \.self) { value in
                Text(name(value)).tag(value)
            }
        }
        .fixedSize()
    }
}
