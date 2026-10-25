import AppKit
import GrammarModels
import SwiftUI

package struct ReplacementButtonStyle: ButtonStyle {
    var prominent: Bool
    var tint: Color

    package init(prominent: Bool, tint: Color) {
        self.prominent = prominent
        self.tint = tint
    }

    package func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(prominent ? tint.opacity(configuration.isPressed ? 0.26 : 0.16) : Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            }
            .overlay {
                if prominent {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

package struct PillButtonStyle: ButtonStyle {
    package enum Kind {
        case primary
        case secondary
    }

    var kind: Kind

    package init(kind: Kind) {
        self.kind = kind
    }

    package func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, kind: kind)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .foregroundStyle(kind == .primary ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    Capsule().fill(fill)
                }
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Capsule())
        }

        private var fill: Color {
            switch kind {
            case .primary: Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1)
            case .secondary: Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08)
            }
        }
    }
}

package struct LinkButtonStyle: ButtonStyle {
    package init() {}

    package func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background {
                Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0))
            }
            .contentShape(Circle())
    }
}

struct TapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
