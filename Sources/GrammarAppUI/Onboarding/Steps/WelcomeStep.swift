import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(symbol: "text.badge.checkmark", title: "Welcome to Grammar Review")
            Text("Grammar Review checks your writing in any app (Mail, Notes, Safari, Slack and more) and underlines mistakes right where you type. Hover over an underline to see the fix and apply it with one click.")
                .fixedSize(horizontal: false, vertical: true)
            Bullet(symbol: "textformat.abc.dottedunderline", title: "Spelling, on this Mac", detail: "Instant, offline, in every language macOS has a dictionary for.")
            Bullet(symbol: "sparkles", title: "Grammar, clarity and style with AI", detail: "Optional. Uses Claude with your own Anthropic API key, or a model running on your Mac.")
            Bullet(symbol: "lock.shield", title: "Private by design", detail: PrivacyText.summary)
        }
    }
}
