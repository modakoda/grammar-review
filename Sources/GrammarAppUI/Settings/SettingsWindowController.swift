import AppKit
import GrammarModels
import Observation
import SwiftUI

public final class SettingsWindowController {
    private let settingsStore: SettingsStore
    private let navigation = SettingsNavigation()
    private let keyModel: APIKeyEditorModel
    private let localServer: LocalServerModel
    private let cloudServices: CloudServiceModels
    private let harper: HarperModel
    private let webSearchKey: APIKeyEditorModel
    private let catalog = AppCatalog()
    private let usage: UsageStore
    private let updater: (any AppUpdater)?
    private var window: NSWindow?

    public init(
        settingsStore: SettingsStore,
        usage: UsageStore,
        validateAPIKey: @escaping APIKeyValidator,
        localServer: LocalServerClient,
        cloudServices: CloudServiceClient,
        harper: HarperSetupClient,
        validateWebSearchKey: @escaping (_ key: String) async throws -> Void,
        updater: (any AppUpdater)? = nil
    ) {
        self.settingsStore = settingsStore
        self.usage = usage
        self.updater = updater
        keyModel = APIKeyEditorModel(validate: validateAPIKey)
        self.localServer = LocalServerModel(client: localServer)
        self.cloudServices = CloudServiceModels(client: cloudServices)
        self.harper = HarperModel(client: harper)
        webSearchKey = APIKeyEditorModel(
            keyStore: .webSearch,
            success: { _ in "Brave Search accepted the key." },
            validate: { key, _ in try await validateWebSearchKey(key) }
        )
    }

    public func show() {
        show(tab: nil)
    }

    public func show(tab: SettingsTab?) {
        if let tab {
            navigation.selection = tab
        }
        keyModel.refresh()
        webSearchKey.refresh()
        cloudServices.refreshKeys()
        AppWindows.present(window ?? makeWindow())
    }

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            store: settingsStore, navigation: navigation, keyModel: keyModel, localServer: localServer,
            cloudServices: cloudServices, harper: harper, webSearchKey: webSearchKey, usage: usage, catalog: catalog,
            updater: updater
        )
        let window = AppWindows.makeWindow(title: "Grammar Review Settings", contentSize: SettingsView.size, rootView: view)
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        self.window = window
        return window
    }
}
