import Foundation
import GrammarModels
import Observation

public struct HarperSetupClient {
    public var installation: (_ customPath: String) async -> HarperInstallation

    public init(installation: @escaping (_ customPath: String) async -> HarperInstallation) {
        self.installation = installation
    }
}

@Observable
final class HarperModel {
    enum State: Equatable {
        case idle
        case checking
        case checked(HarperInstallation)
    }

    static let installCommand = "brew install harper"

    private(set) var state: State = .idle

    @ObservationIgnored private let client: HarperSetupClient
    @ObservationIgnored private(set) var task: Task<Void, Never>?

    init(client: HarperSetupClient) {
        self.client = client
    }

    func refresh(customPath: String) {
        task?.cancel()
        state = .checking
        let installation = client.installation
        task = Task { [weak self] in
            let result = await installation(customPath)
            guard !Task.isCancelled else { return }
            self?.state = .checked(result)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if state == .checking { state = .idle }
    }
}
