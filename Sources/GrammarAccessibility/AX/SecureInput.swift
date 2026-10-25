import ApplicationServices
import CoreGraphics
import Foundation

nonisolated enum SecureInput {
    static func ownerPID() -> pid_t? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = session["kCGSSessionSecureInputPID"] as? Int, pid > 0
        else { return nil }
        return pid_t(pid)
    }
}
