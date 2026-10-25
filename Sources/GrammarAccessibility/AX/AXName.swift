import ApplicationServices
import CoreGraphics
import Foundation

nonisolated enum AXName {
    static let manualAccessibility = "AXManualAccessibility"
    static let enhancedUserInterface = "AXEnhancedUserInterface"
    static let editableAncestor = "AXEditableAncestor"
    static let highestEditableAncestor = "AXHighestEditableAncestor"
    static let focusableAncestor = "AXFocusableAncestor"
    static let domIdentifier = "AXDOMIdentifier"
    static let webAreaRole = "AXWebArea"
}

nonisolated enum AccessibilityTiming {
    static let messagingTimeout: Float = 0.25
    static let timeoutDetectionThreshold: Duration = .milliseconds(200)
}
