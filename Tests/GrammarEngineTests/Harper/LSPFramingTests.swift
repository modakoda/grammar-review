import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct LSPFramingTests {
    private func frame(_ body: String) -> Data {
        LSPFrameDecoder.frame(Data(body.utf8))
    }

    private func text(_ data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? "<not UTF-8>"
    }

    @Test func reassemblesMessagesSplitAcrossChunks() {
        var decoder = LSPFrameDecoder()
        let data = frame(#"{"id":1}"#) + frame(#"{"id":2,"text":"ąčę 😀"}"#)
        var messages: [String] = []
        for index in stride(from: 0, to: data.count, by: 5) {
            let chunk = data.subdata(in: index..<min(index + 5, data.count))
            messages += decoder.append(chunk).map(text)
        }
        #expect(messages == [#"{"id":1}"#, #"{"id":2,"text":"ąčę 😀"}"#])
    }

    @Test func readsSeveralMessagesFromOneChunk() {
        var decoder = LSPFrameDecoder()
        let messages = decoder.append(frame("{}") + frame("[]") + frame("null"))
        #expect(messages.map(text) == ["{}", "[]", "null"])
    }

    @Test func headerNamesIgnoreCaseAndOtherHeadersAreSkipped() {
        var decoder = LSPFrameDecoder()
        let raw = "content-type: application/vscode-jsonrpc; charset=utf-8\r\nCONTENT-LENGTH:  2\r\n\r\n{}"
        #expect(decoder.append(Data(raw.utf8)) == [Data("{}".utf8)])
    }

    @Test func aHeaderWithoutALengthIsDropped() {
        var decoder = LSPFrameDecoder()
        let raw = Data("X-Junk: 1\r\n\r\n".utf8) + frame("{}")
        #expect(decoder.append(raw) == [Data("{}".utf8)])
    }

    @Test func positionsCountUTF16UnitsOnEachLine() {
        let text = "a😀b\nsecond\r\nthird\rfourth"
        let lines = LSPLineIndex(text)
        #expect(lines.offset(of: LSPPosition(line: 0, character: 3)) == 3)
        #expect(lines.offset(of: LSPPosition(line: 1, character: 0)) == 5)
        #expect(lines.offset(of: LSPPosition(line: 2, character: 2)) == 15)
        #expect(lines.offset(of: LSPPosition(line: 3, character: 6)) == 25)
        #expect(substring(text, NSRange(location: 19, length: 6)) == "fourth")
    }

    @Test func positionsPastTheLineEndStopAtTheLineEnd() {
        let lines = LSPLineIndex("ab\r\ncd")
        #expect(lines.offset(of: LSPPosition(line: 0, character: 9)) == 2)
        #expect(lines.offset(of: LSPPosition(line: 1, character: 9)) == 6)
        #expect(lines.offset(of: LSPPosition(line: 2, character: 0)) == nil)
        #expect(lines.utf16Range(of: LSPRange(start: LSPPosition(line: 1, character: 1), end: LSPPosition(line: 0, character: 0))) == nil)
    }
}
