import Foundation

final class RepeatingTimer {
    private var timer: Timer?

    init(interval: TimeInterval, tolerance: TimeInterval? = nil, action: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = tolerance ?? interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
