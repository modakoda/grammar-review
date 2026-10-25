import AppKit

enum OverlayLevel {
    static let underlines = NSWindow.Level.floating
    static let badge = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    static let popover = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
}
