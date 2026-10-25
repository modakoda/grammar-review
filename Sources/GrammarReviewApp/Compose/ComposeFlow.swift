import AppKit
import GrammarAppUI
import GrammarEngine
import GrammarModels

final class ComposeFlow {
    var willStart: () -> Void = {}

    private let composer: any TextComposing
    private let overlay: any SuggestionPresenting
    private let settingsStore: SettingsStore
    private var context: ComposeContext?
    private var task: Task<Void, Never>?

    init(composer: any TextComposing, overlay: any SuggestionPresenting, settingsStore: SettingsStore) {
        self.composer = composer
        self.overlay = overlay
        self.settingsStore = settingsStore
    }

    var isOpen: Bool { context != nil }

    func start(in target: any TextFieldHandle) {
        guard !target.isSecure, let current = target.readText() else {
            NSSound.beep()
            return
        }
        let ns = current as NSString
        let selection = target.selectedRange().flatMap { NSMaxRange($0) <= ns.length ? $0 : nil }
            ?? NSRange(location: ns.length, length: 0)
        willStart()
        task?.cancel()
        let caret = selection.length > 0 ? selection : NSRange(location: max(0, selection.location - 1), length: min(1, ns.length))
        let context = ComposeContext(
            field: target,
            range: selection,
            replaced: ns.substring(with: selection),
            context: ns.replacingCharacters(in: selection, with: ""),
            style: ComposeInsertion.style(for: current),
            anchor: target.anchor(for: caret)
        )
        self.context = context
        overlay.showCompose(context.state())
    }

    func request(_ request: String, usesContext: Bool) {
        guard var context else { return }
        task?.cancel()
        context.request = request
        self.context = context
        overlay.showCompose(context.state(result: .loading))
        let settings = settingsStore.settings
        let background = usesContext ? context.context : nil
        let id = context.id
        task = Task { [weak self, composer] in
            let result: RewriteResult
            do {
                result = .ready(try await composer.compose(request, context: background, settings: settings))
            } catch is CancellationError {
                return
            } catch {
                result = .failed(RewriteGoal.message(for: error, feature: "write with AI"))
            }
            guard !Task.isCancelled, let self, let current = self.context, current.id == id, current.request == request else { return }
            self.overlay.showCompose(current.state(result: result))
        }
    }

    func accept(_ text: String) {
        guard let context else { return }
        task?.cancel()
        self.context = nil
        overlay.showCompose(nil)

        let current = context.field.readText() as NSString?
        guard let current, NSMaxRange(context.range) <= current.length,
              current.substring(with: context.range) == context.replaced
        else {
            NSSound.beep()
            return
        }
        let insertion = ComposeInsertion.text(text, at: context.range, in: current as String, as: context.style)
        if !context.field.replace(context.range, with: insertion) {
            NSSound.beep()
        }
    }

    func close() {
        task?.cancel()
        guard context != nil else { return }
        context = nil
        overlay.showCompose(nil)
    }

    func stop() {
        task?.cancel()
        context = nil
    }
}
