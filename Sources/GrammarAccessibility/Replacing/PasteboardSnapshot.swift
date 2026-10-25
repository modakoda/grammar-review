import AppKit
import Carbon.HIToolbox
import CoreGraphics
import GrammarModels

struct PasteboardSnapshot: Equatable {
    var items: [[NSPasteboard.PasteboardType: Data]]

    static func take(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { entry[type] = data }
            }
            return entry
        }
        return PasteboardSnapshot(items: items.filter { !$0.isEmpty })
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
