import Foundation
import GrammarModels
import os

final class UsageRecorder: Sendable {
    private let handler = OSAllocatedUnfairLock<(@Sendable (UsageEvent) -> Void)?>(initialState: nil)

    func setHandler(_ newHandler: (@Sendable (UsageEvent) -> Void)?) {
        handler.withLock { $0 = newHandler }
    }

    func record(_ event: UsageEvent) {
        handler.withLock { $0 }?(event)
    }
}
