import Foundation

struct HarperLocator: Sendable {
    enum Location: Equatable, Sendable {
        case found(String)
        case missing
        case invalid(String)
    }

    static let programName = "harper-ls"

    var environment: [String: String] = ProcessInfo.processInfo.environment
    var home: String = NSHomeDirectory()
    var isExecutable: @Sendable (String) -> Bool = HarperLocator.isExecutableFile

    var searchDirectories: [String] {
        let path = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let usual = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.cargo/bin", "\(home)/.local/bin",
                     "\(home)/.nix-profile/bin", "/run/current-system/sw/bin", "/opt/local/bin"]
        var seen = Set<String>()
        return (path + usual).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    func locate(customPath: String) -> Location {
        let custom = customPath.trimmedWhitespace
        if !custom.isEmpty {
            let expanded = expandingTilde(custom)
            let candidates = [expanded, (expanded as NSString).appendingPathComponent(Self.programName)]
            return candidates.first(where: isExecutable).map(Location.found) ?? .invalid(expanded)
        }
        for directory in searchDirectories {
            let candidate = (directory as NSString).appendingPathComponent(Self.programName)
            if isExecutable(candidate) { return .found(candidate) }
        }
        return .missing
    }

    private func expandingTilde(_ path: String) -> String {
        if path == "~" { return home }
        guard path.hasPrefix("~/") else { return path }
        return (home as NSString).appendingPathComponent(String(path.dropFirst(2)))
    }

    static func isExecutableFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let manager = FileManager.default
        return manager.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue && manager.isExecutableFile(atPath: path)
    }
}
