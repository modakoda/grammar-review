import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct HarperModelTests {
    @Test func reportsWhatTheProbeFinds() async {
        let model = HarperModel(client: HarperSetupClient { path in
            path.isEmpty ? .found(path: "/opt/homebrew/bin/harper-ls", version: "2.13.0") : .unusable(path: path, reason: "No program.")
        })
        #expect(model.state == .idle)
        model.refresh(customPath: "")
        #expect(model.state == .checking)
        await model.task?.value
        #expect(model.state == .checked(.found(path: "/opt/homebrew/bin/harper-ls", version: "2.13.0")))

        model.refresh(customPath: "/tmp/nothing")
        await model.task?.value
        #expect(model.state == .checked(.unusable(path: "/tmp/nothing", reason: "No program.")))
    }

    @Test func cancellingWhileCheckingGoesBackToIdle() {
        let model = HarperModel(client: HarperSetupClient { _ in
            try? await Task.sleep(for: .seconds(30))
            return .notFound
        })
        model.refresh(customPath: "")
        model.cancel()
        #expect(model.state == .idle)
        #expect(model.task == nil)
    }
}
