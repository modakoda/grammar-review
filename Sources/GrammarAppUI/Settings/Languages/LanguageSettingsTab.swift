import AppKit
import GrammarModels
import SwiftUI

struct LanguageSettingsTab: View {
    @Bindable var store: SettingsStore
    @ViewState private var lastFixedCode: String?
    @ViewState private var keyboard = KeyboardLanguages()

    private enum Choice: Hashable {
        case automatic, keyboard, fixed
    }

    private static let installedOptions = LanguageOptions.make(
        from: NSSpellChecker.shared.availableLanguages,
        displayLocale: .current
    )

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: choiceBinding) {
                    Text("Detect from the text").tag(Choice.automatic)
                    Text("Match the keyboard layout").tag(Choice.keyboard)
                    Text("Always use one language").tag(Choice.fixed)
                }
                .pickerStyle(.radioGroup)

                Picker("Always use", selection: fixedCodeBinding) {
                    ForEach(options) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .disabled(choice != .fixed)

                Text(choiceDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } footer: {
                Text("Suggestions always stay in the text's own language; Grammar Review never translates. Spelling uses the dictionaries installed on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { keyboard = KeyboardLanguages.read() }
        .onReceive(
            DistributedNotificationCenter.default()
                .publisher(for: KeyboardLanguages.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            keyboard = KeyboardLanguages.read()
        }
    }

    private var choiceDetail: String {
        switch choice {
        case .automatic:
            "Short texts, and languages macOS can't detect from text such as Lithuanian, Latvian or Estonian, follow your keyboard layouts and preferred languages."
        case .keyboard:
            if let current = keyboard.current {
                "Switch keyboard layouts to switch languages. Now: \(LanguageOptions.displayName(for: current, in: .current))."
            } else {
                "Switch keyboard layouts to switch languages. Layouts that don't name a language fall back to detecting it from the text."
            }
        case .fixed:
            "Every text is checked in this language, whatever it's written in."
        }
    }

    private var choice: Choice {
        switch store.settings.languageMode {
        case .automatic: .automatic
        case .keyboard: .keyboard
        case .fixed: .fixed
        }
    }

    private var fixedCode: String? {
        if case let .fixed(code) = store.settings.languageMode { code } else { nil }
    }

    private var options: [LanguageOption] {
        LanguageOptions.including(fixedCode, in: Self.installedOptions, displayLocale: .current)
    }

    private var defaultCode: String {
        lastFixedCode
            ?? LanguageOptions.preferredDefault(in: Self.installedOptions, preferredLanguages: Locale.preferredLanguages)
            ?? "en"
    }

    private var choiceBinding: Binding<Choice> {
        Binding(
            get: { choice },
            set: { newChoice in
                guard newChoice != choice else { return }
                lastFixedCode = fixedCode ?? lastFixedCode
                switch newChoice {
                case .automatic: store.settings.languageMode = .automatic
                case .keyboard: store.settings.languageMode = .keyboard
                case .fixed: store.settings.languageMode = .fixed(defaultCode)
                }
            }
        )
    }

    private var fixedCodeBinding: Binding<String> {
        Binding(
            get: { fixedCode ?? defaultCode },
            set: { code in
                lastFixedCode = code
                store.settings.languageMode = .fixed(code)
            }
        )
    }
}
