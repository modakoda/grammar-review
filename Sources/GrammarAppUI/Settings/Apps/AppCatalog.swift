import AppKit
import GrammarModels
import UniformTypeIdentifiers

struct AppEntry: Identifiable, Hashable {
    var bundleID: String
    var name: String
    var url: URL?
    var id: String { bundleID }
}

final class AppCatalog {
    private let locate: (String) -> URL?
    private let nameForURL: (URL) -> String?
    private var cache: [String: AppEntry] = [:]
    private var icons: [String: NSImage] = [:]

    init(
        locate: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        nameForURL: @escaping (URL) -> String? = AppCatalog.bundleName
    ) {
        self.locate = locate
        self.nameForURL = nameForURL
    }

    static let knownNames: [String: String] = [
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "iTerm",
        "dev.warp.Warp-Stable": "Warp",
        "com.mitchellh.ghostty": "Ghostty",
        "net.kovidgoyal.kitty": "kitty",
        "com.apple.keychainaccess": "Keychain Access",
        "com.apple.Passwords": "Passwords",
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.bitwarden.desktop": "Bitwarden",
        "com.apple.dt.Xcode": "Xcode",
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.sublimetext.4": "Sublime Text",
        "com.github.GitHubClient": "GitHub Desktop",
    ]

    func entry(for bundleID: String) -> AppEntry {
        if let cached = cache[bundleID] { return cached }
        let url = locate(bundleID)
        let name = url.flatMap(nameForURL) ?? Self.knownNames[bundleID] ?? bundleID
        let entry = AppEntry(bundleID: bundleID, name: name, url: url)
        cache[bundleID] = entry
        return entry
    }

    func entries(for bundleIDs: Set<String>) -> [AppEntry] {
        bundleIDs.map(entry(for:)).sorted { lhs, rhs in
            if (lhs.url == nil) != (rhs.url == nil) { return lhs.url != nil }
            return Self.byName(lhs, rhs)
        }
    }

    func icon(for entry: AppEntry) -> NSImage {
        if let icon = icons[entry.bundleID] { return icon }
        let icon = entry.url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icon.size = NSSize(width: 32, height: 32)
        icons[entry.bundleID] = icon
        return icon
    }

    func runningApps(excluding excluded: Set<String>) -> [AppEntry] {
        let ownID = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app -> AppEntry? in
            guard
                app.activationPolicy == .regular,
                let id = app.bundleIdentifier,
                id != ownID,
                !excluded.contains(id),
                seen.insert(id).inserted
            else { return nil }
            let entry = AppEntry(bundleID: id, name: app.localizedName ?? id, url: app.bundleURL)
            cache[id] = cache[id] ?? entry
            return entry
        }
        .sorted(by: Self.byName)
    }

    static func byName(_ lhs: AppEntry, _ rhs: AppEntry) -> Bool {
        let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        return order == .orderedSame ? lhs.bundleID < rhs.bundleID : order == .orderedAscending
    }

    nonisolated static func bundleName(_ url: URL) -> String? {
        var name = FileManager.default.displayName(atPath: url.path)
        if name.lowercased().hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        if !name.isEmpty { return name }
        let bundle = Bundle(url: url)
        return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    struct ChosenApps {
        var bundleIDs: [String] = []
        var skipped: [String] = []
    }

    static func chooseApps() -> ChosenApps {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps to Turn Off Checking In"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        var chosen = ChosenApps()
        guard panel.runModal() == .OK else { return chosen }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                chosen.bundleIDs.append(id)
            } else {
                chosen.skipped.append(url.deletingPathExtension().lastPathComponent)
            }
        }
        return chosen
    }
}
