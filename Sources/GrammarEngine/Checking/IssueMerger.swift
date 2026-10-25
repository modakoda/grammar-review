import Foundation
import GrammarModels

enum IssueMerger {
    static func merge(local: [TextIssue], ai: [TextIssue], settings: AppSettings) -> [TextIssue] {
        let styleGuide = local.filter { $0.source == .styleGuide }
        func overlapsStyleGuide(_ issue: TextIssue) -> Bool {
            styleGuide.contains { TextUnits.overlaps($0.range, issue.range) }
        }
        var aiIssues = ai.filter { !overlapsStyleGuide($0) }
        var keptLocal = styleGuide
        for issue in local where issue.source != .styleGuide && !overlapsStyleGuide(issue) {
            let overlapping = aiIssues.indices.filter { TextUnits.overlaps(aiIssues[$0].range, issue.range) }
            guard !overlapping.isEmpty else {
                keptLocal.append(issue)
                continue
            }
            guard issue.category == .spelling else { continue }
            for index in overlapping where aiIssues[index].category == .spelling && aiIssues[index].range == issue.range {
                aiIssues[index].replacements = deduplicated(aiIssues[index].replacements + issue.replacements)
            }
        }

        var seenRanges = Set<RangeKey>()
        let merged = (aiIssues + keptLocal).filter { issue in
            guard settings.enabledCategories.contains(issue.category) else { return false }
            if issue.category == .spelling, settings.isInPersonalDictionary(issue.originalText.trimmedWhitespace) {
                return false
            }
            return seenRanges.insert(RangeKey(issue.range)).inserted
        }
        return merged.sorted { lhs, rhs in
            (lhs.range.location, lhs.range.length) < (rhs.range.location, rhs.range.length)
        }
    }

    static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private struct RangeKey: Hashable {
        let location: Int
        let length: Int
        init(_ range: NSRange) {
            location = range.location
            length = range.length
        }
    }
}
