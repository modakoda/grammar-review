import AppKit
import GrammarModels

enum PermissionRepair {
    static func resetAccessibility(bundleID: String? = Bundle.main.bundleIdentifier) -> Bool {
        guard let bundleID else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Log.app.error("tccutil could not run: \(error.localizedDescription, privacy: .public)")
            return false
        }
        let succeeded = process.terminationStatus == 0
        Log.app.info("Accessibility reset for \(bundleID, privacy: .public): \(succeeded ? "ok" : "failed", privacy: .public)")
        return succeeded
    }

    static func relaunch(bundlePath: String = Bundle.main.bundlePath) {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", bundlePath, "\(getpid())"]
        do {
            try reopen.run()
        } catch {
            Log.app.error("Relaunch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NSApp.terminate(nil)
    }
}
