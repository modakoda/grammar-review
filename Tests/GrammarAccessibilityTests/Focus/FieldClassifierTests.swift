import Testing
@testable import GrammarAccessibility

@Suite("Checkable field detection")
struct FieldClassifierTests {
    private func classify(_ snapshot: FieldSnapshot) -> FieldDecision {
        FieldClassifier.classify(snapshot)
    }

    @Test(arguments: ["AXTextArea", "AXTextField", "AXComboBox"])
    func editableTextRolesAreAccepted(role: String) {
        let snapshot = FieldSnapshot(role: role, isEnabled: true, isValueSettable: true, isSelectedTextSettable: true)
        #expect(classify(snapshot) == .accept(.focusedElement))
    }

    @Test func searchFieldIsAccepted() {
        let snapshot = FieldSnapshot(role: "AXTextField", subrole: "AXSearchField", isEnabled: true, isValueSettable: true)
        #expect(classify(snapshot) == .accept(.focusedElement))
    }

    @Test func textRoleWithUnknownSettabilityIsAccepted() {
        #expect(classify(FieldSnapshot(role: "AXTextArea")) == .accept(.focusedElement))
    }

    @Test func textAreaWithSettableSelectionButNotValueIsAccepted() {
        let snapshot = FieldSnapshot(role: "AXTextArea", isValueSettable: false, isSelectedTextSettable: true)
        #expect(classify(snapshot) == .accept(.focusedElement))
    }

    @Test func customElementWithSettableStringValueIsAccepted() {
        let snapshot = FieldSnapshot(role: "AXGroup", isEnabled: true, isValueSettable: true, valueIsString: true)
        #expect(classify(snapshot) == .accept(.focusedElement))
    }

    @Test func staticTextInsideContentEditableUsesEditableAncestor() {
        let root = FieldSnapshot(role: "AXTextArea", isValueSettable: true)
        let snapshot = FieldSnapshot(role: "AXStaticText", ancestors: [FieldAncestor(.editable, root)])
        #expect(classify(snapshot) == .accept(.ancestor(.editable)))
    }

    @Test func highestEditableAncestorIsUsedWhenNoNearestOne() {
        let snapshot = FieldSnapshot(role: "AXGroup", ancestors: [FieldAncestor(.highestEditable, FieldSnapshot(role: "AXWebArea"))])
        #expect(classify(snapshot) == .accept(.ancestor(.highestEditable)))
    }

    @Test func nearestEditableAncestorWinsOverHighest() {
        let snapshot = FieldSnapshot(role: "AXGroup", ancestors: [
            FieldAncestor(.highestEditable, FieldSnapshot(role: "AXGroup")),
            FieldAncestor(.editable, FieldSnapshot(role: "AXTextArea")),
        ])
        #expect(classify(snapshot) == .accept(.ancestor(.editable)))
    }

    @Test func focusableAncestorCountsOnlyWhenEditable() {
        let editable = FieldSnapshot(role: "AXGroup", ancestors: [
            FieldAncestor(.focusable, FieldSnapshot(role: "AXTextArea", isValueSettable: true)),
        ])
        #expect(classify(editable) == .accept(.ancestor(.focusable)))

        let link = FieldSnapshot(role: "AXStaticText", ancestors: [
            FieldAncestor(.focusable, FieldSnapshot(role: "AXLink", isValueSettable: false)),
        ])
        #expect(classify(link) == .reject(.notEditable))
    }

    @Test func secureSubroleIsRejectedEvenWhenEditable() {
        let snapshot = FieldSnapshot(role: "AXTextField", subrole: "AXSecureTextField", isEnabled: true, isValueSettable: true)
        #expect(classify(snapshot) == .reject(.secure))
    }

    @Test func secureRoleIsRejected() {
        #expect(classify(FieldSnapshot(role: "AXSecureTextField", isValueSettable: true)) == .reject(.secure))
    }

    @Test func secureRoleDescriptionIsRejected() {
        let snapshot = FieldSnapshot(role: "AXTextField", roleDescription: "secure text field", isValueSettable: true)
        #expect(classify(snapshot) == .reject(.secure))
    }

    @Test(arguments: ["password", "Enter your passcode", "Slaptažodis", "user-password-input"])
    func passwordLabelsOnSingleLineFieldsAreRejected(hint: String) {
        let snapshot = FieldSnapshot(role: "AXTextField", isValueSettable: true, hints: [hint.lowercased()])
        #expect(classify(snapshot) == .reject(.secure))
    }

    @Test func passwordWordInTextAreaLabelIsFine() {
        let snapshot = FieldSnapshot(role: "AXTextArea", isValueSettable: true, hints: ["explain why you need a new password"])
        #expect(classify(snapshot) == .accept(.focusedElement))
    }

    @Test func secureAncestorIsRejected() {
        let snapshot = FieldSnapshot(role: "AXStaticText", ancestors: [
            FieldAncestor(.editable, FieldSnapshot(role: "AXTextField", subrole: "AXSecureTextField")),
        ])
        #expect(classify(snapshot) == .reject(.secure))
    }

    @Test func secureInputInTheAppRejectsTransiently() {
        let snapshot = FieldSnapshot(role: "AXTextArea", isValueSettable: true, secureInputActive: true)
        let decision = classify(snapshot)
        #expect(decision == .reject(.secureInput))
        #expect(decision.isTransient)
    }

    @Test func secureInputDoesNotMatterForNonTextElements() {
        let snapshot = FieldSnapshot(role: "AXButton", secureInputActive: true)
        #expect(classify(snapshot) == .reject(.notEditable))
    }

    @Test func readOnlyTextViewIsRejected() {
        let snapshot = FieldSnapshot(role: "AXTextArea", isEnabled: true, isValueSettable: false, isSelectedTextSettable: false)
        #expect(classify(snapshot) == .reject(.notEditable))
    }

    @Test func disabledFieldIsRejected() {
        let snapshot = FieldSnapshot(role: "AXTextField", isEnabled: false, isValueSettable: true)
        #expect(classify(snapshot) == .reject(.disabled))
    }

    @Test(arguments: ["AXButton", "AXSlider", "AXCheckBox", "AXStaticText", "AXWebArea", "AXWindow"])
    func nonTextElementsAreRejected(role: String) {
        let snapshot = FieldSnapshot(role: role, isEnabled: true, isValueSettable: true, valueIsString: role == "AXButton")
        #expect(classify(snapshot) == .reject(.notEditable))
    }

    @Test func settableNonStringValueIsRejected() {
        let snapshot = FieldSnapshot(role: "AXGroup", isValueSettable: true, valueIsString: false)
        #expect(classify(snapshot) == .reject(.notEditable))
    }

    @Test func goneElementIsRejected() {
        let decision = classify(FieldSnapshot(readFailure: .gone))
        #expect(decision == .reject(.noElement))
        #expect(!decision.isTransient)
    }

    @Test func unresponsiveAppIsRetried() {
        let decision = classify(FieldSnapshot(readFailure: .unresponsive))
        #expect(decision == .reject(.unresponsive))
        #expect(decision.isTransient)
    }

    @Test func disabledEditableAncestorIsIgnored() {
        let snapshot = FieldSnapshot(role: "AXStaticText", ancestors: [
            FieldAncestor(.editable, FieldSnapshot(role: "AXTextArea", isEnabled: false)),
        ])
        #expect(classify(snapshot) == .reject(.notEditable))
    }
}
