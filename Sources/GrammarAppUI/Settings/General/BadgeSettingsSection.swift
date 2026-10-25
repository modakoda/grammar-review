import GrammarModels
import SwiftUI

struct BadgeSettingsSection: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Section {
            Toggle("Show the badge next to the text field", isOn: $store.settings.showBadge)
            ForEach(FieldKind.allCases) { kind in
                Picker(kind.displayName, selection: placementBinding(kind)) {
                    Text(BadgePlacement.automatic.displayName).tag(BadgePlacement.automatic)
                    Divider()
                    ForEach(BadgePlacement.allCases.filter(\.isInside)) { placement in
                        Text(placement.displayName).tag(placement)
                    }
                    Divider()
                    ForEach(BadgePlacement.allCases.filter { !$0.isInside && $0 != .automatic }) { placement in
                        Text(placement.displayName).tag(placement)
                    }
                }
                .disabled(!store.settings.showBadge)
                Text(store.settings.badgePlacement(for: kind).detail(for: kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Distance from the field") {
                HStack {
                    Slider(value: $store.settings.badgeSpacing, in: AppSettings.badgeSpacingRange, step: 1)
                        .frame(minWidth: 160)
                    Text("\(Int(store.settings.badgeSpacing)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .disabled(!store.settings.showBadge || FieldKind.allCases.allSatisfy { store.settings.badgePlacement(for: $0).isInside })
            .help("The space between the badge and the field when the badge sits outside the field.")
        } header: {
            Text("Badge")
        } footer: {
            Text("Right-click the badge to change these on the spot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func placementBinding(_ kind: FieldKind) -> Binding<BadgePlacement> {
        Binding(
            get: { store.settings.badgePlacement(for: kind) },
            set: { placement in store.update { $0.setBadgePlacement(placement, for: kind) } }
        )
    }
}
