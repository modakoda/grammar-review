import Foundation
import GrammarModels
import Observation

@Observable
final class EditorComposer {
    private(set) var session: ComposeSession?
    @ObservationIgnored private let composer: any TextComposing
    @ObservationIgnored private let settings: () -> AppSettings
    @ObservationIgnored private var task: Task<Void, Never>?

    init(composer: any TextComposing, settings: @escaping () -> AppSettings) {
        self.composer = composer
        self.settings = settings
    }

    func start(_ newSession: ComposeSession) {
        task?.cancel()
        session = newSession
    }

    func setUsesText(_ usesText: Bool) {
        guard session?.usesText != usesText else { return }
        session?.usesText = usesText
    }

    func compose(_ request: String, context: String?) {
        guard var current = session else { return }
        task?.cancel()
        current.request = request
        current.result = .loading
        session = current
        let id = current.id
        let settings = settings()
        let composer = composer
        task = Task { [weak self] in
            let result: RewriteResult
            do {
                result = .ready(try await composer.compose(request, context: context, settings: settings))
            } catch is CancellationError {
                return
            } catch {
                result = .failed(AIFailureMessage.message(for: error, feature: "write with AI"))
            }
            guard !Task.isCancelled, let self, self.session?.id == id, self.session?.request == request else { return }
            self.session?.result = result
        }
    }

    func fail(_ message: String) {
        session?.result = .failed(message)
    }

    func end() {
        task?.cancel()
        if session != nil { session = nil }
    }
}
