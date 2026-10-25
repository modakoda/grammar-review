import AppKit
import ApplicationServices
import GrammarModels

final class AppCompatibilityFixer {
    static let chromiumProbeDelay: Duration = .seconds(1)
    static let maxProbeAttempts = 3

    var isObserving: (AppObservation) -> Bool = { _ in false }
    var webContentDidAppear: (AppObservation) -> Void = { _ in }

    func apply(to observation: AppObservation) {
        let name = observation.bundleID ?? "pid \(observation.pid)"
        if observation.compatibility.manualAccessibility == nil {
            let error = observation.app.setBool(AXName.manualAccessibility, true)
            guard error != .cannotComplete else { return }
            let result: ManualAccessibilityResult = switch error {
            case .success: .applied
            case _ where error.isUnsupported || error == .illegalArgument: .unsupported
            default: .failed
            }
            observation.compatibility.manualAccessibility = result
            if result == .applied || observation.family != .native {
                Log.accessibility.info("AXManualAccessibility on \(name, privacy: .public): \(result.rawValue, privacy: .public) (\(error.logName, privacy: .public))")
            }
        }

        guard observation.family == .chromium,
              !observation.compatibility.enhancedUserInterfaceAttempted,
              let manual = observation.compatibility.manualAccessibility
        else { return }

        if AppCompatibility.needsEnhancedUserInterface(family: observation.family, manual: manual, probe: nil) {
            enableEnhancedUserInterface(on: observation, reason: "manual accessibility \(manual.rawValue)")
            return
        }
        scheduleWebContentProbe(on: observation, manual: manual)
    }

    func undo(on observation: AppObservation) {
        if observation.compatibility.enhancedUserInterfaceEnabled {
            observation.app.setBool(AXName.enhancedUserInterface, false)
        }
    }

    private func scheduleWebContentProbe(on observation: AppObservation, manual: ManualAccessibilityResult) {
        let probe = observation.compatibility.probe
        guard probe == nil || probe == .unknown, !observation.compatibility.probeScheduled,
              observation.compatibility.probeAttempts < Self.maxProbeAttempts
        else { return }
        observation.compatibility.probeScheduled = true
        observation.compatibility.probeAttempts += 1

        let name = observation.bundleID ?? "pid \(observation.pid)"
        Task { @MainActor [weak self, weak observation] in
            try? await Task.sleep(for: Self.chromiumProbeDelay)
            guard let self, let observation, self.isObserving(observation) else { return }
            observation.compatibility.probeScheduled = false
            let probe = WebContentProber.probe(app: observation.app)
            observation.compatibility.probe = probe
            Log.accessibility.info("Chromium web content in \(name, privacy: .public): \(probe.rawValue, privacy: .public)")
            if AppCompatibility.needsEnhancedUserInterface(family: observation.family, manual: manual, probe: probe) {
                self.enableEnhancedUserInterface(on: observation, reason: "web content not exposed")
                self.webContentDidAppear(observation)
            }
        }
    }

    private func enableEnhancedUserInterface(on observation: AppObservation, reason: String) {
        let error = observation.app.setBool(AXName.enhancedUserInterface, true)
        observation.compatibility.enhancedUserInterfaceAttempted = true
        observation.compatibility.enhancedUserInterfaceEnabled = error == .success
        Log.accessibility.info("AXEnhancedUserInterface on \(observation.bundleID ?? "?", privacy: .public) (\(reason, privacy: .public)): \(error.logName, privacy: .public)")
    }
}
