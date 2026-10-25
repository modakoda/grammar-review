import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ComposeInsertionTests {
    @Test(arguments: [
        ("", 0, "X Y"),
        ("Hi", 2, " X Y"),
        ("Hi ", 3, "X Y"),
        ("Hi there", 3, "X Y "),
        ("Hi there", 0, "X Y "),
    ])
    func inlineInsertionIsOneLineWithSpaces(text: String, location: Int, expected: String) {
        #expect(ComposeInsertion.text("X\nY", at: NSRange(location: location, length: 0), in: text, as: .inline) == expected)
    }

    @Test(arguments: [
        ("", 0, "X"),
        ("Hello", 5, "\n\nX"),
        ("Hello\n", 6, "\nX"),
        ("Hello\n\n", 7, "X"),
        ("Hello", 0, "X\n\n"),
        ("Hello world", 5, "\n\nX\n\n"),
        ("Hello\nworld", 5, "\n\nX\n"),
    ])
    func paragraphInsertionIsSetApartByBlankLines(text: String, location: Int, expected: String) {
        #expect(ComposeInsertion.text("X", at: NSRange(location: location, length: 0), in: text, as: .paragraph) == expected)
    }

    @Test func aSelectionIsReplacedAsIsOrOnOneLine() {
        #expect(ComposeInsertion.text("X\nY", at: NSRange(location: 0, length: 2), in: "Hi there", as: .paragraph) == "X\nY")
        #expect(ComposeInsertion.text("X\nY", at: NSRange(location: 0, length: 2), in: "Hi there", as: .inline) == "X Y")
    }

    @Test func fieldsWithLinesGetParagraphs() {
        #expect(ComposeInsertion.style(for: "one line") == .inline)
        #expect(ComposeInsertion.style(for: "two\nlines") == .paragraph)
    }
}
