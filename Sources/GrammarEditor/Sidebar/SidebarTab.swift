import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case suggestions
    case insights
    case plagiarism

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suggestions: "Suggestions"
        case .insights: "Insights"
        case .plagiarism: "Plagiarism"
        }
    }
}
