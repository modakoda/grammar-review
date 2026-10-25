import AppKit
import GrammarAccessibility
import GrammarAppUI
import GrammarEditor
import GrammarEngine
import GrammarModels
import GrammarOverlay

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let usage = UsageStore()
    private let engine = HybridGrammarEngine(apiKeys: { KeychainStore.apiKey(for: $0) })
    private let editorEngine = HybridGrammarEngine(apiKeys: { KeychainStore.apiKey(for: $0) })
    private let plagiarism = PlagiarismChecker(apiKey: { KeychainStore.webSearchAPIKey() })
    private let tracker = AccessibilityFocusTracker()
    private let overlay = OverlayController()
    private let hotkeys = HotkeyManager()

    private var coordinator: AppCoordinator?
    private var updater: SparkleUpdater?
    private var statusBar: StatusBarController?
    private var settingsWindow: SettingsWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var editorWindow: EditorWindowController?
    private var keyboardObserver: (any NSObjectProtocol)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let updater = SparkleUpdater(configuration: .current)
        self.updater = updater
        MainMenu.install(openSettings: { [weak self] in self?.showSettings() }, updater: updater)
        for checker in [engine, editorEngine] {
            checker.setUsageHandler { [usage] event in
                Task { @MainActor in usage.record(event) }
            }
        }

        let coordinator = AppCoordinator(
            settingsStore: settingsStore,
            engine: engine,
            rewriter: engine,
            composer: engine,
            toneDetector: engine,
            tracker: tracker,
            overlay: overlay
        )
        self.coordinator = coordinator

        let statusBar = StatusBarController(
            settingsStore: settingsStore,
            actions: StatusBarActions(
                openSettings: { [weak self] in self?.showSettings(tab: $0) },
                showOnboarding: { [weak self] in self?.showOnboarding() },
                rewriteSelection: { [weak coordinator] in coordinator?.rewriteSelection() },
                writeWithAI: { [weak coordinator] in coordinator?.writeWithAI() },
                showSuggestions: { [weak coordinator] in coordinator?.toggleSuggestions() },
                openEditor: { [weak self] in self?.showEditor() },
                quit: { NSApp.terminate(nil) }
            ),
            updater: updater
        )
        self.statusBar = statusBar

        coordinator.onStatusChange = { [weak statusBar] in statusBar?.setStatus($0) }
        coordinator.onOpenSettings = { [weak self] in self?.showSettings(tab: $0) }
        settingsStore.onChange = { [weak self, weak coordinator] settings in
            coordinator?.settingsDidChange(settings)
            self?.editorWindow?.settingsDidChange()
        }

        keyboardObserver = DistributedNotificationCenter.default().addObserver(
            forName: KeyboardLanguages.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.keyboardLayoutDidChange() }
        }

        hotkeys.register(.showSuggestions) { [weak coordinator] in coordinator?.toggleSuggestions() }
        hotkeys.register(.rewriteSelection) { [weak coordinator] in coordinator?.rewriteSelection() }
        hotkeys.register(.writeWithAI) { [weak coordinator] in coordinator?.writeWithAI() }
        hotkeys.register(.openEditor) { [weak self] in self?.showEditor() }

        coordinator.start()

        if !settingsStore.settings.hasCompletedOnboarding || !AccessibilityPermission.isTrusted {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.unregisterAll()
        tracker.stop()
    }

    private func keyboardLayoutDidChange() {
        if case .fixed = settingsStore.settings.languageMode { return }
        coordinator?.keyboardLayoutDidChange()
        editorWindow?.settingsDidChange()
    }

    private func showSettings(tab: SettingsTab? = nil) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                settingsStore: settingsStore,
                usage: usage,
                validateAPIKey: validateAPIKey,
                localServer: LocalServerClient(
                    listModels: { [engine] address in try await engine.localModels(at: address) },
                    testModel: { [engine] address, model in try await engine.testLocalModel(at: address, model: model) }
                ),
                cloudServices: CloudServiceClient(
                    validateKey: { [engine] service, key, model in try await engine.validateAPIKey(key, service: service, model: model) },
                    listModels: { [engine] service, key in try await engine.cloudModels(for: service, apiKey: key) },
                    testModel: { [engine] service, model, key in try await engine.testCloudModel(model, service: service, apiKey: key) }
                ),
                harper: HarperSetupClient(installation: { [engine] path in await engine.harperInstallation(customPath: path) }),
                validateWebSearchKey: { [plagiarism] key in try await plagiarism.validateKey(key) },
                updater: updater
            )
        }
        settingsWindow?.show(tab: tab)
    }

    private func showEditor() {
        if editorWindow == nil {
            editorWindow = EditorWindowController(services: EditorServices(
                checker: editorEngine,
                rewriter: editorEngine,
                toneDetector: editorEngine,
                composer: editorEngine,
                plagiarism: plagiarism,
                settings: { [settingsStore] in settingsStore.settings },
                saveGoals: { [settingsStore] goals in settingsStore.update { $0.editorGoals = goals } },
                addToDictionary: { [settingsStore] word in settingsStore.addToDictionary(word) },
                openSettings: { [weak self] in self?.showSettings(tab: .ai) },
                openPlagiarismSettings: { [weak self] in self?.showSettings(tab: .plagiarism) }
            ))
        }
        editorWindow?.show()
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(
                settingsStore: settingsStore,
                validateAPIKey: validateAPIKey,
                onFinish: { [weak self] in self?.onboardingWindow = nil }
            )
        }
        onboardingWindow?.show()
    }

    private var validateAPIKey: APIKeyValidator {
        { [engine] key, model in try await engine.validateAPIKey(key, model: model) }
    }
}
