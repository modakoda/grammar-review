import AppKit
import ApplicationServices
import GrammarModels

final class AXTextFieldHandle: TextFieldHandle {
    static let frameCacheLifetime: Duration = .milliseconds(50)
    static let largeTextThreshold = 50_000

    let element: AXElement
    let processID: pid_t
    let bundleID: String?
    let appName: String?
    let role: String?

    private let clipAncestors: [AXElement]
    private let layoutCache = LineLayoutCache()
    private var cachedText: NSString?
    private var cachedVisibleFrame: (frame: VisibleFrame, at: ContinuousClock.Instant)?
    private var lastFieldSize: CGSize?
    private var health = Responsiveness()
    private let replacer = AXTextReplacer()

    init(element: AXElement, processID: pid_t, bundleID: String?, appName: String?, role: String?) {
        self.element = element
        self.processID = processID
        self.bundleID = bundleID
        self.appName = appName
        self.role = role
        element.setMessagingTimeout(AccessibilityTiming.messagingTimeout)
        clipAncestors = element.clippingAncestors()
    }

    var isSecure: Bool {
        isSecureElement() || SecureInput.ownerPID() == processID
    }

    var isSingleLine: Bool {
        role.map(FieldClassifier.singleLineRoles.contains) ?? false
    }

    func readText() -> String? {
        guard !health.isSuspended(), !isSecureElement() else { return nil }
        let (value, error) = timed { element.copyValue(kAXValueAttribute) }
        var text = AXValueConversion.string(value) ?? (value as? NSAttributedString)?.string
        if text == nil, error != .invalidUIElement, error != .cannotComplete {
            text = readTextByRange() ?? (error == .noValue ? "" : nil)
        }
        if let text { remember(text) }
        return text
    }

    func selectedRange() -> NSRange? {
        guard !health.isSuspended() else { return nil }
        let (value, _) = timed { element.copyValue(kAXSelectedTextRangeAttribute) }
        return AXValueConversion.axValue(value).flatMap(AXValueConversion.range)
    }

    func frame() -> CGRect? {
        guard case .visible(let rect) = visibleFrame() else { return nil }
        return ScreenGeometry.flip(rect)
    }

    func rects(for range: NSRange) -> [CGRect] {
        guard range.location != NSNotFound, range.location >= 0, range.length > 0, !health.isSuspended() else { return [] }
        let clip: CGRect?
        switch visibleFrame() {
        case .hidden: return []
        case .unknown: clip = nil
        case .visible(let rect): clip = rect
        }
        if cachedText == nil { _ = readText() }

        let querier = AXLayoutQuerier(element: element, cache: layoutCache)
        let layout = CachingLayoutQuerier(base: querier, cache: layoutCache)
        let axRects = LineSplitter.lineRects(for: range, text: cachedText, layout: layout)
        if querier.timedOut { health.record(.cannotComplete, elapsed: AccessibilityTiming.timeoutDetectionThreshold) }
        return RectGeometry.screenRects(fromAX: axRects, visibleField: clip, primaryHeight: ScreenGeometry.primaryDisplayHeight)
    }

    @discardableResult
    func replace(_ range: NSRange, with replacement: String) -> Bool {
        replacer.replace(range, with: replacement, in: self)
    }

    @discardableResult
    func select(_ range: NSRange) -> Bool {
        guard !health.isSuspended() else { return false }
        return element.setRange(kAXSelectedTextRangeAttribute, range) == .success
    }

    func isSameField(as other: any TextFieldHandle) -> Bool {
        guard let other = other as? AXTextFieldHandle else { return false }
        return element.isSame(as: other.element)
    }

    var isAlive: Bool {
        element.copyValue(kAXRoleAttribute).error != .invalidUIElement
    }

    var isUnresponsive: Bool {
        health.isSuspended()
    }

    var lastKnownTextLength: Int? {
        cachedText?.length
    }

    func invalidateGeometry() {
        cachedVisibleFrame = nil
    }

    func frameForChangeTracking() -> CGRect? {
        switch visibleFrame() {
        case .unknown: nil
        case .hidden: .null
        case .visible(let rect): ScreenGeometry.flip(rect)
        }
    }

    var logName: String {
        "\(role ?? "?") in \(bundleID ?? "pid \(processID)")"
    }

    private func isSecureElement() -> Bool {
        let values = element.copyValues([kAXRoleAttribute, kAXSubroleAttribute])
        return FieldClassifier.isSecure(
            role: AXValueConversion.string(values?[0] ?? nil),
            subrole: AXValueConversion.string(values?[1] ?? nil),
            roleDescription: nil
        )
    }

    private func readTextByRange() -> String? {
        guard let count = AXValueConversion.int(element.copyValue(kAXNumberOfCharactersAttribute).value), count >= 0 else { return nil }
        return count == 0 ? "" : element.string(for: NSRange(location: 0, length: count))
    }

    private func remember(_ text: String) {
        if let cachedText, cachedText.isEqual(to: text) { return }
        cachedText = text as NSString
        layoutCache.invalidate()
    }

    private func visibleFrame() -> VisibleFrame {
        let now = ContinuousClock.now
        if let cachedVisibleFrame, cachedVisibleFrame.at.duration(to: now) < Self.frameCacheLifetime {
            return cachedVisibleFrame.frame
        }
        var result = VisibleFrame.unknown
        if !health.isSuspended(now: now) {
            let (fieldFrame, _) = timed { element.frame() }
            if let fieldFrame {
                if fieldFrame.size != lastFieldSize {
                    if lastFieldSize != nil { layoutCache.invalidate() }
                    lastFieldSize = fieldFrame.size
                }
                result = RectGeometry.visibleFrame(field: fieldFrame, clips: clipAncestors.compactMap { $0.frame().rect })
            }
        }
        cachedVisibleFrame = (result, now)
        return result
    }

    private func timed<T>(_ body: () -> (T?, AXError)) -> (T?, AXError) {
        let start = ContinuousClock.now
        let (value, error) = body()
        health.record(error, elapsed: start.duration(to: .now))
        return (value, error)
    }
}
