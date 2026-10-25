import Foundation
import GrammarModels

public struct EditorServices {
    public var checker: any GrammarChecking
    public var rewriter: any TextRewriting
    public var toneDetector: any ToneDetecting
    public var composer: any TextComposing
    public var settings: () -> AppSettings
    public var saveGoals: (WritingGoals) -> Void
    public var addToDictionary: (String) -> Void
    public var openSettings: () -> Void

    public init(
        checker: any GrammarChecking,
        rewriter: any TextRewriting,
        toneDetector: any ToneDetecting,
        composer: any TextComposing,
        settings: @escaping () -> AppSettings,
        saveGoals: @escaping (WritingGoals) -> Void,
        addToDictionary: @escaping (String) -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.checker = checker
        self.rewriter = rewriter
        self.toneDetector = toneDetector
        self.composer = composer
        self.settings = settings
        self.saveGoals = saveGoals
        self.addToDictionary = addToDictionary
        self.openSettings = openSettings
    }
}
