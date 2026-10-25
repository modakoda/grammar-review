import AppKit
import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct SpellingFilterTests {
    private func isProtected(_ word: String, in text: String) -> Bool {
        let range = (text as NSString).range(of: word)
        precondition(range.location != NSNotFound, "\(word) not in text")
        return SpellingFilter.shouldIgnore(range, in: text as NSString,
                                           protected: SpellingFilter.protectedRanges(in: text), settings: AppSettings())
    }

    @Test func urlsAndEmailsAreProtected() {
        let text = "See https://exmaple.com/pth?q=1 or www.exmaple.org and mail jhon@exmaple.com or exmaple.net now"
        #expect(isProtected("pth", in: text))
        #expect(isProtected("exmaple.org", in: text))
        #expect(isProtected("jhon", in: text))
        #expect(isProtected("exmaple.net", in: text))
        #expect(!isProtected("now", in: text))
    }

    @Test func mentionsAndHashtagsAreProtected() {
        let text = "Thanks @jdoe for #swiftlang tips, teh best"
        #expect(isProtected("jdoe", in: text))
        #expect(isProtected("swiftlang", in: text))
        #expect(!isProtected("teh", in: text))
    }

    @Test func codeInBackticksIsProtected() {
        let text = "Call `fooo barr` then\n```\nlet qux = baz\n```\nand teh end"
        #expect(isProtected("fooo", in: text))
        #expect(isProtected("barr", in: text))
        #expect(isProtected("qux", in: text))
        #expect(!isProtected("teh", in: text))
        #expect(isProtected("wrk", in: "Text\n```\nwrk in progress"))
    }

    @Test func identifiersAreProtected() {
        let text = "Use myVarName, snake_case_thing, iPhone, abc123, Main.swift, src/utls and a::b"
        for word in ["myVarName", "snake_case_thing", "iPhone", "abc123", "Main.swift", "utls", "a::b"] {
            #expect(isProtected(word, in: text), "\(word)")
        }
    }

    @Test func acronymsAndPersonalDictionaryWordsAreIgnored() {
        var settings = AppSettings()
        settings.personalDictionary = ["Kažinauskas"]
        #expect(SpellingFilter.isIgnorableWord("NASA", settings: settings))
        #expect(SpellingFilter.isIgnorableWord("URLs", settings: settings))
        #expect(SpellingFilter.isIgnorableWord("kažinauskas", settings: settings))
        #expect(!SpellingFilter.isIgnorableWord("Teh", settings: settings))
        #expect(!SpellingFilter.isIgnorableWord("A", settings: settings))
    }

    @Test func plainWordsAreNotCode() {
        for word in ["hello", "Hello", "don't", "state-of-the-art", "O'Brien", "naïve"] {
            #expect(!SpellingFilter.looksLikeCode(word), "\(word)")
        }
        #expect(SpellingFilter.trimmedToken("(“*teh*”),") == "teh")
        #expect(SpellingFilter.trimmedToken(".gitignore") == ".gitignore")
    }
}
