import Foundation
import GrammarModels

extension StatusMenuModel {
    static func goalsItems(bundleID: String, goals: WritingGoals) -> [StatusMenuItem] {
        func choices<Value: CaseIterable & Equatable>(
            _ title: String,
            _ keyPath: WritableKeyPath<WritingGoals, Value>,
            name: (Value) -> String
        ) -> [StatusMenuItem] where Value.AllCases: Sequence {
            [StatusMenuItem(title)] + Value.allCases.map { value in
                var changed = goals
                changed[keyPath: keyPath] = value
                return StatusMenuItem(name(value), command: .setAppGoals(bundleID: bundleID, goals: changed), isOn: goals[keyPath: keyPath] == value)
            }
        }
        var items = choices("Style", \.style) { $0.displayName }
        items.append(.separator)
        items += choices("Audience", \.audience) { $0.displayName }
        items.append(.separator)
        items += choices("Domain", \.domain) { $0.displayName }
        items.append(.separator)
        items += choices("Intent", \.intent) { $0.displayName }
        items.append(.separator)
        if !goals.isNone {
            items.append(StatusMenuItem("Clear Goals", command: .setAppGoals(bundleID: bundleID, goals: .none)))
        }
        items.append(StatusMenuItem("Goals for Other Apps…", command: .openGoalsSettings))
        return items
    }
}
