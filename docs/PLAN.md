# Grammar Review — product & architecture plan

A Grammarly-style macOS menu bar app that watches the text field you are typing in — in any app — underlines mistakes in place, and lets you fix them with one click.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Platform | macOS native: Swift 6, AppKit + SwiftUI, Swift Package Manager | The macOS Accessibility (AX) API is the only reliable way to read, locate and edit text fields in other apps. |
| Engine | Hybrid: instant local spelling (`NSSpellChecker`) + Claude API for grammar, clarity and style after a typing pause | Local gives zero-latency feedback and works offline; Claude gives Grammarly-level grammar and style suggestions. |
| Languages | Multilingual with automatic detection (`NaturalLanguage`, with keyboard layouts as hints for short texts and languages it can't recognise), the keyboard layout's language, or a fixed language | Suggestions always stay in the text's own language. UI and explanations are in English. |
| UX | Inline underlines + suggestion card + floating badge with an "all suggestions" panel | Matches Grammarly; falls back to badge-only where an app cannot report text positions. |
| Distribution | Outside the App Store (the sandbox forbids controlling other apps), signed `.app` built by script | No Xcode needed: Command Line Tools are enough. |
| Updates | Sparkle 2, with the feed and update archives on the project's GitHub Pages site, made from the GitHub releases | The repository is private, so its release files aren't public; Pages is. |

## Features — v1 (this build)

1. **System-wide checking.** Runs as a menu bar app (no Dock icon) and follows the focused editable text field in any app.
2. **Inline underlines.** Red = correctness (spelling, grammar, punctuation), blue = clarity (clarity, word choice), purple = style.
3. **Suggestion card.** Appears on hover over an underline or when the caret moves into one: explanation, up to 3 replacements (original struck through → fix), *Accept*, *Ignore*, *Add to dictionary* (spelling).
4. **Floating badge.** Sits inside a corner of the field (bottom-left by default) or just outside it (left, right, above or below; by default left of input fields and small text areas, so it doesn't cover the text), with a position for input fields and one for text areas, chosen in Settings or from the badge's right-click menu: issue count, spinner while checking, warning when AI is unavailable. Click it to open the **suggestions panel**: every issue with Accept/Ignore, *Fix all* for correctness issues, the ignored suggestions found in the field with *Restore*, and a tone line ("Sounds: 😎 Confident · 🤗 Friendly", detected when the panel opens and again after typing pauses while it stays open). An ignore lasts for the session.
5. **Hybrid engine.**
   - Local spelling in milliseconds, in any language macOS has a dictionary for.
   - Claude (default `claude-haiku-5-5`, selectable Sonnet/Opus) checks grammar, punctuation, clarity, word choice and style after you pause typing (default 1 s).
   - Paragraph-level cache: editing one paragraph only re-sends that paragraph.
   - Stale requests are cancelled; results that arrive late are re-mapped onto the current text.
6. **Multilingual.** Language detected per text; can be fixed in Settings. Claude is told never to translate.
7. **Rewrite selection** (`⌃⌥R`): select text, pick a style or describe the change in your own words, preview the rewrite, Accept to replace. Edits: Improve, Concise, Simplify, Expand. Tones: Professional, Formal, Informal, Friendly, Confident, Diplomatic, Persuasive, Academic. The card's instruction field is the only overlay control that takes the keyboard: clicking it makes the (non-activating) card key, so the edited app stays frontmost, and the card hands the keyboard back before the text is replaced.
8. **Controls.** Menu bar: on/off, pause for 1 hour / until tomorrow, AI on/off, disable for the current app, open Settings. `⌃⌥G` opens the suggestions panel for the current field.
   - **Write with AI** (`⌃⌥W`, menu bar → *Write with AI…*): a card under the caret takes the keyboard for the request (the edited app stays frontmost), optionally sends the field's text (minus the selection) as context, and inserts the draft at the caret or in place of the selection, only if that text is unchanged. Fields that already have several lines get it as its own paragraph; single-line fields get it on one line, with spaces, so a line break can't send a message.
9. **Settings.** Anthropic API key (stored in Keychain), model, a usage meter (requests, tokens and estimated cost per month, model and purpose, at list prices; counts only, in UserDefaults under `usage.v1`), AI delay, enabled categories, language mode, disabled apps, writing goals per app, personal dictionary, show badge, its position in input fields and in text areas and its distance from the field, launch at login.
   - **Writing goals** (`WritingGoals`): a style (neutral, professional, formal, informal, friendly, confident, concise, simple), an audience (general, knowledgeable, expert), a domain (general, email, business, academic, technical, casual, creative) and an intent (inform, describe, convince, tell a story). They go in the check's user turn (the system prompt stays cacheable) and key the paragraph cache. The editor has its own goals; other apps get theirs from a per-app profile (menu bar → *Writing Goals in <App>*, or Settings → Goals).
10. **Editor window** (`⌃⌥E`): a plain-text editor with the suggestions in a sidebar (filter by category, *Accept all*), a writing style goal for AI suggestions, and *Rewrite* for the paragraph at the caret or the selection, in one of the rewrite styles or with the writer's own instruction. **Write with AI** drafts new text from a request, optionally with the editor's text as context (capped by the AI limit), and inserts it at the cursor as its own paragraph or in place of the selection; it never invents dates, numbers or names, and uses placeholders like [date] instead. Its **Insights** tab shows:
    - **Tone**: up to three tones with their intensity, the overall sentiment and a one-line summary, from one AI call per text (debounced, only while the tab is open). Tones that may land badly (accusatory, disapproving…) are marked.
    - **Readability**: Flesch reading ease and Flesch–Kincaid grade for English, and sentences over 30 words highlighted in the text.
    - **Counts**: words, characters, sentences, paragraphs, reading and speaking time, average sentence and word length, vocabulary variety.
11. **Style guide** (Settings → Style Guide): rules with a term, an optional replacement, an optional note and *Match case*, checked locally (`StyleGuideChecker`) as whole words in every field and the editor. A rule from "Github" to "GitHub" fixes capitalisation; others keep the capitalisation found. Style guide suggestions win over overlapping AI and local ones. Teams share a guide as JSON or CSV (term, replacement, note, match case; semicolons and a header row are accepted); an imported rule replaces one for the same term.
12. **Consistency checks** (local, offline, in the local pass): a word spelled with and without a hyphen, British and American spellings in one English text, mixed straight and curly quotation marks or apostrophes. The form used most wins; ties are left alone (a British/American tie follows the user's English variant).
13. **Onboarding.** Walks through granting Accessibility permission (detects the grant live) and adding an API key (optional — local spelling works without it).
14. **Privacy.**
    - Never reads secure/password fields.
    - Terminals, password managers and code editors are excluded by default.
    - Text leaves the Mac only when AI is on, only to the AI service the user chose (or their local server), and only up to a length cap (default 6,000 characters).
    - Only settings and AI request counts (for the usage meter) are written to disk, never text.
15. **Updates.** Sparkle 2 (`SPUStandardUpdaterController`), checking `appcast.xml` on the website once a day (`SUEnableAutomaticChecks`) and from *Check for Updates…* in the menu bar menu and the app menu. Settings → General turns the daily check off.
    - **Off unless configured.** `UpdaterConfiguration` reads the Info.plist: updates need an https `SUFeedURL` and a valid `SUPublicEDKey`, which only builds with `SPARKLE_PUBLIC_KEY` get. Without them Sparkle never starts and the update controls are hidden, so local builds behave as before.
    - **Signed updates.** Each update zip carries an EdDSA signature from the private key (a CI secret), checked before extraction (`SUVerifyUpdateBeforeExtraction`). This is also what protects unsigned (ad-hoc) releases, whose code signature can't match a later build's.
    - **Gentle reminders.** A background check opens its window behind other apps, so the menu bar menu shows *Update to Version …* until the user has seen it.
    - Sparkle stays out of `GrammarModels` and `GrammarEngine`: `GrammarAppUI` talks to an `AppUpdater` protocol, and the executable's `SparkleUpdater` implements it.
16. **App compatibility layer.**
    - Native AppKit apps: full support.
    - Safari/WebKit: full support.
    - Chrome/Chromium: enables the enhanced accessibility tree.
    - Electron apps: sets `AXManualAccessibility`.
    - Apps that reject AX writes get a clipboard-paste fallback, which saves and then restores the clipboard.

### Later (not in v1)

- Plagiarism detection and citations (need a web index).
- Offline grammar via Harper, without a model server (a local LLM already works offline through the local provider).
- Windows version (UI Automation).

### Known limitations

- Apps that expose no accessible text get nothing: canvas-based editors (Google Docs in its default mode), most games, some Java/Qt apps.
- Underline accuracy depends on each app's `AXBoundsForRange`; where it is missing or wrong we show badge + panel only.
- Ad-hoc signed builds change identity on every rebuild, so macOS asks to re-grant Accessibility. Setting `CODESIGN_IDENTITY` to a stable certificate avoids this. Unsigned releases have the same problem after every update.

## Architecture

```
┌──────────────────── Grammar Review.app (LSUIElement menu bar app) ────────────────────┐
│ GrammarReviewApp   main.swift · AppDelegate · AppCoordinator (state machine + wiring)  │
│        ▲ focus/text/selection events      ▲ check / rewrite        │ overlay state     │
│ ┌──────┴───────────────┐ ┌────────────────┴──────────┐ ┌───────────▼─────────────────┐ │
│ │ GrammarAccessibility │ │ GrammarEngine             │ │ GrammarOverlay              │ │
│ │ AXObserver tracking  │ │ LocalSpellChecker         │ │ click-through underline win │ │
│ │ read text/sel/bounds │ │ ClaudeClient (Messages)   │ │ badge · card · panel        │ │
│ │ write: AX set/paste  │ │ IssueLocator/Merger/Rebaser│ │ rewrite card                │ │
│ │ Chrome/Electron fixes│ │ paragraph cache, debounce │ │ hover tracking              │ │
│ └──────────────────────┘ └───────────────────────────┘ └─────────────────────────────┘ │
│ GrammarAppUI  menu bar item · Settings window · Onboarding · hotkeys · Keychain · store │
│ GrammarModels  shared value types + protocols (the contract between all modules)       │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Modules

| Target | Responsibility | Isolation |
|---|---|---|
| `GrammarModels` | `TextIssue`, `CheckRequest/Result`, `AppSettings`, the `GrammarChecking`, `TextRewriting`, `FocusTracking`, `TextFieldHandle` and `SuggestionPresenting` protocols, screen-coordinate helpers, permission helper, loggers | nonisolated, `Sendable` |
| `GrammarEngine` | `HybridGrammarEngine` (implements `GrammarChecking` + `TextRewriting`), `IssueRebaser` | nonisolated / actors |
| `GrammarAccessibility` | `AccessibilityFocusTracker` (implements `FocusTracking`) and its `TextFieldHandle` | `@MainActor` by default |
| `GrammarOverlay` | `OverlayController` (implements `SuggestionPresenting`) | `@MainActor` by default |
| `GrammarAppUI` | `SettingsStore`, `KeychainStore`, `StatusBarController`, `SettingsWindowController`, `OnboardingWindowController`, `HotkeyManager`, `UpdaterConfiguration` and the `AppUpdater` protocol | `@MainActor` by default |
| `GrammarReviewApp` | executable: composition root, `AppCoordinator` and `SparkleUpdater` | `@MainActor` by default |

### Releases and updates

1. Running `release.yml` by hand releases the default branch, versioned from the date and time in UTC (`YYYY.MMDD.HHMM`, as both `CFBundleShortVersionString` and `CFBundleVersion`, so Sparkle sees every release as newer): `scripts/release.sh` builds the app (`scripts/build-app.sh` embeds and signs `Sparkle.framework`, and writes `SUPublicEDKey`), notarizes it when the Developer ID secrets exist (an ad-hoc signed, "not notarized" release otherwise), packages a zip and a disk image, signs the zip with Sparkle's `sign_update`, checks that signature against the app's public key, and writes `release.json` (version, build, minimum macOS, notarized, signature and length).
2. The workflow publishes those as a GitHub release, tagging the commit it built `v<version>` only once the build succeeds, then dispatches `pages.yml` on the default branch (a `GITHUB_TOKEN` push or release triggers nothing, and the `github-pages` environment only deploys the default branch).
3. `pages.yml` runs `scripts/assemble-site.py`: it copies `site/`, reads the newest releases with `gh`, puts the latest dmg and zip at `download/Grammar-Review.dmg` and `.zip` with `download/latest.json`, and the last 10 signed zips in `updates/`, listed in `appcast.xml`. It checks its output before the deploy. No release file is ever committed.
4. The app's Sparkle checks `appcast.xml`, downloads the newest zip the Mac can run, verifies its signature against `SUPublicEDKey`, and replaces the app.

### Data flow

1. **Focus.** `AccessibilityFocusTracker` observes app activation and `kAXFocusedUIElementChanged`. It reports a `TextFieldHandle` when the focused element is editable and not secure, and `nil` otherwise. The coordinator ignores disabled apps, paused state and its own process.
2. **Text change.** The tracker listens for `kAXValueChanged`, with a 0.5 s polling fallback for apps that don't send it. The coordinator immediately rebases the issues it already has onto the new text (`IssueRebaser`), so underlines follow typing, then debounces 250 ms and calls `engine.check(_:)`.
3. **Local pass.** The engine yields local spelling issues within milliseconds. The coordinator turns each issue range into screen rects with `handle.rects(for:)` and sends `OverlayState` to the overlay.
4. **AI pass.** After `aiDelay` with no new check:
   - The engine splits the text into paragraphs and sends only uncached ones to Claude (max 3 concurrent).
   - Claude returns structured JSON edits `{original, replacement, context_before, explanation, category}`.
   - Each edit is located in its paragraph and mapped to a UTF-16 range in the full text.
   - The merger dedupes against local results, preferring AI on overlap.
   - The final `CheckResult` is yielded and the stream finishes.
5. **Apply.** On *Accept*, the coordinator re-reads the field and checks that the text at `issue.range` still equals `issue.originalText`, rebasing first if needed. It then calls `handle.replace(range, with:)`, which sets `AXSelectedTextRange` and `AXSelectedText`, re-reads to verify, and falls back to a clipboard paste. *Fix all* applies fixes from the end of the text backwards so earlier ranges stay valid.
6. **Geometry.** A 10 Hz timer runs only while underlines are visible, plus the tracker's moved/resized events. Both re-query rects, so underlines follow scrolling and window moves. The overlay hides when the field loses focus or the app deactivates.

### Coordinates and ranges (contract)

- All ranges are **UTF-16 `NSRange`s** into the field's full text, the same units as AX and `NSString`.
- All rects crossing module boundaries are **AppKit global screen coordinates** (origin at the bottom-left of the primary display). AX returns top-left-origin coordinates, and `ScreenGeometry.flip` converts between the two.

### Claude integration

- Messages API (`POST /v1/messages`, `anthropic-version: 2026-10-21`) over `URLSession`. The API key comes from Keychain, with `ANTHROPIC_API_KEY` as a dev fallback. `docs/providers/anthropic.md` has the models, prices, limits and errors.
- Structured JSON output with a strict schema. If parsing fails, the paragraph is skipped rather than breaking the result.
- System prompt: a minimal-edit copy editor. Keep the language; never translate. Don't flag names, code, URLs, emoji or deliberate stylistic fragments. Return no edits when the text is fine. Explanations are one short English sentence.
- Errors are surfaced as `AIStatus`: 401 means "Invalid API key"; 429/529 back off, except the monthly spend cap's 429 (`enforced_spend_limit_reached`), which isn't retried; other errors show Anthropic's message (a 403 is a permission or region block, not a bad key); when offline, local-only results are shown with a warning badge.
- Rewrite uses the same client with a tone-specific prompt and returns plain text.
- **Cloud services** (Settings → AI): OpenAI, xAI (Grok), Google Gemini (its OpenAI-compatible endpoint), Mistral and DeepSeek, each with the user's own key (Keychain item `<id>-api-key`, environment variable fallback). One `CloudService` descriptor per service in `Sources/GrammarModels/AIProviders/CloudServices/` gives the base URL, models with list prices, the default model and a `RequestStyle`: JSON schema vs JSON-object-only output (then the schema goes into the system prompt), `max_tokens` vs `max_completion_tokens`, "system" vs "developer" role, `reasoning_effort`. A model can override the service's style. `ChatCompletionsClient` sends the request with a bearer token; `GET /models` validates keys and lists models. Errors name the service.
- **Local provider** (Settings → AI): instead of Claude, the same prompts go to an OpenAI-compatible server (LM Studio, Ollama, llama.cpp's `llama-server`) via `POST {base}/chat/completions`, with the schema as `response_format: json_schema`. No API key; the base URL and model name are settings. `<think>` blocks from reasoning models are stripped, the timeout is at least 60 s (the first request may load the model), and *Test* proofreads a sample sentence end to end.

## Parallel implementation plan

The lead (main session) wrote `Package.swift`, `GrammarModels` (the frozen contract) and compiling stubs for every module. Each agent then works in its own git worktree, owns disjoint directories, and must not change public signatures from the scaffold. Agents may add API.

| Agent | Owns | Delivers |
|---|---|---|
| **A — Engine** | `Sources/GrammarEngine`, `Tests/GrammarEngineTests` | Local spellchecker with code/URL filtering and personal dictionary; Claude client, prompts, schema and parser; edit locator; merger; paragraph cache; debounce/cancellation; `IssueRebaser`; rewrite; key validation; unit tests with a mocked `URLProtocol`. |
| **B — Accessibility** | `Sources/GrammarAccessibility`, `Tests/GrammarAccessibilityTests` | Focus tracking via `NSWorkspace` + `AXObserver`; editable/secure detection; text/selection/bounds reading with per-line rect splitting; replace via AX with paste fallback; Chrome/Electron accessibility switches; polling fallback; tests for the pure helpers. |
| **C — Overlay** | `Sources/GrammarOverlay`, `Tests/GrammarOverlayTests` | Click-through underline window (wavy, colour by severity, clipped to field); global hover tracking; non-activating suggestion card; badge; suggestions panel with Fix all; rewrite card; tests for the layout math. |
| **D — App shell** | `Sources/GrammarAppUI`, `Tests/GrammarAppUITests`, `App/`, `scripts/build-app.sh`, `scripts/run.sh` | Settings persistence + thread-safe snapshot; Keychain; menu bar item and menu; Settings window (General, AI, Languages, Apps, Dictionary); onboarding with live permission detection; Carbon global hotkeys; launch at login; `Info.plist` and the `.app` bundling + signing script. |
| **Lead** | `Package.swift`, `GrammarModels`, `Sources/GrammarReviewApp`, `docs/`, `README.md` | `AppCoordinator` written in parallel against the protocols, then integration: merge, build, run tests, bundle, smoke test. |

## Testing

- **Unit tests** (Swift Testing) via `scripts/test.sh`, which also works without Xcode. They cover:
  - edit location, merging and rebasing
  - Claude response parsing (with mocked HTTP)
  - prompt building
  - settings round-trip
  - coordinate flipping and line splitting
  - overlay layout
  - the focused field's session and the overlay state built from it, against a fake field, engine and overlay
- **Manual QA matrix:** TextEdit, Notes, Mail, Messages, Safari `<textarea>`, Chrome `<textarea>`/contenteditable, Slack (Electron), a password field (must be ignored), and an excluded app (Terminal).

## Milestones

1. Plan + scaffold + contract — lead.
2. Parallel module implementation — agents A–D.
3. Integration: coordinator, merge, green build and tests, `.app` bundle.
4. Manual QA in real apps, fix compatibility issues.
5. Polish: icon, notarized releases (`scripts/release.sh`, `release.yml`; need a Developer ID), Sparkle updates, downloads on the website, README.
