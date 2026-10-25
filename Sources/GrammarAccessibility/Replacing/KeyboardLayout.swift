import AppKit
import Carbon.HIToolbox
import CoreGraphics
import GrammarModels

enum KeyboardLayout {
    static func keyCode(producing character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        let commandModifier = UInt32((cmdKey >> 8) & 0xFF)

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for modifiers in [commandModifier, 0] {
                for code in 0..<128 {
                    var deadKeys: UInt32 = 0
                    var length = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layout, UInt16(code), UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, characters.count, &length, &characters
                    )
                    if status == noErr, length > 0,
                       String(utf16CodeUnits: characters, count: length).lowercased() == target {
                        return CGKeyCode(code)
                    }
                }
            }
            return nil
        }
    }
}
