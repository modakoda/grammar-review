import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case suggestions
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suggestions: "Suggestions"
        case .insights: "Insights"
        }
    }
}
