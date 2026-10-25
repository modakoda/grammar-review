import AppKit
import Carbon.HIToolbox
import GrammarModels

public final class HotkeyManager {
    private struct Registration {
        var id: UInt32
        var ref: EventHotKeyRef
    }

    private var registrations: [Hotkey: Registration] = [:]

    public init() {}

    public func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        unregister(hotkey)
        guard HotkeyDispatcher.installEventHandlerIfNeeded() else { return }

        let id = HotkeyDispatcher.nextID()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            EventHotKeyID(signature: HotkeyDispatcher.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Log.app.error("Could not register hotkey \(hotkey.displayString, privacy: .public): OSStatus \(status, privacy: .public)")
            return
        }
        registrations[hotkey] = Registration(id: id, ref: ref)
        HotkeyDispatcher.handlers[id] = handler
    }

    public func isRegistered(_ hotkey: Hotkey) -> Bool {
        registrations[hotkey] != nil
    }

    public func unregister(_ hotkey: Hotkey) {
        guard let registration = registrations.removeValue(forKey: hotkey) else { return }
        UnregisterEventHotKey(registration.ref)
        HotkeyDispatcher.handlers[registration.id] = nil
    }

    public func unregisterAll() {
        for hotkey in Array(registrations.keys) {
            unregister(hotkey)
        }
        HotkeyDispatcher.removeEventHandlerIfUnused()
    }
}

enum HotkeyDispatcher {
    nonisolated static let signature: OSType = 0x4752_7677

    static var handlers: [UInt32: () -> Void] = [:]
    private static var lastID: UInt32 = 0
    private static var eventHandler: EventHandlerRef?

    static func nextID() -> UInt32 {
        lastID &+= 1
        return lastID
    }

    static func installEventHandlerIfNeeded() -> Bool {
        if eventHandler != nil { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handler: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyEventCallback, 1, &eventType, nil, &handler)
        guard status == noErr, let handler else {
            Log.app.error("Could not install the hotkey event handler: OSStatus \(status, privacy: .public)")
            return false
        }
        eventHandler = handler
        return true
    }

    static func removeEventHandlerIfUnused() {
        guard handlers.isEmpty, let eventHandler else { return }
        RemoveEventHandler(eventHandler)
        self.eventHandler = nil
    }

    static func dispatch(_ id: UInt32) {
        handlers[id]?()
    }
}

nonisolated private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == HotkeyDispatcher.signature else {
        return OSStatus(eventNotHandledErr)
    }
    let id = hotKeyID.id
    MainActor.assumeIsolated {
        HotkeyDispatcher.dispatch(id)
    }
    return noErr
}
