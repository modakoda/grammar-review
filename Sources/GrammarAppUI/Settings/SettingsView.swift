import AppKit
import GrammarModels
import Observation
import SwiftUI

@Observable
final class SettingsNavigation {
    var selection: SettingsTab = .general
}

struct SettingsView: View {
    static let size = NSSize(width: 700, height: 560)

    @Bindable var store: SettingsStore
    @Bindable var navigation: SettingsNavigation
    let keyModel: APIKeyEditorModel
    let localServer: LocalServerModel
    let cloudServices: CloudServiceModels
    let usage: UsageStore
    let catalog: AppCatalog
    let updater: (any AppUpdater)?

    var body: some View {
        TabView(selection: $navigation.selection) {
            GeneralSettingsTab(store: store, updater: updater)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            AISettingsTab(store: store, keyModel: keyModel, localServer: localServer, cloudServices: cloudServices, usage: usage)
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(SettingsTab.ai)
            LanguageSettingsTab(store: store)
                .tabItem { Label("Languages", systemImage: "globe") }
                .tag(SettingsTab.languages)
            AppsSettingsTab(store: store, catalog: catalog)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.apps)
            GoalsSettingsTab(store: store, catalog: catalog)
                .tabItem { Label("Goals", systemImage: "scope") }
                .tag(SettingsTab.goals)
            StyleGuideSettingsTab(store: store)
                .tabItem { Label("Style Guide", systemImage: "list.bullet.rectangle") }
                .tag(SettingsTab.styleGuide)
            DictionarySettingsTab(store: store)
                .tabItem { Label("Dictionary", systemImage: "character.book.closed") }
                .tag(SettingsTab.dictionary)
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(12)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
