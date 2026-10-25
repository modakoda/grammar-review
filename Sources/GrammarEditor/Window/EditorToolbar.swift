import AppKit
import GrammarModels
import SwiftUI

struct EditorToolbar: View {
    let model: EditorModel

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Style", selection: binding(\.style)) {
                    ForEach(WritingStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Picker("Audience", selection: binding(\.audience)) {
                    ForEach(WritingAudience.allCases) { audience in
                        Text(audience.displayName).tag(audience)
                    }
                }
                Picker("Domain", selection: binding(\.domain)) {
                    ForEach(WritingDomain.allCases) { domain in
                        Text(domain.displayName).tag(domain)
                    }
                }
                Picker("Intent", selection: binding(\.intent)) {
                    ForEach(WritingIntent.allCases) { intent in
                        Text(intent.displayName).tag(intent)
                    }
                }
                if !model.goals.isNone {
                    Divider()
                    Button("Clear Goals") { model.setGoals(.none) }
                }
            } label: {
                Label(model.goals.isNone ? "Goals" : "Goals: \(model.goals.summary)", systemImage: "slider.horizontal.3")
            }
            .fixedSize()
            .help("Writing goals: how it should sound, who reads it, what kind of writing it is and what it's for. AI suggestions follow them.")

            Menu {
                if !model.rewritesSelection {
                    Button("Rephrase Sentence") { model.rephraseSentence() }
                        .help("Say the sentence with the cursor another way, then pick a style for it")
                    Divider()
                }
                ForEach(RewriteTone.Group.allCases) { group in
                    Section(group.displayName) {
                        ForEach(group.tones) { tone in
                            Button(tone.displayName) { model.startRewrite(tone) }
                                .help(tone.detail)
                        }
                    }
                }
                Divider()
                Button("Describe a Change…") { model.startCustomRewrite() }
                    .help("Rewrite it the way you describe, in your own words")
            } label: {
                Label(model.rewritesSelection ? "Rewrite Selection" : "Rewrite Paragraph", systemImage: "wand.and.stars")
            }
            .fixedSize()
            .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Rewrite the selected text or the paragraph with the cursor, or rephrase the sentence with the cursor, in another style")

            Button {
                model.startCompose()
            } label: {
                Label("Write with AI", systemImage: "sparkles")
            }
            .fixedSize()
            .help("Draft new text from a short request, at the cursor or in place of the selection")

            Spacer(minLength: 8)

            Text(model.wordCount == 1 ? "1 word" : "\(model.wordCount) words")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(model.text, forType: .string)
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
            .disabled(model.text.isEmpty)
            .help("Copy the whole text")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<WritingGoals, Value>) -> Binding<Value> {
        Binding(
            get: { model.goals[keyPath: keyPath] },
            set: { value in
                var goals = model.goals
                goals[keyPath: keyPath] = value
                model.setGoals(goals)
            }
        )
    }
}
