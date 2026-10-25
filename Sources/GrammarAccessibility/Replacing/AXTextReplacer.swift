import AppKit
import ApplicationServices
import GrammarModels

final class AXTextReplacer {
    static let selectionConfirmationTimeout: Duration = .milliseconds(150)
    static let axWriteVerificationTimeout: Duration = .milliseconds(300)
    static let pasteVerificationTimeout: Duration = .milliseconds(400)

    private var axWritesIgnored = false

    func replace(_ range: NSRange, with replacement: String, in field: AXTextFieldHandle) -> Bool {
        guard let text = field.readText() else {
            Log.accessibility.info("Replace failed in \(field.logName, privacy: .public): field unreadable")
            return false
        }
        guard let plan = ReplacementPlan(text: text, range: range, replacement: replacement) else {
            Log.accessibility.info("Replace failed in \(field.logName, privacy: .public): range \(NSStringFromRange(range), privacy: .public) invalid for length \((text as NSString).length, privacy: .public)")
            return false
        }
        guard selectAndConfirm(plan.range, in: field) else {
            Log.accessibility.info("Replace failed in \(field.logName, privacy: .public): couldn't select the range")
            return false
        }

        if !axWritesIgnored {
            switch writeThroughAccessibility(plan, replacement: replacement, in: field) {
            case .applied: return true
            case .diverged, .unreadable: return false
            case .unchanged: guard selectAndConfirm(plan.range, in: field) else { return false }
            }
        }
        return paste(plan, replacement: replacement, in: field)
    }

    private func writeThroughAccessibility(_ plan: ReplacementPlan, replacement: String, in field: AXTextFieldHandle) -> ReplacementOutcome {
        let writeError = field.element.setString(kAXSelectedTextAttribute, replacement)
        let mightHaveWritten = [AXError.success, .cannotComplete, .failure].contains(writeError)
        let outcome = waitForOutcome(of: plan, in: field, timeout: mightHaveWritten ? Self.axWriteVerificationTimeout : .zero)
        switch outcome {
        case .applied:
            finish(plan, in: field)
            Log.accessibility.debug("Replaced via AX in \(field.logName, privacy: .public)")
        case .diverged, .unreadable:
            Log.accessibility.info("AX write in \(field.logName, privacy: .public) gave unexpected text (\(writeError.logName, privacy: .public)); not retrying")
        case .unchanged:
            axWritesIgnored = true
            Log.accessibility.info("AX write ignored by \(field.logName, privacy: .public) (\(writeError.logName, privacy: .public)); pasting instead")
        }
        return outcome
    }

    private func paste(_ plan: ReplacementPlan, replacement: String, in field: AXTextFieldHandle) -> Bool {
        let paste = PasteController.shared
        guard paste.paste(replacement, intoProcess: field.processID) else { return false }
        let outcome = waitForOutcome(of: plan, in: field, timeout: Self.pasteVerificationTimeout)
        paste.scheduleRestore()
        guard outcome == .applied else {
            Log.accessibility.info("Paste fallback in \(field.logName, privacy: .public) not verified (\(String(describing: outcome), privacy: .public))")
            return false
        }
        finish(plan, in: field)
        Log.accessibility.debug("Replaced via paste in \(field.logName, privacy: .public)")
        return true
    }

    private func selectAndConfirm(_ range: NSRange, in field: AXTextFieldHandle) -> Bool {
        let error = field.element.setRange(kAXSelectedTextRangeAttribute, range)
        if error.isUnsupported || error == .invalidUIElement || error == .illegalArgument { return false }
        let deadline = ContinuousClock.now + Self.selectionConfirmationTimeout
        while true {
            if let selection = field.selectedRange() {
                if selection == range { return true }
            } else if error == .success {
                return true
            }
            if ContinuousClock.now >= deadline { return false }
            usleep(15_000)
        }
    }

    private func waitForOutcome(of plan: ReplacementPlan, in field: AXTextFieldHandle, timeout: Duration) -> ReplacementOutcome {
        let deadline = ContinuousClock.now + timeout
        var outcome = plan.outcome(for: field.readText())
        while outcome != .applied, ContinuousClock.now < deadline {
            usleep(20_000)
            outcome = plan.outcome(for: field.readText())
        }
        return outcome
    }

    private func finish(_ plan: ReplacementPlan, in field: AXTextFieldHandle) {
        _ = field.element.setRange(kAXSelectedTextRangeAttribute, plan.caretAfter)
        field.invalidateGeometry()
    }
}
