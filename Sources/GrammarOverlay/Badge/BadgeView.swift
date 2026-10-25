import AppKit
import GrammarModels
import SwiftUI

struct BadgeView: View {
    let model: BadgeModel
    let actions: OverlayActions

    private let diameter = OverlayMetrics.badgeDiameter

    var body: some View {
        let appearance = model.appearance
        Button {
            actions.toggleSuggestions()
        } label: {
            ZStack {
                Circle()
                    .fill(fill(for: appearance.tint))
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(appearance.tint == .neutral ? 0.15 : 0), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: -0.5)
                glyph(appearance.glyph)
                if appearance.showsActivityRing {
                    Spinner(size: diameter + 5, lineWidth: 1.5, color: fill(for: appearance.tint).opacity(0.6), arc: 0.3)
                }
            }
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .topTrailing) {
                if appearance.showsWarningDot {
                    Circle()
                        .fill(Color(nsColor: .systemOrange))
                        .frame(width: 8, height: 8)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 1) }
                        .offset(x: 2, y: -2)
                }
            }
            .padding(OverlayMetrics.badgePadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(BadgeButtonStyle())
        .accessibilityLabel(appearance.tooltip)
    }

    @ViewBuilder
    private func glyph(_ glyph: BadgeAppearance.Glyph) -> some View {
        switch glyph {
        case .count(let text):
            Text(text)
                .font(.system(size: text.count >= 3 ? 8 : (text.count == 2 ? 10 : 11), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        case .spinner:
            Spinner(size: 11, lineWidth: 1.5, color: .secondary)
        case .warning:
            Image(systemName: "exclamationmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    private func fill(for tint: BadgeAppearance.Tint) -> Color {
        switch tint {
        case .severity(let severity): severity.color
        case .success: Color(nsColor: .systemGreen)
        case .neutral: Color(nsColor: .windowBackgroundColor)
        case .warning: Color(nsColor: .systemOrange)
        }
    }
}

private struct BadgeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
