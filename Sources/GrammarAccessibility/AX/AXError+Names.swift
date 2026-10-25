import ApplicationServices
import CoreGraphics
import Foundation

extension AXError {
    nonisolated var logName: String {
        switch self {
        case .success: "success"
        case .failure: "failure"
        case .illegalArgument: "illegalArgument"
        case .invalidUIElement: "invalidUIElement"
        case .invalidUIElementObserver: "invalidUIElementObserver"
        case .cannotComplete: "cannotComplete"
        case .attributeUnsupported: "attributeUnsupported"
        case .actionUnsupported: "actionUnsupported"
        case .notificationUnsupported: "notificationUnsupported"
        case .notImplemented: "notImplemented"
        case .notificationAlreadyRegistered: "notificationAlreadyRegistered"
        case .notificationNotRegistered: "notificationNotRegistered"
        case .apiDisabled: "apiDisabled"
        case .noValue: "noValue"
        case .parameterizedAttributeUnsupported: "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: "notEnoughPrecision"
        @unknown default: "AXError(\(rawValue))"
        }
    }

    nonisolated var isUnsupported: Bool {
        switch self {
        case .attributeUnsupported, .parameterizedAttributeUnsupported, .notImplemented, .actionUnsupported,
             .notificationUnsupported:
            true
        default:
            false
        }
    }
}
