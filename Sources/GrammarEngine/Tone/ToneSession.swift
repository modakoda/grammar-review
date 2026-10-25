import Foundation
import GrammarModels

@MainActor
public final class ToneSession {
    public enum State: Equatable, Sendable {
        case unavailable(String)
        case ready(ToneReport)
        case failed(String, offersSettings: Bool)
    }

    public static let minimumWords = 6
    public static let needsTextMessage = "Write a sentence or two to see how your text sounds."
    public static let aiOffMessage = "Turn on AI suggestions in Settings to see how your text sounds."
    public static let tooLongMessage = "This text is longer than the AI limit in Settings, so its tone isn't detected."

    public private(set) var state: State = .unavailable(ToneSession.needsTextMessage)
    public private(set) var isDetecting = false
    public var onChange: (() -> Void)?

    private let detector: any ToneDetecting
    private var detectedText: String?
    private var task: Task<Void, Never>?

    public init(detector: any ToneDetecting) {
        self.detector = detector
    }

    public func update(text: String, settings: AppSettings, after delay: Duration = .zero) {
        guard TextStatistics.wordCount(text) >= Self.minimumWords else {
            settle(.unavailable(Self.needsTextMessage))
            return
        }
        guard settings.aiEnabled else {
            settle(.unavailable(Self.aiOffMessage))
            return
        }
        guard text.utf16.count <= settings.maxAICharacters else {
            settle(.unavailable(Self.tooLongMessage))
            return
        }
        guard detectedText != text else { return }
        task?.cancel()
        detectedText = text
        isDetecting = true
        onChange?()
        let detector = detector
        task = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            let state: State
            do {
                state = .ready(try await detector.detectTone(text, settings: settings))
            } catch is CancellationError {
                return
            } catch {
                state = Self.failure(error)
            }
            guard !Task.isCancelled, let self, self.detectedText == text else { return }
            if case .failed = state { self.detectedText = nil }
            self.state = state
            self.isDetecting = false
            self.onChange?()
        }
    }

    public func invalidate() {
        task?.cancel()
        detectedText = nil
        if isDetecting {
            isDetecting = false
            onChange?()
        }
    }

    public func reset() {
        settle(.unavailable(Self.needsTextMessage))
    }

    private func settle(_ newState: State) {
        task?.cancel()
        detectedText = nil
        guard state != newState || isDetecting else { return }
        state = newState
        isDetecting = false
        onChange?()
    }

    static func failure(_ error: any Error) -> State {
        switch error as? RewriteError {
        case .missingAPIKey: .failed("Add an Anthropic API key in Settings to use tone detection.", offersSettings: true)
        case .invalidAPIKey: .failed("Your Anthropic API key was rejected. Check it in Settings.", offersSettings: true)
        case .textTooLong: .failed("This text is too long for tone detection.", offersSettings: false)
        case .failed(let message): .failed(message, offersSettings: false)
        case nil: .failed(error.localizedDescription, offersSettings: false)
        }
    }
}
