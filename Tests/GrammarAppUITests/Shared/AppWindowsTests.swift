import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@Test @MainActor func windowOnScreenCheck() {
    let screen = NSRect(x: 0, y: 85, width: 1800, height: 1044)
    #expect(AppWindows.isOnScreen(NSRect(x: 610, y: 484, width: 580, height: 512), screens: [screen]))
    #expect(!AppWindows.isOnScreen(NSRect(x: 2326, y: 367, width: 580, height: 508), screens: [screen]))
    #expect(!AppWindows.isOnScreen(NSRect(x: 1500, y: 484, width: 580, height: 512), screens: [screen]))
}
