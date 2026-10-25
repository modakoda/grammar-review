import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var isEnabled = true
    public var pausedUntil: Date?
    public var aiEnabled = true
    public var aiProvider: AIProvider = .claude
    public var aiModel = "claude-haiku-5-5"
    public var localServerURL = LocalServerPreset.lmStudio.url
    public var localModel = ""
    public var cloudModels: [String: String] = [:]
    public var aiDelay: Double = 1.0
    public var maxAICharacters = 6000
    public var languageMode: LanguageMode = .automatic
    public var enabledCategories: Set<IssueCategory> = Set(IssueCategory.allCases)
    public var disabledBundleIDs: Set<String> = AppSettings.defaultDisabledBundleIDs
    public var personalDictionary: Set<String> = []
    public var styleGuide: [StyleRule] = []
    public var harperEnabled = true
    public var harperPath = ""
    public var showBadge = true
    public var inputBadgePlacement: BadgePlacement = .automatic
    public var textAreaBadgePlacement: BadgePlacement = .automatic
    public var badgeSpacing = AppSettings.defaultBadgeSpacing
    public var editorGoals = WritingGoals.none
    public var appGoals: [String: WritingGoals] = [:]
    public var launchAtLogin = false
    public var hasCompletedOnboarding = false

    public init() {}

    public static let badgeSpacingRange: ClosedRange<Double> = 4...40
    public static let defaultBadgeSpacing: Double = 8

    public static let defaultDisabledBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.jetbrains.intellij",
        "com.sublimetext.4",
        "com.github.GitHubClient",
    ]

    public func isActive(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        if let pausedUntil, pausedUntil > date { return false }
        return true
    }

    public func allowsApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return !disabledBundleIDs.contains(bundleID)
    }

    public func cloudModel(for service: CloudService) -> String {
        let chosen = cloudModels[service.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return chosen.isEmpty ? service.defaultModel : chosen
    }

    public func goals(forApp bundleID: String?) -> WritingGoals {
        bundleID.flatMap { appGoals[$0] } ?? .none
    }

    public func badgePlacement(for kind: FieldKind) -> BadgePlacement {
        switch kind {
        case .input: inputBadgePlacement
        case .textArea: textAreaBadgePlacement
        }
    }

    public mutating func setBadgePlacement(_ placement: BadgePlacement, for kind: FieldKind) {
        switch kind {
        case .input: inputBadgePlacement = placement
        case .textArea: textAreaBadgePlacement = placement
        }
    }

    public func differsOnlyInBadge(from other: AppSettings) -> Bool {
        var other = other
        other.showBadge = showBadge
        other.inputBadgePlacement = inputBadgePlacement
        other.textAreaBadgePlacement = textAreaBadgePlacement
        other.badgeSpacing = badgeSpacing
        return other == self
    }

    public func isInPersonalDictionary(_ word: String) -> Bool {
        personalDictionary.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, pausedUntil, aiEnabled, aiProvider, aiModel, localServerURL, localModel, cloudModels
        case aiDelay, maxAICharacters, languageMode
        case enabledCategories, disabledBundleIDs, personalDictionary, styleGuide, harperEnabled, harperPath
        case showBadge, inputBadgePlacement, textAreaBadgePlacement, badgeSpacing
        case editorGoals, appGoals, launchAtLogin, hasCompletedOnboarding
    }

    private enum LegacyKeys: String, CodingKey {
        case editorStyle
        case badgePlacement
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
        pausedUntil = try c.decodeIfPresent(Date.self, forKey: .pausedUntil)
        aiEnabled = try c.decodeIfPresent(Bool.self, forKey: .aiEnabled) ?? d.aiEnabled
        aiProvider = try c.decodeIfPresent(AIProvider.self, forKey: .aiProvider) ?? d.aiProvider
        aiModel = try c.decodeIfPresent(String.self, forKey: .aiModel) ?? d.aiModel
        localServerURL = try c.decodeIfPresent(String.self, forKey: .localServerURL) ?? d.localServerURL
        localModel = try c.decodeIfPresent(String.self, forKey: .localModel) ?? d.localModel
        cloudModels = (try? c.decodeIfPresent([String: String].self, forKey: .cloudModels)) ?? d.cloudModels
        aiDelay = try c.decodeIfPresent(Double.self, forKey: .aiDelay) ?? d.aiDelay
        maxAICharacters = try c.decodeIfPresent(Int.self, forKey: .maxAICharacters) ?? d.maxAICharacters
        languageMode = try c.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? d.languageMode
        enabledCategories = try c.decodeIfPresent(Set<IssueCategory>.self, forKey: .enabledCategories) ?? d.enabledCategories
        disabledBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .disabledBundleIDs) ?? d.disabledBundleIDs
        personalDictionary = try c.decodeIfPresent(Set<String>.self, forKey: .personalDictionary) ?? d.personalDictionary
        styleGuide = (try? c.decodeIfPresent([StyleRule].self, forKey: .styleGuide)) ?? d.styleGuide
        harperEnabled = try c.decodeIfPresent(Bool.self, forKey: .harperEnabled) ?? d.harperEnabled
        harperPath = try c.decodeIfPresent(String.self, forKey: .harperPath) ?? d.harperPath
        showBadge = try c.decodeIfPresent(Bool.self, forKey: .showBadge) ?? d.showBadge
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let sharedPlacement = (try? legacy.decodeIfPresent(BadgePlacement.self, forKey: .badgePlacement)) ?? nil
        inputBadgePlacement = try c.decodeIfPresent(BadgePlacement.self, forKey: .inputBadgePlacement)
            ?? sharedPlacement ?? d.inputBadgePlacement
        textAreaBadgePlacement = try c.decodeIfPresent(BadgePlacement.self, forKey: .textAreaBadgePlacement)
            ?? sharedPlacement ?? d.textAreaBadgePlacement
        badgeSpacing = try c.decodeIfPresent(Double.self, forKey: .badgeSpacing)
            .map { min(max($0, Self.badgeSpacingRange.lowerBound), Self.badgeSpacingRange.upperBound) } ?? d.badgeSpacing
        if let goals = try? c.decodeIfPresent(WritingGoals.self, forKey: .editorGoals) {
            editorGoals = goals
        } else {
            let style = (try? legacy.decodeIfPresent(WritingStyle.self, forKey: .editorStyle)) ?? nil
            editorGoals = WritingGoals(style: style ?? .neutral)
        }
        appGoals = (try? c.decodeIfPresent([String: WritingGoals].self, forKey: .appGoals)) ?? d.appGoals
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
    }
}
