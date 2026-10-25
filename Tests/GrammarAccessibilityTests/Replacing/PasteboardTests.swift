import AppKit
import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("Clipboard paste fallback", .serialized)
@MainActor
struct PasteboardTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("GrammarAccessibilityTests.\(UUID().uuidString)"))
    }

    @Test func snapshotRestoresEveryItemAndType() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("hello", forType: .string)
        first.setData(Data("<b>hello</b>".utf8), forType: .html)
        let second = NSPasteboardItem()
        second.setString("https://example.com", forType: .URL)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])

        let snapshot = PasteboardSnapshot.take(from: pasteboard)
        #expect(snapshot.items.count == 2)

        pasteboard.clearContents()
        pasteboard.setString("temporary", forType: .string)
        snapshot.restore(to: pasteboard)

        #expect(PasteboardSnapshot.take(from: pasteboard) == snapshot)
        #expect(pasteboard.string(forType: .string) == "hello")
    }

    @Test func backToBackPastesRestoreTheOriginalClipboard() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("user clipboard", forType: .string)
        let controller = PasteController(pasteboard: pasteboard)

        controller.stage("first fix")
        #expect(pasteboard.string(forType: .string) == "first fix")
        #expect(pasteboard.data(forType: PasteController.transientType) != nil)
        controller.stage("second fix")
        controller.restoreNow()

        #expect(pasteboard.string(forType: .string) == "user clipboard")
        #expect(pasteboard.data(forType: PasteController.transientType) == nil)
    }

    @Test func restoreDoesNotClobberANewerCopy() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("old", forType: .string)
        let controller = PasteController(pasteboard: pasteboard)

        controller.stage("fix")
        pasteboard.clearContents()
        pasteboard.setString("copied meanwhile", forType: .string)
        controller.restoreNow()

        #expect(pasteboard.string(forType: .string) == "copied meanwhile")
    }

    @Test func emptyClipboardIsRestoredEmpty() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        let controller = PasteController(pasteboard: pasteboard)
        controller.stage("fix")
        controller.restoreNow()
        #expect(pasteboard.pasteboardItems?.isEmpty ?? true)
    }

    @Test func keyboardLayoutLookupIsSane() {
        if let code = KeyboardLayout.keyCode(producing: "v") {
            #expect(code < 128)
        }
    }
}
