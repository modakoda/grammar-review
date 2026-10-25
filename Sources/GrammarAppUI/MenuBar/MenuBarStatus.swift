import Foundation

public enum MenuBarStatus: Equatable {
    case active
    case paused
    case disabledForApp(String)
    case needsPermission
    case windowsHidden
    case aiUnavailable(String)
}
