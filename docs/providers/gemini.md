# Google Gemini

Grammar Review can use Google's Gemini models instead of Claude, with your own API key, through
the Gemini API's OpenAI-compatible endpoint. Checks, rewrites, tone detection and Write with AI
all go through it.

Verified against [ai.google.dev](https://ai.google.dev/gemini-api/docs) in October 2026 (the
models and pricing pages were last updated on 19 October 2026). Nothing was tested against the
live API.

## Setting it up

1. Create a key in [Google AI Studio](https://aistudio.google.com/apikey). Keys start with `AIza`.
2. In Grammar Review, open Settings → AI and choose **Google Gemini**.
3. Paste the key and press *Save*. It goes into your Keychain, never into the settings file.
   *Test* checks the key by listing the models it can use.
4. Pick a model and press *Test* under it to proofread a sample sentence end to end.

For development, the `GEMINI_API_KEY` environment variable is used when the Keychain has no key.

## Models

Paid-tier prices per million tokens; output prices include thinking tokens. As of October 2026,
from [Google's pricing page](https://ai.google.dev/gemini-api/docs/pricing).

| Model | Input | Cached input | Output | Free tier | Good for |
|---|---|---|---|---|---|
| `gemini-3.5-flash-lite` (default) | $0.30 | $0.03 | $2.50 | Yes | Fast and cheap; quick enough to check as you type. |
| `gemini-3.1-flash-lite` | $0.25 | $0.025 | $1.50 | Yes | The cheapest; a generation older. |
| `gemini-3.8-flash` | $0.75 | $0.075 | $3.75 | Yes | Better style and clarity suggestions; slower. Rises to $1.50 / $7.50 on 1 January 2027. |
| `gemini-4-argon` | $2.00 | $0.10 | $10.00 | No | Google's flagship: the best suggestions, the slowest. Rises to $4.00 / $20.00 on 1 December 2026. |

The Gemini 2.5 models still run, but only for projects that used them before, so the app doesn't
offer them; any model ID can still be typed under *Other…*. The list button shows what your key can
use. The usage meter in Settings → AI → Usage prices requests from this table.

## What's particular to Gemini

- **The endpoint is a compatibility layer**, `https://generativelanguage.googleapis.com/v1beta/openai`,
  which Google still calls beta. The key goes in `Authorization: Bearer`.
- **Thinking:** Gemini 3 and 4 models think before answering and can't be told not to. The app sends
  `reasoning_effort: "low"`, which the endpoint maps to the lowest thinking level of each model, to
  keep checks quick. Thinking tokens are billed as output.
- **Structured output:** checks and tone detection send OpenAI's `response_format: json_schema`
  with `strict: true`, which the compatibility layer supports (it's what the OpenAI SDKs' `parse`
  helpers send).
- **Model IDs:** the native API names models `models/gemini-…`; if the model list comes back with
  that prefix, the app drops it.
- **Free tier:** Flash and Flash-Lite models work without a billing account, with low per-minute
  and per-day limits that vary by model (shown in AI Studio). Exceeding them returns HTTP 429; the
  app shows "Google Gemini rate limit or quota reached" and tries again on the next edit. Linking a
  billing account moves the project to Tier 1 at once.
- **A bad key** comes back as HTTP 400 `INVALID_ARGUMENT` ("API key not valid") rather than 401;
  the app recognises it and says "Invalid Google Gemini API key".

## Data handling

This matters more than with the other services. Under the
[Gemini API terms](https://ai.google.dev/gemini-api/terms):

- **Unpaid (free tier):** Google may use what you send and what the model answers to improve its
  products and train models, and human reviewers may read it (after disconnecting it from your
  account). Don't send confidential text on the free tier.
- **Paid (a project with billing):** prompts and responses aren't used to improve Google's products;
  they're logged for a limited time to detect abuse and meet legal requirements, and may be stored
  in any country where Google has facilities.
- In the EEA, Switzerland and the UK, the paid terms apply to free use too.

Grammar Review itself sends only the paragraphs you changed, the text whose tone you asked about
and what you rewrite or draft, and stores none of it.

## Troubleshooting

| The app says | Why | What to do |
|---|---|---|
| Invalid Google Gemini API key | Google returned 400 `API key not valid` (or 401/403). | Paste a key from AI Studio and press Save, then Test. |
| Google Gemini rate limit or quota reached | 429: the free tier's per-minute or per-day limit, or a spend limit. | Wait, or add a billing account in AI Studio. |
| Google Gemini doesn't have this model | 404: the model ID doesn't exist, or your project can't use it (the 2.5 models). | Choose one from the list. |
| Gemini is busy — try again shortly | 502/503 from Google. | Wait a moment; the next check tries again. |
| Gemini's answer wasn't in the expected format | The JSON didn't match the schema. | Try again; if it keeps happening with a model typed under *Other…*, use one of the models above. |

Sources: [Models](https://ai.google.dev/gemini-api/docs/models), [Pricing](https://ai.google.dev/gemini-api/docs/pricing),
[OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai), [Rate limits](https://ai.google.dev/gemini-api/docs/rate-limits),
[Terms](https://ai.google.dev/gemini-api/terms). All read in October 2026.
