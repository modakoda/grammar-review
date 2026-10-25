import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarAppUI

@MainActor
@Suite struct OnboardingModelTests {
    private final class Counter {
        var value = 0
    }

    private func makeModel(
        defaults: UserDefaults,
        backend: InMemorySecretBackend = InMemorySecretBackend(),
        trusted: @escaping () -> Bool = { false },
        counter: Counter
    ) -> OnboardingModel {
        OnboardingModel(
            store: SettingsStore(defaults: defaults),
            keyModel: APIKeyEditorModel(keyStore: makeKeyStore(backend: backend), validate: FakeValidator().validate),
            permissionCheck: trusted,
            onFinish: { counter.value += 1 }
        )
    }

    @Test func finishMarksOnboardingCompleteAndReportsOnce() async {
        await withTemporaryDefaults { defaults in
            let counter = Counter()
            let model = makeModel(defaults: defaults, counter: counter)
            model.step = .done

            model.finish()
            model.windowClosed()
            #expect(counter.value == 1)
            #expect(model.store.settings.hasCompletedOnboarding)
            #expect(SettingsStore(defaults: defaults).settings.hasCompletedOnboarding)
        }
    }

    @Test func closingEarlyReportsOnceWithoutCompleting() async {
        await withTemporaryDefaults { defaults in
            let counter = Counter()
            let model = makeModel(defaults: defaults, counter: counter)
            model.next()
            #expect(model.step == .accessibility)

            model.windowClosed()
            model.windowClosed()
            model.finish()
            #expect(counter.value == 1)
            #expect(!model.store.settings.hasCompletedOnboarding)
        }
    }

    @Test func closingOnTheLastStepCountsAsFinishing() async {
        await withTemporaryDefaults { defaults in
            let counter = Counter()
            let model = makeModel(defaults: defaults, counter: counter)
            model.step = .done
            model.windowClosed()
            #expect(counter.value == 1)
            #expect(model.store.settings.hasCompletedOnboarding)
        }
    }

    @Test func showingAgainStartsANewPresentation() async {
        await withTemporaryDefaults { defaults in
            let counter = Counter()
            let model = makeModel(defaults: defaults, counter: counter)
            model.step = .apiKey
            model.keyModel.draft = "sk-ant-leftover"
            model.windowClosed()

            model.restart()
            #expect(model.step == .welcome)
            #expect(model.keyModel.draft.isEmpty)
            #expect(!model.hasFinished)
            model.windowClosed()
            #expect(counter.value == 2)
        }
    }

    @Test func navigationStaysInRange() async {
        await withTemporaryDefaults { defaults in
            let model = makeModel(defaults: defaults, counter: Counter())
            model.back()
            #expect(model.step == .welcome)
            #expect(model.isFirstStep)
            for _ in 0..<10 { model.next() }
            #expect(model.step == .done)
            model.back()
            #expect(model.step == .apiKey)
        }
    }

    @Test func detectsThePermissionGrant() async {
        await withTemporaryDefaults { defaults in
            var trusted = false
            let model = makeModel(defaults: defaults, trusted: { trusted }, counter: Counter())
            #expect(!model.isTrusted)
            #expect(!model.refreshPermission())

            trusted = true
            #expect(model.refreshPermission())
            #expect(model.isTrusted)
            #expect(!model.refreshPermission())

            trusted = false
            #expect(!model.refreshPermission())
            #expect(!model.isTrusted)
        }
    }

    @Test func savingTheKeyMovesOn() async {
        await withTemporaryDefaults { defaults in
            let backend = InMemorySecretBackend()
            let model = makeModel(defaults: defaults, backend: backend, counter: Counter())
            model.step = .apiKey
            model.keyModel.draft = "sk-ant-onboarding"

            model.saveKeyAndContinue()
            #expect(backend.secret == "sk-ant-onboarding")
            #expect(model.step == .done)
        }
    }

    @Test func aFailedSaveStaysOnTheStep() async {
        await withTemporaryDefaults { defaults in
            let backend = InMemorySecretBackend()
            backend.writeError = KeychainError(status: -25_291)
            let model = makeModel(defaults: defaults, backend: backend, counter: Counter())
            model.step = .apiKey
            model.keyModel.draft = "sk-ant-onboarding"

            model.saveKeyAndContinue()
            #expect(model.step == .apiKey)
            #expect(model.keyModel.saveError != nil)
        }
    }

    @Test func skippingWithoutAKeyMovesOn() async {
        await withTemporaryDefaults { defaults in
            let backend = InMemorySecretBackend()
            let model = makeModel(defaults: defaults, backend: backend, counter: Counter())
            model.step = .apiKey
            model.saveKeyAndContinue()
            #expect(model.step == .done)
            #expect(backend.secret == nil)
        }
    }
}
