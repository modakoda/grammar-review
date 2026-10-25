import ApplicationServices
import CoreGraphics
import Foundation

nonisolated enum AXValueConversion {
    static func axValue(_ ref: CFTypeRef?) -> AXValue? {
        guard let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(ref, to: AXValue.self)
    }

    static func isErrorValue(_ ref: CFTypeRef) -> Bool {
        axValue(ref).map { AXValueGetType($0) == .axError } ?? false
    }

    static func makeValue(_ range: NSRange) -> AXValue? {
        guard var cfRange = RangeConversion.cfRange(from: range) else { return nil }
        return AXValueCreate(.cfRange, &cfRange)
    }

    static func makeValue(_ rect: CGRect) -> AXValue? {
        var rect = rect
        return AXValueCreate(.cgRect, &rect)
    }

    static func makeValue(_ point: CGPoint) -> AXValue? {
        var point = point
        return AXValueCreate(.cgPoint, &point)
    }

    static func makeValue(_ size: CGSize) -> AXValue? {
        var size = size
        return AXValueCreate(.cgSize, &size)
    }

    static func range(_ value: AXValue) -> NSRange? {
        guard AXValueGetType(value) == .cfRange else { return nil }
        var cfRange = CFRange()
        guard AXValueGetValue(value, .cfRange, &cfRange) else { return nil }
        return RangeConversion.nsRange(from: cfRange)
    }

    static func rect(_ value: AXValue) -> CGRect? {
        guard AXValueGetType(value) == .cgRect else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(value, .cgRect, &rect) ? rect : nil
    }

    static func point(_ value: AXValue) -> CGPoint? {
        guard AXValueGetType(value) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    static func size(_ value: AXValue) -> CGSize? {
        guard AXValueGetType(value) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    static func string(_ ref: CFTypeRef?) -> String? {
        guard let ref, CFGetTypeID(ref) == CFStringGetTypeID() else { return nil }
        return ref as? String
    }

    static func isString(_ ref: CFTypeRef?) -> Bool {
        guard let ref else { return false }
        return CFGetTypeID(ref) == CFStringGetTypeID() || CFGetTypeID(ref) == CFAttributedStringGetTypeID()
    }

    static func bool(_ ref: CFTypeRef?) -> Bool? {
        guard let ref else { return nil }
        if CFGetTypeID(ref) == CFBooleanGetTypeID() {
            return CFBooleanGetValue(unsafeDowncast(ref, to: CFBoolean.self))
        }
        if CFGetTypeID(ref) == CFNumberGetTypeID() {
            return (ref as? NSNumber)?.boolValue
        }
        return nil
    }

    static func int(_ ref: CFTypeRef?) -> Int? {
        guard let ref, CFGetTypeID(ref) == CFNumberGetTypeID() else { return nil }
        return (ref as? NSNumber)?.intValue
    }

    static func element(_ ref: CFTypeRef?) -> AXElement? {
        guard let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return AXElement(unsafeDowncast(ref, to: AXUIElement.self))
    }

    static func elements(_ ref: CFTypeRef?) -> [AXElement]? {
        guard let ref, CFGetTypeID(ref) == CFArrayGetTypeID(), let array = ref as? [AnyObject] else { return nil }
        return array.compactMap { element($0) }
    }
}

nonisolated enum RangeConversion {
    static func nsRange(from range: CFRange) -> NSRange? {
        guard range.location >= 0, range.length >= 0, range.location <= Int.max - range.length,
              range.location != NSNotFound
        else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func cfRange(from range: NSRange) -> CFRange? {
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              range.location <= Int.max - range.length
        else { return nil }
        return CFRange(location: range.location, length: range.length)
    }
}
