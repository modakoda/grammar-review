import SwiftUI

struct DoneStep: View {
    let isTrusted: Bool

    static func explanation(for hotkey: Hotkey) -> String {
        switch hotkey {
        case .showSuggestions: "Show all suggestions for the field you're typing in"
        case .rewriteSelection: "Rewrite the selected text, or rephrase the sentence at the cursor, in another style"
        case .writeWithAI: "Draft new text where you're typing, from a short request"
        case .openEditor: "Open the editor to write and polish longer text"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(symbol: "checkmark.seal.fill", title: "You're all set", tint: .green)
            Text("Start typing in any app. Grammar Review underlines what it finds; hover over an underline, or click the badge next to the field, to see suggestions.")
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(Hotkey.allCases, id: \.self) { hotkey in
                    GridRow {
                        Text(hotkey.displayString)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                        Text(Self.explanation(for: hotkey))
                    }
                }
                GridRow {
                    Image(systemName: "text.badge.checkmark")
                        .padding(.horizontal, 8)
                    Text("Menu bar: pause checking, turn it off for an app, open Settings")
                }
            }
            .padding(.vertical, 4)

            if !isTrusted {
                Label("Accessibility permission is still missing, so Grammar Review can't check text yet. Open the Setup Guide from the menu bar icon to grant it.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
