import AppKit
import GrammarModels
import GrammarOverlay
import SwiftUI

struct EditorTextArea: NSViewRepresentable {
    let model: EditorModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = EditorTextView.makeScrollable()
        textView.string = model.text
        textView.delegate = context.coordinator
        model.surface = textView
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}

    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: EditorModel

        init(model: EditorModel) {
            self.model = model
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            model.textDidChange(textView.string, selection: textView.selectedRange())
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            model.selectionDidChange(textView.selectedRange(), in: textView.string)
        }
    }
}
