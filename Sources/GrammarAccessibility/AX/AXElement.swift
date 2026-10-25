import ApplicationServices
import CoreGraphics
import Foundation

nonisolated struct AXElement {
    let raw: AXUIElement

    init(_ raw: AXUIElement) {
        self.raw = raw
    }

    static func application(_ pid: pid_t) -> AXElement {
        AXElement(AXUIElementCreateApplication(pid))
    }

    static func systemWide() -> AXElement {
        AXElement(AXUIElementCreateSystemWide())
    }

    var processID: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(raw, &pid) == .success ? pid : nil
    }

    func isSame(as other: AXElement) -> Bool {
        CFEqual(raw, other.raw)
    }

    func setMessagingTimeout(_ seconds: Float) {
        _ = AXUIElementSetMessagingTimeout(raw, seconds)
    }

    func copyValue(_ attribute: String) -> (value: CFTypeRef?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        return (error == .success ? value : nil, error)
    }

    func copyValues(_ attributes: [String]) -> [CFTypeRef?]? {
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(raw, attributes as CFArray, AXCopyMultipleAttributeOptions(), &values)
        guard error == .success, let array = values as? [AnyObject], array.count == attributes.count else { return nil }
        return array.map { item -> CFTypeRef? in
            if item is NSNull || AXValueConversion.isErrorValue(item) { return nil }
            return item
        }
    }

    func string(_ attribute: String) -> String? {
        AXValueConversion.string(copyValue(attribute).value)
    }

    func bool(_ attribute: String) -> Bool? {
        AXValueConversion.bool(copyValue(attribute).value)
    }

    func element(_ attribute: String) -> AXElement? {
        AXValueConversion.element(copyValue(attribute).value)
    }

    func elements(_ attribute: String) -> [AXElement]? {
        AXValueConversion.elements(copyValue(attribute).value)
    }

    func range(_ attribute: String) -> NSRange? {
        AXValueConversion.axValue(copyValue(attribute).value).flatMap(AXValueConversion.range)
    }

    func childCount() -> Int? {
        var count: CFIndex = 0
        return AXUIElementGetAttributeValueCount(raw, kAXChildrenAttribute as CFString, &count) == .success ? count : nil
    }

    func isSettable(_ attribute: String) -> Bool? {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(raw, attribute as CFString, &settable)
        return error == .success ? settable.boolValue : nil
    }

    func frame() -> (rect: CGRect?, error: AXError) {
        var values: CFArray?
        let attributes = [kAXPositionAttribute, kAXSizeAttribute] as CFArray
        let error = AXUIElementCopyMultipleAttributeValues(raw, attributes, AXCopyMultipleAttributeOptions(), &values)
        guard error == .success, let array = values as? [AnyObject], array.count == 2,
              let position = AXValueConversion.axValue(array[0]).flatMap(AXValueConversion.point),
              let size = AXValueConversion.axValue(array[1]).flatMap(AXValueConversion.size)
        else { return (nil, error == .success ? .noValue : error) }
        return (CGRect(origin: position, size: size), .success)
    }

    @discardableResult
    func set(_ attribute: String, to value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(raw, attribute as CFString, value)
    }

    @discardableResult
    func setBool(_ attribute: String, _ value: Bool) -> AXError {
        set(attribute, to: (value ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef)
    }

    @discardableResult
    func setString(_ attribute: String, _ value: String) -> AXError {
        set(attribute, to: value as CFString)
    }

    @discardableResult
    func setRange(_ attribute: String, _ range: NSRange) -> AXError {
        guard let value = AXValueConversion.makeValue(range) else { return .illegalArgument }
        return set(attribute, to: value)
    }

    func copyParameterizedValue(_ attribute: String, _ parameter: CFTypeRef) -> (value: CFTypeRef?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(raw, attribute as CFString, parameter, &value)
        return (error == .success ? value : nil, error)
    }

    func bounds(for range: NSRange) -> (rect: CGRect?, error: AXError) {
        guard let parameter = AXValueConversion.makeValue(range) else { return (nil, .illegalArgument) }
        let (value, error) = copyParameterizedValue(kAXBoundsForRangeParameterizedAttribute, parameter)
        return (AXValueConversion.axValue(value).flatMap(AXValueConversion.rect), error)
    }

    func line(forIndex index: Int) -> (line: Int?, error: AXError) {
        let (value, error) = copyParameterizedValue(kAXLineForIndexParameterizedAttribute, NSNumber(value: index))
        return (AXValueConversion.int(value), error)
    }

    func range(forLine line: Int) -> (range: NSRange?, error: AXError) {
        let (value, error) = copyParameterizedValue(kAXRangeForLineParameterizedAttribute, NSNumber(value: line))
        return (AXValueConversion.axValue(value).flatMap(AXValueConversion.range), error)
    }

    func string(for range: NSRange) -> String? {
        guard let parameter = AXValueConversion.makeValue(range) else { return nil }
        return AXValueConversion.string(copyParameterizedValue(kAXStringForRangeParameterizedAttribute, parameter).value)
    }
}
