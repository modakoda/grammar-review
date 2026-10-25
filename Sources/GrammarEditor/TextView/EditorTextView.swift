import AppKit
import GrammarModels
import GrammarOverlay
import SwiftUI

final class EditorTextView: NSTextView, EditorTextSurface {
    static let font = NSFont.systemFont(ofSize: 15)
    static let inset = NSSize(width: 22, height: 18)

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.25
        return style
    }()

    static func makeScrollable() -> (NSScrollView, EditorTextView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = EditorTextView(usingTextLayoutManager: false)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = inset
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: NSColor.textColor]
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.setAccessibilityLabel("Text")

        scrollView.documentView = textView
        return (scrollView, textView)
    }

    @discardableResult
    func replaceText(in range: NSRange, with replacement: String) -> Bool {
        let length = (string as NSString).length
        guard NSMaxRange(range) <= length, shouldChangeText(in: range, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: range, with: NSAttributedString(string: replacement, attributes: typingAttributes))
        didChangeText()
        return true
    }

    func reveal(_ range: NSRange) {
        guard NSMaxRange(range) <= (string as NSString).length else { return }
        scrollRangeToVisible(range)
        showFindIndicator(for: range)
    }

    func decorate(_ decorations: EditorDecorations) {
        guard let layoutManager else { return }
        let length = (string as NSString).length
        let everything = NSRange(location: 0, length: length)
        for key in [NSAttributedString.Key.underlineStyle, .underlineColor, .backgroundColor] {
            layoutManager.removeTemporaryAttribute(key, forCharacterRange: everything)
        }

        func valid(_ range: NSRange) -> Bool { range.length > 0 && NSMaxRange(range) <= length }

        for sentence in decorations.longSentences where valid(sentence) {
            layoutManager.addTemporaryAttribute(
                .backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.2), forCharacterRange: sentence
            )
        }
        if let target = decorations.rewriteTarget, valid(target) {
            layoutManager.addTemporaryAttribute(
                .backgroundColor, value: NSColor.controlAccentColor.withAlphaComponent(0.12), forCharacterRange: target
            )
        }
        for underline in decorations.underlines where valid(underline.range) {
            layoutManager.addTemporaryAttributes([
                .underlineStyle: NSUnderlineStyle.thick.rawValue,
                .underlineColor: underline.severity.underlineColor,
            ], forCharacterRange: underline.range)
        }
        if let active = decorations.active, valid(active),
           let severity = decorations.underlines.first(where: { $0.range == active })?.severity {
            layoutManager.addTemporaryAttribute(
                .backgroundColor, value: severity.underlineColor.withAlphaComponent(0.18), forCharacterRange: active
            )
        }
    }
}
