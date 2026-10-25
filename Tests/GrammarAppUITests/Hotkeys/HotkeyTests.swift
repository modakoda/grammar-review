import AppKit
import Carbon.HIToolbox
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct HotkeyTests {
    @Test func keyCodes() {
        #expect(Hotkey.showSuggestions.keyCode == UInt32(kVK_ANSI_G))
        #expect(Hotkey.rewriteSelection.keyCode == UInt32(kVK_ANSI_R))
        #expect(Hotkey.openEditor.keyCode == UInt32(kVK_ANSI_E))
        #expect(Hotkey.writeWithAI.keyCode == UInt32(kVK_ANSI_W))
        #expect(Set(Hotkey.allCases.map(\.keyCode)).count == Hotkey.allCases.count)
    }

    @Test func modifiersAreControlOption() {
        for hotkey in Hotkey.allCases {
            #expect(hotkey.carbonModifiers == UInt32(controlKey | optionKey))
            #expect(hotkey.modifierFlags == [.control, .option])
        }
    }

    @Test func labels() {
        #expect(Hotkey.showSuggestions.displayString == "⌃⌥G")
        #expect(Hotkey.rewriteSelection.displayString == "⌃⌥R")
        #expect(Hotkey.showSuggestions.keyEquivalent == "g")
        #expect(Hotkey.rewriteSelection.keyEquivalent == "r")
    }

    @Test func unregisteringWithoutRegistrationsIsHarmless() {
        let manager = HotkeyManager()
        manager.unregisterAll()
        #expect(!manager.isRegistered(.showSuggestions))
        #expect(!manager.isRegistered(.rewriteSelection))
    }

    @Test func dispatcherRoutesByID() {
        var fired: [UInt32] = []
        HotkeyDispatcher.handlers[9_000_001] = { fired.append(9_000_001) }
        HotkeyDispatcher.handlers[9_000_002] = { fired.append(9_000_002) }
        defer {
            HotkeyDispatcher.handlers[9_000_001] = nil
            HotkeyDispatcher.handlers[9_000_002] = nil
        }

        HotkeyDispatcher.dispatch(9_000_002)
        HotkeyDispatcher.dispatch(9_000_003)
        #expect(fired == [9_000_002])
    }
}
