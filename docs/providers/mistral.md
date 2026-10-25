# Mistral

Grammar Review can use Mistral's models instead of Claude, with your own API key, through La
Plateforme's chat completions API. Checks, rewrites, tone detection and Write with AI all go
through it.

Verified against [docs.mistral.ai](https://docs.mistral.ai/getting-started/models/models_overview/)
in October 2026. Nothing was tested against the live API; the request and response shapes come
from the API reference.

## Setting it up

1. Create a key at [console.mistral.ai](https://console.mistral.ai/api-keys). A workspace needs a
   plan with billing details before the key works for the API.
2. In Grammar Review, open Settings → AI and choose **Mistral**.
3. Paste the key and press *Save*. It goes into your Keychain, never into the settings file.
   *Test* checks the key by listing the models it can use.
4. Pick a model and press *Test* under it to proofread a sample sentence end to end.

For development, the `MISTRAL_API_KEY` environment variable is used when the Keychain has no key.

## Models

Prices per million tokens, as of October 2026, from
[Mistral's pricing page](https://docs.mistral.ai/inference/pricing). The app uses the `-latest`
aliases, which follow each line's newest release; the names and prices below are those releases.

| Model | Input | Cached input | Output | Context | Good for |
|---|---|---|---|---|---|
| `mistral-small-latest` → Mistral Small 4 (default) | $0.15 | $0.015 | $0.60 | 256k | Fast and cheap, strong in European languages; quick enough to check as you type. |
| `ministral-8b-latest` → Ministral 3 8B | $0.15 | $0.015 | $0.15 | — | The cheapest and quickest; misses more outside English. |
| `mistral-medium-latest` → Mistral Medium 3.5 | $1.50 | $0.15 | $7.50 | 256k | Better style and clarity suggestions; slower. |
| `mistral-large-latest` → Mistral Large 4 | $1.36 | $0.14 | $4.18 | — | Mistral's largest model; the best suggestions, the slowest. |

Any other model ID can be typed under *Other…* (a dated release such as `mistral-small-2603`
pins a version); the list button shows what your key can use. The usage meter in Settings → AI →
Usage prices requests from this table; models not in it show as unpriced. The Magistral reasoning
models were retired in July 2026 and aren't offered.

## What's particular to Mistral

- **Reasoning:** Small 4, Medium 3.5 and Large 4 can reason. The app sends
  `reasoning_effort: "none"` so checks come back quickly (the API also takes `minimal`, `low`,
  `medium`, `high` and `xhigh`).
- **Structured output:** checks and tone detection send `response_format: json_schema` with
  `strict: true` (Mistral's "custom structured outputs"), which every model above supports.
- **Safety prompt:** La Plateforme can prepend a safety prompt (`safe_prompt`); it's off by
  default and the app doesn't send it. No sampling parameters are sent either, so each model's
  default temperature applies.
- **Rate limits** are per workspace and depend on your plan; exceeding one returns HTTP 429, which
  the app shows as "Mistral is busy — try again shortly" and retries on the next edit. A 429 whose
  error says the quota or spend limit is used up shows as "Mistral rate limit or quota reached".
- **Prompt caching:** Mistral bills repeated prompt prefixes at a tenth of the input price; the
  app reads the cached-token count from each answer and prices it that way.

## Data handling

Requests go to `https://api.mistral.ai`, hosted in the EU. Mistral's terms for API data
(training, retention, the Data Processing Addendum for commercial customers) are in its
[Legal Center](https://legal.mistral.ai/terms); read the Commercial Terms of Service and the
Privacy Policy before sending confidential text, and check what your plan allows. Grammar Review
itself sends only the paragraphs you changed, the text whose tone you asked about and what you
rewrite or draft, and stores none of it.

## Troubleshooting

| The app says | Why | What to do |
|---|---|---|
| Invalid Mistral API key | 401 `Unauthorized`: the key is missing, mistyped or revoked. | Paste a key from console.mistral.ai and press Save, then Test. |
| Mistral rate limit or quota reached | 429 whose error reports a used-up quota or spend limit. | Raise the limit in the console. |
| Mistral doesn't have this model | 404: the model ID doesn't exist (any more). | Choose one from the list, or check the ID at docs.mistral.ai. |
| Mistral error: Input validation error | 422: a request field Mistral didn't accept. | Try another model; report it if it persists. |
| Mistral is busy — try again shortly | 429 rate limit, or a 5xx from La Plateforme. | Wait a moment; the next check tries again. |
| Mistral's answer was cut off | The answer hit `max_tokens`. | Rare for one paragraph; shorten the paragraph. |

Sources: [Models overview](https://docs.mistral.ai/getting-started/models/models_overview/),
[Pricing](https://docs.mistral.ai/inference/pricing), [Mistral Small 4](https://docs.mistral.ai/models/mistral-small-4-0-26-03),
[Mistral Medium 3.5](https://docs.mistral.ai/models/mistral-medium-3-5-26-04), [API reference](https://docs.mistral.ai/api/),
[Structured outputs](https://docs.mistral.ai/studio/conversations/structured-output/custom). All read in October 2026.
