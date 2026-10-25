import AppKit
import GrammarModels
import SwiftUI

struct EditorView: View {
    let model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(model: model)
            Divider()
            HStack(spacing: 0) {
                EditorTextArea(model: model)
                    .overlay(alignment: .topLeading) {
                        if model.text.isEmpty {
                            Text("Type or paste your text here.")
                                .font(Font(EditorTextView.font))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, EditorTextView.inset.width + 5)
                                .padding(.top, EditorTextView.inset.height)
                                .allowsHitTesting(false)
                        }
                    }
                Divider()
                EditorSidebar(model: model)
                    .frame(width: 340)
            }
        }
    }
}
