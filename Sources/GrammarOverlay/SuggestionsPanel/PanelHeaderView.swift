import GrammarModels
import SwiftUI

struct PanelHeaderView: View {
    static let leadingPadding: CGFloat = 14
    static let trailingPadding: CGFloat = 8
    static let textTrailingPadding: CGFloat = 6

    let model: PanelModel
    let actions: OverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            if model.tone != nil || model.isDetectingTone {
                PanelToneRow(tone: model.tone, isDetecting: model.isDetectingTone)
                    .padding(.trailing, Self.textTrailingPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.offersRewrite {
                PanelRewriteRow(model: model, rewrite: actions.rewriteText)
                    .padding(.top, 2)
            }
        }
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, Self.trailingPadding)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Divider() }
        .frame(width: model.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(IssueSummary.title(forCount: model.issues.count))
                .font(.system(size: 13, weight: .semibold))
            if model.isChecking {
                Spinner(size: 10, lineWidth: 1.25)
            }
            Spacer(minLength: 4)
            let fixAll = model.fixAllCount
            if fixAll > 0 {
                Button("Fix all (\(fixAll))") { actions.fixAll() }
                    .buttonStyle(PillButtonStyle(kind: .primary))
            }
            Button {
                actions.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Settings")
        }
    }
}
