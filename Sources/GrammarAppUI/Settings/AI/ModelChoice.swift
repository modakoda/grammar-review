import GrammarModels

struct ModelChoice: Identifiable, Hashable {
    var id: String
    var name: String
    var detail: String

    static func options(including current: String) -> [ModelChoice] {
        var choices = AIModelOption.all.map { ModelChoice(id: $0.id, name: $0.name, detail: $0.detail) }
        if !choices.contains(where: { $0.id == current }) {
            choices.append(ModelChoice(id: current, name: current, detail: "A model that isn't in the built-in list."))
        }
        return choices
    }
}
