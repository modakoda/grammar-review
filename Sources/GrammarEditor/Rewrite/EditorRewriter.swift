import Foundation
import GrammarModels
import Observation

@Observable
final class EditorRewriter {
    private(set) var session: RewriteSession?
    @ObservationIgnored private let rewriter: any TextRewriting
    @ObservationIgnored private let settings: () -> AppSettings
    @ObservationIgnored private var task: Task<Void, Never>?

    init(rewriter: any TextRewriting, settings: @escaping () -> AppSettings) {
        self.rewriter = rewriter
        self.settings = settings
    }

    func start(_ newSession: RewriteSession) {
        task?.cancel()
        session = newSession
        request()
    }

    func change(to goal: RewriteGoal) {
        guard var current = session, current.goal != goal || current.result != .loading else { return }
        current.goal = goal
        current.result = nil
        session = current
        request()
    }

    func fail(_ message: String) {
        session?.result = .failed(message)
    }

    func end() {
        task?.cancel()
        session = nil
    }

    private func request() {
        guard let session else { return }
        task?.cancel()
        if case .instruction(let instruction) = session.goal, instruction.isEmpty { return }
        self.session?.result = .loading
        let settings = settings()
        let rewriter = rewriter
        task = Task { [weak self] in
            let result: RewriteResult
            do {
                let rewritten = switch session.goal {
                case .tone(let tone): try await rewriter.rewrite(session.original, tone: tone, settings: settings)
                case .instruction(let instruction): try await rewriter.rewrite(session.original, instruction: instruction, settings: settings)
                }
                result = .ready(rewritten)
            } catch is CancellationError {
                return
            } catch {
                result = .failed(AIFailureMessage.message(for: error))
            }
            guard !Task.isCancelled, let self, self.session?.id == session.id, self.session?.goal == session.goal else { return }
            self.session?.result = result
        }
    }
}
