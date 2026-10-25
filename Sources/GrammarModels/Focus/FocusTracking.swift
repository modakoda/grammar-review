import Foundation

@MainActor
public protocol FocusTrackingDelegate: AnyObject {
    func focusTracker(_ tracker: any FocusTracking, didFocus field: (any TextFieldHandle)?)
    func focusTracker(_ tracker: any FocusTracking, textDidChangeIn field: any TextFieldHandle)
    func focusTracker(_ tracker: any FocusTracking, selectionDidChangeIn field: any TextFieldHandle)
    func focusTracker(_ tracker: any FocusTracking, geometryDidChangeFor field: any TextFieldHandle)
    func focusTrackerWindowsHiddenDidChange(_ tracker: any FocusTracking)
}

@MainActor
public protocol FocusTracking: AnyObject {
    var delegate: (any FocusTrackingDelegate)? { get set }
    var focusedField: (any TextFieldHandle)? { get }
    var windowsAreHidden: Bool { get }
    func start()
    func stop()
}
