import AppKit
import Carbon.HIToolbox
import GrammarModels

public enum Hotkey: CaseIterable {
    case showSuggestions
    case rewriteSelection
    case writeWithAI
    case openEditor
}

extension Hotkey {
    public var keyCode: UInt32 {
        switch self {
        case .showSuggestions: UInt32(kVK_ANSI_G)
        case .rewriteSelection: UInt32(kVK_ANSI_R)
        case .writeWithAI: UInt32(kVK_ANSI_W)
        case .openEditor: UInt32(kVK_ANSI_E)
        }
    }

    public var carbonModifiers: UInt32 {
        UInt32(controlKey | optionKey)
    }

    public var keyEquivalent: String {
        switch self {
        case .showSuggestions: "g"
        case .rewriteSelection: "r"
        case .writeWithAI: "w"
        case .openEditor: "e"
        }
    }

    public var modifierFlags: NSEvent.ModifierFlags {
        [.control, .option]
    }

    public var displayString: String {
        "⌃⌥" + keyEquivalent.uppercased()
    }

    public var title: String {
        switch self {
        case .showSuggestions: "Show suggestions"
        case .rewriteSelection: "Rewrite selection or sentence"
        case .writeWithAI: "Write with AI"
        case .openEditor: "Open the editor"
        }
    }
}
