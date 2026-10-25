# Grammar Review

A Grammarly-style writing assistant for macOS. It lives in the menu bar, follows the text field you're typing in — in any app — underlines mistakes in place, and fixes them with one click.

- **Instant spelling** from the macOS spellchecker, in any language you have a dictionary for.
- **Style guide**: your team's terms (brand names, banned words, preferred spellings), flagged in every app, offline; import and export it as CSV or JSON.
- **Consistency checks**, offline: the same word written two ways ("email" and "e-mail"), British and American spelling mixed in one text, straight and curly quotes mixed.
- **Grammar, clarity and style** from Claude, from another AI service with your own key (OpenAI, xAI's Grok, Google Gemini, Mistral, DeepSeek), or from a local model (LM Studio, Ollama), after you pause typing.
- **Multilingual**: the language is detected from the text and your keyboard layouts (macOS can't detect some languages, such as Lithuanian, from text alone), or you pick one in the menu bar under **Language**. Suggestions never translate your text.
- **Inline underlines** (red = correctness, blue = clarity, purple = style) with a suggestion card on hover or when the caret enters a mistake.
- **Badge + panel**: issue count on the field, a list of all suggestions, *Fix all*, and how your text sounds (tone detection).
- **Rewrite selection** in a different style: `⌃⌥R`. Improve, rephrase, concise, simplify or expand it, change the tone (professional, formal, informal, friendly, confident, diplomatic, persuasive or academic), or describe the change in your own words.
- **Rephrase a sentence** without selecting it: press `⌃⌥R` with the cursor in the sentence, click *Rephrase sentence* on a suggestion, or click the badge and pick a style under *Rewrite* (for the sentence or all the text).
- **Editor window** (`⌃⌥E`): write or paste text, review every suggestion in a sidebar, set writing goals (style, audience, domain, intent), and rewrite paragraphs in a style or as you describe ("make it sound excited").
- **Write with AI** (`⌃⌥W`, in any app, or in the editor): draft new text from a short request ("a polite reply declining the meeting"), using the field's text as context if you like.
- **Insights** in the editor: a tone detector (how your text comes across, and whether a tone might land badly), a readability score with long sentences highlighted, and word, sentence and reading-time counts.
- **Updates itself**: released builds check for a new version once a day, or when you choose *Check for Updates…*.

The design is described in [docs/PLAN.md](docs/PLAN.md). The project website, with a live demo, is at [modakoda.github.io/grammar-review](https://modakoda.github.io/grammar-review/).

## Requirements

- macOS 14 or later.
- Swift 6.2+ toolchain. The Xcode Command Line Tools are enough (`xcode-select --install`).
- Optional, for grammar, style and rewrites: an [Anthropic API key](https://platform.claude.com/settings/keys) (scoped to one workspace; see [Anthropic](docs/providers/anthropic.md)), or another service's key (see [Other AI services](#other-ai-services)), or a local model server (see [Local models](#local-models)). Without either you get spelling only.

## Build and run

```bash
scripts/run.sh
```

This builds `build/Grammar Review.app` (via `scripts/build-app.sh`) and opens it. Add `--logs` to stream the app's logs.

On first launch the setup guide asks for:

1. **Accessibility permission**: System Settings → Privacy & Security → Accessibility → enable *Grammar Review*. This is how the app reads and edits text fields in other apps.
2. **Anthropic API key** (optional). It is stored in your Keychain. For development you can also export `ANTHROPIC_API_KEY`. [Anthropic](docs/providers/anthropic.md) covers getting a key, the models, prices, limits and the error messages.

> **Switched it on, but the setup guide keeps waiting?** macOS ties the permission to the app's code signature. Without a certificate every build is ad-hoc signed with a new identity, so an entry made for an older build looks enabled but is ignored. Click **Reset Permission** in the setup guide (or run `tccutil reset Accessibility com.grammarreview.app`) and switch it on again.
>
> To stop this happening after every rebuild, create a local signing identity once. `scripts/build-app.sh` then uses it automatically:
>
> ```bash
> scripts/setup-signing.sh
> ```

> **Underlines stopped appearing in every app, and the menu bar says "macOS is hiding text fields"?** macOS has stopped showing app windows to Accessibility, which can happen after a WindowServer restart: every app answers with itself instead of its windows, so no text field can be found. The permission isn't the problem. Log out and back in, or restart the Mac.

## Local models

Instead of Claude, Grammar Review can use a model running on your Mac through any OpenAI-compatible server. No API key is needed, and with the server on this Mac your text never leaves it.

1. Start a server and get a model:
   - **LM Studio**: download a model, then start the server in the Developer tab. Address: `http://localhost:1234/v1`.
   - **LM Studio Bionic**: download a model, then turn on *Local Server*; it doesn't start on its own. Same address as LM Studio, so use the *LM Studio* preset.
   - **Ollama**: `ollama pull <model>`; the server runs in the background. Address: `http://localhost:11434/v1`.
   - **llama.cpp**: `llama-server -m model.gguf`. Address: `http://localhost:8080/v1`.
2. In Settings → AI, choose **Local model**, pick the server from *Presets*, choose a model from the list, and click **Test**.

The server needs to support structured output (`response_format: json_schema`); LM Studio, Ollama and `llama-server` do. Local models are slower and less accurate than Claude, especially small ones and in languages other than English. Models of about 20–30B parameters are a good balance, and mixture-of-experts models (e.g. 30B-A3B) respond fastest. Reasoning ("thinking") models work but add seconds to every check.

### Recommended models

These are fast enough to check as you type. Sizes are for the 4-bit versions.

| Model | Mac memory | Ollama | Notes |
|---|---|---|---|
| **Qwen3-30B-A3B-Instruct-2507** | 32 GB+ | `ollama pull qwen3:30b-a3b-instruct-2507-q4_K_M` | Recommended. A mixture-of-experts model with 3B active parameters: about as fast as a small model, with much better suggestions. No thinking. 19 GB. |
| **gpt-oss-20b** | 24 GB+ | `ollama pull gpt-oss:20b` | Also mixture-of-experts and quick, but it always reasons first, which adds a little time to every check. 14 GB. |
| **Qwen3-4B-Instruct-2507** | 16 GB | `ollama pull qwen3:4b-instruct-2507-q4_K_M` | Fastest. Fine for spelling and basic grammar; weaker on style and in languages other than English. 2.5 GB. |

In LM Studio, search for the model name; on Apple Silicon the MLX build is usually faster than GGUF. Choose the *Instruct-2507* versions: the original Qwen3 releases think before every answer.

## Other AI services

Besides Claude, Grammar Review can use any of these with your own API key: choose the service in Settings → AI, paste the key (it goes into your Keychain, one item per service) and pick a model. Each page lists the models offered, what they cost and anything particular to the service: [OpenAI](docs/providers/openai.md), [xAI (Grok)](docs/providers/xai.md), [Google Gemini](docs/providers/gemini.md), [Mistral](docs/providers/mistral.md), [DeepSeek](docs/providers/deepseek.md). For development, each service also reads its usual environment variable (`OPENAI_API_KEY`, `XAI_API_KEY`, `GEMINI_API_KEY`, `MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`) when the Keychain has no key.

All of them speak the OpenAI chat completions API, so one client serves them all; a service is described in a single file under `Sources/GrammarModels/AIProviders/CloudServices/` (models, prices, request quirks such as `max_completion_tokens` or JSON-object-only output). The usage meter prices their requests at the service's list prices.

## Using it

| Action | How |
|---|---|
| See a suggestion | Hover over an underline, or move the caret into it |
| Apply / ignore | Click the replacement, or *Ignore* / *Add to dictionary* in the card |
| All suggestions | Click the badge on or beside the field, or press `⌃⌥G` |
| Undo an ignore | The suggestions panel lists ignored suggestions at the bottom; click *Restore* |
| Move the badge | Right-click the badge and pick a position for that kind of field, or set one for *Input fields* and one for *Text areas* in Settings → General → *Badge*: any inside corner of the field, right, left, above or below it, or automatic (left of input fields so it doesn't cover the text, inside the bottom-left corner of large text areas) |
| Badge spacing | Right-click the badge → *Distance from the Field*, or Settings → General → *Badge* → *Distance from the field*: how far the badge sits from the field when it's outside it |
| Rewrite selection | Select text, press `⌃⌥R`, pick a style or click *Describe a change…* and type one, *Replace* |
| Rephrase a sentence | Put the cursor in it and press `⌃⌥R` with nothing selected, or click *Rephrase sentence* on a suggestion. It's said another way; pick a style (formal, friendly, concise…) to rephrase it in that style, then *Replace*. In the editor: *Rewrite* → *Rephrase Sentence* |
| Rewrite from the badge | Click the badge; under *Rewrite*, choose *Sentence* (the one with the cursor) or *All text*, then click a style: *Rephrase*, *Formal*, *Friendly*, *Diplomatic*, or *⋯* for the rest. Check the result, then *Replace* |
| Write in the editor | Menu bar icon → *Open Editor…*, or `⌃⌥E`: suggestion cards by category, writing *Goals* and *Rewrite* in another style |
| Add style guide rules | Settings → *Style Guide*: a term, what to write instead (optional) and why. *Import…* reads a team's JSON or CSV file |
| Set writing goals for an app | Menu bar icon → *Writing Goals in <App>*: style (professional, formal, informal, friendly, confident, concise, simple), audience, domain (email, business, academic…) and intent. All apps: Settings → *Goals* |
| Rewrite in your own words | In the editor, *Rewrite* → *Describe a Change…*, or type an instruction on the rewrite card |
| Draft new text | In any field, `⌃⌥W` (or menu bar icon → *Write with AI…*); in the editor, *Write with AI*. Type a request, Return, then *Insert* (at the cursor) or *Replace* (the selection) |
| Check tone and readability | In the editor's sidebar, switch to *Insights* |
| Pause, turn AI off, disable for an app | Menu bar icon |
| Settings | Menu bar icon → *Settings…* |
| See what AI costs | Settings → AI → *Usage*: this month's requests, tokens and estimated cost at each service's list prices |
| Update | Menu bar icon → *Check for Updates…*; Settings → General → *Check for updates automatically*. Only in released builds (see [Updates](#updates)) |

## Privacy

- Secure/password fields are never read.
- Terminals, password managers and code editors are excluded by default. You can edit the list in Settings → Apps.
- Text is sent to the AI service you chose (Anthropic, OpenAI, xAI, Google, Mistral or DeepSeek), or to your local model server, only when AI suggestions are on. Only the paragraphs that changed are sent, and long texts (6,000+ characters by default) get local spelling only.
- Only your settings and AI request counts are stored on disk, never text. API keys are kept in the Keychain.
- Released builds download the update feed from the project website about once a day. Nothing about you or your text is sent with it.

## Development

```bash
swift build
```

```bash
scripts/test.sh
```

`scripts/test.sh` wraps `swift test` so Swift Testing also works with only the Command Line Tools installed.

The first build downloads [Sparkle](https://sparkle-project.org), the update framework, through SwiftPM. If it stalls at *Downloading binary artifact*, SwiftPM may be waiting for a Keychain prompt about github.com credentials: allow it, or run `swift package resolve --disable-keychain` once.

### Formatting and linting

[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) formats the code (`.swiftformat`) and [SwiftLint](https://github.com/realm/SwiftLint) checks it (`.swiftlint.yml`). Install both with:

```bash
brew bundle
```

Format the code in place:

```bash
scripts/format.sh
```

Check formatting and lint rules without changing anything (warnings fail too):

```bash
scripts/lint.sh
```

To run these checks on the staged files before every commit, enable the hook once per clone:

```bash
git config core.hooksPath .githooks
```

CI (`.github/workflows/ci.yml`) runs `scripts/lint.sh`, builds with compiler warnings treated as errors, and runs the tests on every push to `main` and every pull request.

For [Claude Code](https://claude.com/claude-code), `.claude/settings.json` enables two plugins from Anthropic's official marketplace: `swift-lsp` gives Claude SourceKit-LSP's diagnostics and code navigation for the Swift sources, and `pr-review-toolkit` adds `/pr-review-toolkit:review-pr` and review agents for silent failures, test coverage, comments, type design and simplification.

| Module | What it does |
|---|---|
| `GrammarModels` | Shared types and protocols: the contract between modules |
| `GrammarEngine` | Local spellchecker, Claude and local-server clients, merging, caching, rebasing |
| `GrammarAccessibility` | Focus tracking and text field reading/writing over the Accessibility API |
| `GrammarOverlay` | Underlines, badge, suggestion card, panel, rewrite and *Write with AI* cards |
| `GrammarEditor` | The editor window: text view, suggestions sidebar, insights, rewrite and *Write with AI* |
| `GrammarAppUI` | Menu bar, Settings, onboarding, hotkeys, Keychain, settings and usage storage, update controls (without Sparkle itself) |
| `GrammarReviewApp` | The executable: `AppDelegate`, `AppCoordinator` and the flows it drives (`FieldSession`, `RewriteFlow`, `ComposeFlow`…), and `SparkleUpdater`, the only code that uses Sparkle |

Inside each module the files are grouped by feature, not by kind: `Checking/`, `Rewrite/`, `Compose/`, `Tone/`, `Settings/`, `Onboarding/` and so on, with what several features use in `Shared/`. A file holds one type, and big jobs are split into small classes: `HybridGrammarEngine` hands a check to `CheckPipeline` and a rewrite to `TextRewriter`, `OverlayController` has a presenter per overlay, and `AppCoordinator` gives the focused field to a `FieldSession`. The test targets use the same folders.

### Security checks

`brew bundle` also installs four scanners, which one script runs:

```bash
scripts/security.sh
```

- [Gitleaks](https://github.com/gitleaks/gitleaks): API keys and other secrets in the commit history.
- [OSV-Scanner](https://google.github.io/osv-scanner/): known vulnerabilities in the locked dependencies (`Package.resolved`, `site/tests/package-lock.json`).
- [zizmor](https://docs.zizmor.sh): security problems in the GitHub Actions workflows, such as unpinned actions and template injection. With `GH_TOKEN` set it also checks the actions against GitHub's advisories.
- [Semgrep](https://semgrep.dev): static analysis of the Swift and Python code with the registry's `p/swift`, `p/python` and `p/secrets` rules, without sending usage metrics.

CI (`.github/workflows/security.yml`) runs it on every push to `main`, every pull request and once a week. The workflows pin each action to a commit SHA, with the version in a comment (`actions/checkout@<sha> # v5.1.0`): zizmor fails on an action used by tag, so pin new ones the same way.

### Releases

To release `main`, choose Actions → *Release* → *Run workflow* and leave *tag* empty. The version is the date and time the run starts, in UTC, as `YYYY.MMDD.HHMM`: a run at 14:35 UTC on 23 October 2026 releases version `2026.1023.1435`. It goes into both `CFBundleShortVersionString` and `CFBundleVersion`, which Sparkle compares to find updates, so each release is newer than the last. The `0.1.0` in `App/Info.plist` is only for local builds.

`.github/workflows/release.yml` builds the release, publishes a GitHub release with `Grammar-Review-2026.1023.1435.dmg`, `Grammar-Review-2026.1023.1435.zip` and `release.json` (which describes them for the website), tags the commit it built `v2026.1023.1435`, and then redeploys the website, which offers the new version for download and as an update. The tag is made only once the build succeeds. To build an existing release again, enter its tag in *Run workflow*.

The repository's secrets and variables (Settings → Secrets and variables → Actions) decide what a release gets:

| Name | Kind | What it does |
|---|---|---|
| `DEVELOPER_ID_CERTIFICATE` | secret | Base64 of the "Developer ID Application" certificate exported as a .p12 (`base64 -i certificate.p12`) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret | The .p12's password |
| `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID` | secrets | The Apple ID and team that notarize |
| `NOTARY_PASSWORD` | secret | An [app-specific password](https://support.apple.com/102654) for that Apple ID |
| `SPARKLE_PUBLIC_KEY` | variable | The public update key (see [Updates](#updates)). The released app checks for updates only when it has one |
| `SPARKLE_PRIVATE_KEY` | secret | The private update key. It signs the release's zip; without it the release isn't offered as an update |

- **Notarized**, with the Developer ID and notarization secrets: signed with the Developer ID (hardened runtime, secure timestamp), notarized and stapled. It opens without warnings on other Macs.
- **Unsigned**, with none of them: ad-hoc signed and not notarized, and labelled "not notarized" in the release's title and notes and on the website. macOS asks before opening it the first time (System Settings → Privacy & Security → *Open Anyway*). Some of these secrets without the rest is an error.

Without `SPARKLE_PRIVATE_KEY` the workflow warns and publishes the release without signing it as an update.

To build a release on your Mac instead, run `scripts/release.sh`; it packages the release in `build/release/`, versioned from the date and time like the workflow's (set `VERSION=1.2.3` for another version). A notarized release needs a "Developer ID Application" certificate in the keychain and notarization credentials stored once with `xcrun notarytool store-credentials`. `--ad-hoc` builds an unsigned release, and `--skip-notarize` signs without notarizing:

```bash
xcrun notarytool store-credentials grammar-review --apple-id you@example.com --team-id TEAMID --password <app-specific password>
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=grammar-review scripts/release.sh
scripts/release.sh --ad-hoc
```

### Updates

Grammar Review updates itself with [Sparkle](https://sparkle-project.org) 2. It reads the update feed at `https://modakoda.github.io/grammar-review/appcast.xml` (`SUFeedURL` in `App/Info.plist`) once a day, or when you choose *Check for Updates…*, and installs an update only if its zip is signed with the update key: the app carries the public half (`SUPublicEDKey`), and the release workflow signs with the private half. `scripts/build-app.sh` adds the public key from `SPARKLE_PUBLIC_KEY`; builds without it, such as every local build, never start the updater and show no update controls.

Set up the key once, on a Mac you trust. `generate_keys` keeps the private key in that Mac's login keychain:

```bash
swift package resolve
.build/artifacts/sparkle/Sparkle/bin/generate_keys                         # prints the public key
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key  # exports the private key
gh variable set SPARKLE_PUBLIC_KEY --body "<the public key>"
gh secret set SPARKLE_PRIVATE_KEY < sparkle-private-key
rm sparkle-private-key
```

(Or add them in Settings → Secrets and variables → Actions.) Keep the private key safe, and don't lose it: installed copies accept only updates signed with it, or, for notarized builds, signed with the same Developer ID. To sign a release made with `scripts/release.sh`, set `SPARKLE_PUBLIC_KEY` and `SPARKLE_PRIVATE_KEY` in its environment; it checks the signature against the app's public key before writing it to `release.json`.

Unsigned releases update too. Sparkle accepts an update when either its update-key signature or its Apple code signature matches the installed app; an ad-hoc signature never matches another build, so for unsigned releases the update key does all the checking. Sparkle clears the quarantine flag, so the updated app opens without *Open Anyway*, but like every ad-hoc build it needs the Accessibility permission granted again. Moving between notarized and unsigned releases works both ways.

### Website

The landing page is a single static file, `site/index.html`, with no build step. Preview it locally with:

```bash
python3 -m http.server 4173 --directory site
```

Two test suites cover the page. `python3 scripts/test-site.py` checks its structure, links, accessibility basics, the download contract and the facts it states, without a browser. `site/tests/` runs the demos and the download states in headless Chromium at desktop and phone widths: `cd site/tests && npm ci && npx playwright install chromium && npm test`. `.github/workflows/site.yml` runs both on every change to the site.

`.github/workflows/pages.yml` publishes the site to GitHub Pages on every push to `main` that touches it and after every release. Before the first deploy, set Settings → Pages → *Source* to **GitHub Actions**. Release files never go into git: `scripts/assemble-site.py` copies `site/` and adds these, made from the GitHub releases:

| Path | What |
|---|---|
| `download/Grammar-Review.dmg`, `download/Grammar-Review.zip` | The latest release, at URLs that stay the same from release to release |
| `download/latest.json` | What the latest release is (below) |
| `appcast.xml` | Sparkle's update feed: the last 10 releases signed as updates, with their release notes (so the notes are public too) |
| `updates/Grammar-Review-<version>.zip` | Those releases' zips |

All of them are under `https://modakoda.github.io/grammar-review/`. `latest.json` looks like this, and has `"version": null` and no files before the first release:

```json
{
  "version": "2026.1021.0930",
  "published": "2026-10-21T09:30:00Z",
  "minimumSystemVersion": "14.0",
  "notarized": true,
  "files": {
    "dmg": {"name": "Grammar-Review.dmg", "size": 4123456, "sha256": "…"},
    "zip": {"name": "Grammar-Review.zip", "size": 3912345, "sha256": "…"}
  }
}
```

To see the assembled site, run `python3 scripts/assemble-site.py build/site` with `gh` signed in. `python3 scripts/test-assemble-site.py` tests the script against fake releases; CI runs it too.

## Known limitations

- Apps that don't expose their text through Accessibility get nothing: canvas-based editors like Google Docs, games, some cross-platform toolkits.
- Underlines rely on each app reporting text positions. Where an app reports them wrongly or not at all, you still get the badge and panel.
- Not on the Mac App Store: the sandbox forbids controlling other apps.
