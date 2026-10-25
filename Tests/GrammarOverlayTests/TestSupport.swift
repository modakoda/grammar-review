import CoreGraphics
import Foundation
import GrammarModels
@testable import GrammarOverlay

func makeIssue(
    _ category: IssueCategory = .spelling,
    original: String = "teh",
    replacements: [String] = ["the"],
    message: String = "Possible spelling mistake.",
    id: UUID = UUID()
) -> TextIssue {
    TextIssue(
        id: id,
        range: NSRange(location: 0, length: (original as NSString).length),
        originalText: original,
        replacements: replacements,
        message: message,
        category: category,
        source: .local
    )
}

func positioned(_ issue: TextIssue, _ rects: CGRect...) -> PositionedIssue {
    PositionedIssue(issue: issue, rects: rects)
}

let primaryScreen = ScreenLayout(
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 0, y: 60, width: 1440, height: 815)
)

let rightScreen = ScreenLayout(
    frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055)
)
