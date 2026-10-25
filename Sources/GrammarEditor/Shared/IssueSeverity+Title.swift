import GrammarModels

extension IssueSeverity {
    var title: String {
        switch self {
        case .correctness: "Correctness"
        case .clarity: "Clarity"
        case .style: "Style"
        }
    }
}
