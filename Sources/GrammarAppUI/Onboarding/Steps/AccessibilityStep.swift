import SwiftUI

struct AccessibilityStep: View {
    let isTrusted: Bool
    let repairState: PermissionRepairState
    let openSystemSettings: () -> Void
    let resetPermission: () -> Void
    let relaunch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(symbol: "accessibility", title: "Allow Accessibility access")
            Text("macOS asks you to approve apps that work with text in other apps. Grammar Review needs this permission to read the field you're typing in, place underlines on the right words and apply the fixes you accept.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Click **Open System Settings**, then turn on **Grammar Review** under Privacy & Security → Accessibility.")
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Open System Settings", action: openSystemSettings)
                    .controlSize(.large)
                if isTrusted {
                    Label("Permission granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                } else {
                    ProgressView().controlSize(.small)
                    Text("Waiting for permission…")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)
            if !isTrusted {
                StillWaitingHelp(repairState: repairState, resetPermission: resetPermission, relaunch: relaunch)
            }
        }
    }
}

struct StillWaitingHelp: View {
    let repairState: PermissionRepairState
    let resetPermission: () -> Void
    let relaunch: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Switched it on, but still waiting?")
                    .font(.headline)
                Text("macOS may be holding on to the permission of an older copy of Grammar Review. Reset it, then switch Grammar Review on again in the list.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Reset Permission", action: resetPermission)
                    Button("Relaunch App", action: relaunch)
                }
                switch repairState {
                case .idle:
                    EmptyView()
                case .resetDone:
                    Label("Reset. Now switch on Grammar Review in System Settings.", systemImage: "arrow.uturn.backward.circle")
                        .font(.callout)
                case .resetFailed:
                    Text("The reset didn't work. In System Settings, select Grammar Review, click − to remove it, then click **Open System Settings** here and switch it on again.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
