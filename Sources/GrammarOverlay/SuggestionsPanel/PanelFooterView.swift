import GrammarModels
import SwiftUI

struct PanelFooterView: View {
    let model: PanelModel
    let actions: OverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = model.aiUnavailableMessage {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .systemOrange))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Settings") { actions.openSettings() }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                }
            }
            Button(IssueSummary.disableTitle(appName: model.appName)) { actions.disableForCurrentApp() }
                .buttonStyle(LinkButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: model.width, alignment: .leading)
        .overlay(alignment: .top) { Divider() }
        .fixedSize(horizontal: false, vertical: true)
    }
}
