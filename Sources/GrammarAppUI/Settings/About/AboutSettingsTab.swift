import AppKit
import SwiftUI

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Grammar Review")
                .font(.title.bold())
            Text(AppVersion.current)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Spelling, grammar and style suggestions in any app, right where you type.")
                .multilineTextAlignment(.center)
            Text(PrivacyText.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .fixedSize(horizontal: false, vertical: true)
            if let copyright = AppVersion.copyright {
                Text(copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
