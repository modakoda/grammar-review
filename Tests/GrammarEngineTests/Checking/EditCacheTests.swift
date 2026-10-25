import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct EditCacheTests {
    private func key(_ text: String, language: String? = "en") -> EditCache.Key {
        EditCache.Key(model: "claude-haiku-5-5", language: language, text: text)
    }

    private func edits(_ original: String) -> [LocatedEdit] {
        [LocatedEdit(range: NSRange(location: 0, length: (original as NSString).length), originalText: original, edit: edit(original, "x"))]
    }

    @Test func theLeastRecentlyUsedParagraphIsDroppedFirst() async {
        let cache = EditCache(capacity: 2)
        await cache.insert(edits("a"), for: key("a"))
        await cache.insert(edits("b"), for: key("b"))
        #expect(await cache.value(for: key("a")) == edits("a"), "reading “a” leaves “b” the oldest")

        await cache.insert(edits("c"), for: key("c"))
        #expect(await cache.count == 2)
        #expect(await cache.values(for: [key("a"), key("b"), key("c")]) == [edits("a"), nil, edits("c")])
    }

    @Test func theLanguageIsPartOfTheKey() async {
        let cache = EditCache()
        await cache.insert(edits("a"), for: key("a", language: "en"))
        #expect(await cache.value(for: key("a", language: "lt")) == nil)
        #expect(await cache.value(for: key("a", language: "en")) == edits("a"))
    }

    @Test func holdsAtLeastOneParagraphAndCanBeEmptied() async {
        let cache = EditCache(capacity: 0)
        await cache.insert(edits("a"), for: key("a"))
        await cache.insert(edits("b"), for: key("b"))
        #expect(await cache.count == 1)
        #expect(await cache.value(for: key("b")) == edits("b"))

        await cache.removeAll()
        #expect(await cache.value(for: key("b")) == nil)
    }
}
