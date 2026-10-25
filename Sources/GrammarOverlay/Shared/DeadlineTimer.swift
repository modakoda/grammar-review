import Foundation

final class DeadlineTimer {
    private let action: () -> Void
    private var task: Task<Void, Never>?
    private var deadline: TimeInterval?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func schedule(at deadline: TimeInterval, now: TimeInterval) {
        if task != nil, let scheduled = self.deadline, scheduled <= deadline { return }
        task?.cancel()
        self.deadline = deadline
        let delay = max(0, deadline - now)
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.task = nil
            self.deadline = nil
            self.action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        deadline = nil
    }
}
