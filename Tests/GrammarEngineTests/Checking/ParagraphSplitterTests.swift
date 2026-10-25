import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ParagraphSplitterTests {
    @Test func splitsOnAllLineBreaksKeepingUTF16Offsets() {
        let text = "First line\n\nSecond line\r\nThird\u{2028}Fourth"
        let paragraphs = ParagraphSplitter.split(text)
        #expect(paragraphs.map(\.text) == ["First line", "Second line", "Third", "Fourth"])
        for paragraph in paragraphs {
            #expect(substring(text, paragraph.range) == paragraph.text)
        }
        #expect(paragraphs.map(\.location) == [0, 12, 25, 31])
    }

    @Test func trimsSpacesAndSkipsBlankLines() {
        let text = "   \n  Indented text  \n\t\n"
        let paragraphs = ParagraphSplitter.split(text)
        #expect(paragraphs == [Paragraph(text: "Indented text", location: 6)])
    }

    @Test func emojiBeforeAParagraphShiftsByUTF16Units() {
        let text = "😀😀\nNext"
        #expect(ParagraphSplitter.split(text) == [
            Paragraph(text: "😀😀", location: 0),
            Paragraph(text: "Next", location: 5),
        ])
    }

    @Test func emptyTextHasNoParagraphs() {
        #expect(ParagraphSplitter.split("").isEmpty)
        #expect(ParagraphSplitter.split("\n\n").isEmpty)
    }

    @Test func veryShortParagraphsAreNotWorthAI() {
        #expect(!ParagraphSplitter.isWorthChecking(Paragraph(text: "Ok.", location: 0)))
        #expect(!ParagraphSplitter.isWorthChecking(Paragraph(text: "👍 12", location: 0)))
        #expect(ParagraphSplitter.isWorthChecking(Paragraph(text: "I goed.", location: 0)))
    }
}
