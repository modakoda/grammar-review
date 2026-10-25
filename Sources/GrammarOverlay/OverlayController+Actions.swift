import AppKit
import GrammarModels

extension OverlayController {
    func makeActions() -> OverlayActions {
        OverlayActions(
            accept: { [weak self] replacement, issue in
                guard let self else { return }
                self.closeCard(ifShowing: issue)
                self.delegate?.presenter(didAccept: replacement, for: issue)
            },
            ignore: { [weak self] issue in
                guard let self else { return }
                self.closeCard(ifShowing: issue)
                self.delegate?.presenter(didIgnore: issue)
            },
            restore: { [weak self] issue in
                self?.delegate?.presenter(didRestore: issue)
            },
            addToDictionary: { [weak self] issue in
                guard let self else { return }
                self.closeCard(ifShowing: issue)
                self.delegate?.presenter(didAddToDictionary: issue)
            },
            fixAll: { [weak self] in
                self?.delegate?.presenterDidRequestFixAll()
            },
            openSettings: { [weak self] in
                guard let self else { return }
                self.closePanel()
                self.delegate?.presenterDidRequestSettings()
            },
            disableForCurrentApp: { [weak self] in
                guard let self else { return }
                self.closePanel()
                self.delegate?.presenterDidRequestDisableForCurrentApp()
            },
            setBadgePlacement: { [weak self] placement, kind in
                self?.delegate?.presenter(didChooseBadgePlacement: placement, for: kind)
            },
            setBadgeSpacing: { [weak self] spacing in
                self?.delegate?.presenter(didChooseBadgeSpacing: spacing)
            },
            openBadgeSettings: { [weak self] in
                guard let self else { return }
                self.closePanel()
                self.delegate?.presenterDidRequestBadgeSettings()
            },
            toggleSuggestions: { [weak self] in
                self?.togglePanel()
            },
            requestRewrite: { [weak self] tone in
                self?.delegate?.presenter(didRequestRewriteWith: tone)
            },
            rephraseSentence: { [weak self] in self?.rephraseSentence(of: $0) },
            rewriteText: { [weak self] in self?.delegate?.presenter(didRequestRewriteOf: $0, tone: $1) },
            requestInstructionRewrite: { [weak self] instruction in
                guard let self else { return }
                self.rewriteCard.giveUpKeyboard()
                self.delegate?.presenter(didRequestRewriteWithInstruction: instruction)
            },
            acceptRewrite: { [weak self] in self?.acceptRewrite($0) },
            cancelRewrite: { [weak self] in
                guard let self else { return }
                self.rewriteCard.dismiss()
                self.delegate?.presenterDidCancelRewrite()
            },
            requestCompose: { [weak self] request, usesContext in
                self?.delegate?.presenter(didRequestCompose: request, usesContext: usesContext)
            },
            acceptCompose: { [weak self] in self?.acceptCompose($0) },
            cancelCompose: { [weak self] in
                guard let self else { return }
                self.composeCard.dismiss()
                self.delegate?.presenterDidCancelCompose()
            }
        )
    }

    private func rephraseSentence(of issue: TextIssue) {
        closeCard(ifShowing: issue)
        delegate?.presenter(didRequestRephraseSentenceOf: issue)
    }

    private func acceptRewrite(_ text: String) {
        let hadKeyboard = rewriteCard.hasKeyboard
        rewriteCard.dismiss()
        afterKeyboardReturns(hadKeyboard) { [weak self] in self?.delegate?.presenter(didAcceptRewrite: text) }
    }

    private func acceptCompose(_ text: String) {
        let hadKeyboard = composeCard.hasKeyboard
        composeCard.dismiss()
        afterKeyboardReturns(hadKeyboard) { [weak self] in self?.delegate?.presenter(didAcceptCompose: text) }
    }

    private func afterKeyboardReturns(_ hadKeyboard: Bool, _ action: @escaping @MainActor () -> Void) {
        guard hadKeyboard else { return action() }
        Task { @MainActor in
            try? await Task.sleep(for: OverlayMetrics.keyboardReturnDelay)
            action()
        }
    }
}
