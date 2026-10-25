import CoreGraphics
import Foundation

struct GeometryProbe: Equatable {
    var frame: CGRect?
    var firstIssueRects: [CGRect]?
}

final class GeometryWatcher {
    static let interval = Duration.milliseconds(100)

    private var task: Task<Void, Never>?
    private var lastProbe: GeometryProbe?

    func start(probe: @escaping () -> GeometryProbe?, onChange: @escaping () -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                guard let self, let current = probe() else { return }
                if current != self.lastProbe {
                    self.lastProbe = current
                    onChange()
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        lastProbe = nil
    }
}
