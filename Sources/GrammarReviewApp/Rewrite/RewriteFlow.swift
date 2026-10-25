import AppKit
import GrammarAppUI
import GrammarEngine
import GrammarModels

final class RewriteFlow {
    var willStart: () -> Void = {}

    private let rewriter: any TextRewriting
    private let overlay: any SuggestionPresenting
    private let settingsStore: SettingsStore
    private var context: RewriteContext?
    private var task: Task<Void, Never>?

    init(rewriter: any TextRewriting, overlay: any SuggestionPresenting, settingsStore: SettingsStore) {
        self.rewriter = rewriter
        self.overlay = overlay
        self.settingsStore = settingsStore
    }

    var isOpen: Bool { context != nil }

    func rewriteSelection(in target: any TextFieldHandle) {
        guard !target.isSecure,
              let selection = target.selectedRange(),
              let current = target.readText(),
              NSMaxRange(selection) <= (current as NSString).length
        else {
            NSSound.beep()
            return
        }
        if selection.length > 0 {
            start(of: selection, in: target, text: current, scope: .selection, goal: .tone(.improve))
        } else {
            rephraseSentence(around: selection, in: target, text: current)
        }
    }

    func rewrite(_ scope: RewriteScope, tone: RewriteTone, in field: any TextFieldHandle) {
        guard !field.isSecure, let current = field.readText() else {
            NSSound.beep()
            return
        }
        let length = (current as NSString).length
        guard scope == .sentence else {
            guard let all = SentenceLocator.trimmed(NSRange(location: 0, length: length), in: current) else {
                NSSound.beep()
                return
            }
            start(of: all, in: field, text: current, scope: .wholeText, goal: .tone(tone))
            return
        }
        let selection = field.selectedRange().flatMap { NSMaxRange($0) <= length ? $0 : nil }
        rephraseSentence(around: selection ?? NSRange(location: length, length: 0), in: field, text: current, tone: tone)
    }

    func rephraseSentence(around range: NSRange, in target: any TextFieldHandle, text current: String, tone: RewriteTone = .rephrase) {
        guard let sentence = SentenceLocator.sentence(around: range, in: current) else {
            NSSound.beep()
            return
        }
        start(of: sentence, in: target, text: current, scope: .sentence, goal: .tone(tone))
    }

    func request(_ goal: RewriteGoal) {
        guard let context else { return }
        task?.cancel()
        overlay.showRewrite(context.state(goal, result: .loading))

        let settings = settingsStore.settings
        let original = context.original
        task = Task { [weak self, rewriter] in
            let result: RewriteResult
            do {
                let rewritten = switch goal {
                case .tone(let tone): try await rewriter.rewrite(original, tone: tone, settings: settings)
                case .instruction(let instruction): try await rewriter.rewrite(original, instruction: instruction, settings: settings)
                }
                result = .ready(rewritten)
            } catch is CancellationError {
                return
            } catch {
                result = .failed(RewriteGoal.message(for: error))
            }
            guard !Task.isCancelled, let self, let current = self.context, current.id == context.id else { return }
            self.overlay.showRewrite(current.state(goal, result: result))
        }
    }

    func accept(_ text: String) {
        guard let context else { return }
        task?.cancel()
        self.context = nil
        overlay.showRewrite(nil)

        let current = context.field.readText() as NSString?
        guard let current, NSMaxRange(context.range) <= current.length,
              current.substring(with: context.range) == context.original,
              context.field.replace(context.range, with: text)
        else {
            NSSound.beep()
            return
        }
    }

    func cancel() {
        task?.cancel()
        context = nil
        overlay.showRewrite(nil)
    }

    func close() {
        task?.cancel()
        guard context != nil else { return }
        context = nil
        overlay.showRewrite(nil)
    }

    func stop() {
        task?.cancel()
        context = nil
    }

    private func start(of range: NSRange, in target: any TextFieldHandle, text current: String, scope: RewriteScope, goal: RewriteGoal) {
        willStart()
        context = RewriteContext(
            field: target,
            range: range,
            original: (current as NSString).substring(with: range),
            scope: scope,
            anchor: target.anchor(for: range)
        )
        request(goal)
    }
}
