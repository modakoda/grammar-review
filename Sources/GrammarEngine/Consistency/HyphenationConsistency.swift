import Foundation
import GrammarModels

enum HyphenationConsistency {
    typealias Word = ConsistencyChecker.Word

    static func issues(in words: [Word]) -> [TextIssue] {
        var groups: [String: [Word]] = [:]
        for word in words where word.text.contains(where: isHyphen) || word.text.count >= 4 {
            let key = String(word.text.lowercased().filter { !isHyphen($0) })
            groups[key, default: []].append(word)
        }
        var issues: [TextIssue] = []
        for group in groups.values where group.contains(where: { $0.text.contains(where: isHyphen) }) {
            let forms = group.map { $0.text.lowercased() }
            guard let majority = ConsistencyChecker.strictMajority(forms) else { continue }
            for word in group where word.text.lowercased() != majority {
                let replacement = ConsistencyChecker.matchingCase(of: word.text, majority)
                let message = majority.contains(where: isHyphen)
                    ? "Elsewhere you write “\(majority)” with a hyphen. Write it the same way throughout."
                    : "Elsewhere you write “\(majority)” without a hyphen. Write it the same way throughout."
                issues.append(ConsistencyChecker.issue(word, replacement: replacement, message: message, category: .wordChoice))
            }
        }
        return issues
    }

    private static func isHyphen(_ character: Character) -> Bool {
        character == "-" || character == "\u{2010}"
    }
}
