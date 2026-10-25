# xAI (Grok)

Grammar Review can use xAI's Grok models instead of Claude, with your own API key. Checks,
rewrites, tone detection and Write with AI all go through xAI's chat completions API.

Verified against [docs.x.ai](https://docs.x.ai/developers/models) in October 2026. Nothing was
tested against the live API; the request and response shapes come from the reference pages.

## Setting it up

1. Create a key at [console.x.ai](https://console.x.ai/team/default/api-keys). Keys start with `xai-`.
2. In Grammar Review, open Settings → AI and choose **xAI (Grok)**.
3. Paste the key and press *Save*. It goes into your Keychain (one item per service), never into
   the settings file. *Test* checks the key by listing the models it can use.
4. Pick a model and press *Test* under it to proofread a sample sentence end to end.

For development, the `XAI_API_KEY` environment variable is used when the Keychain has no key.

## Models

Prices per million tokens, for prompts under 200k tokens (every request of this app is far
smaller). As of October 2026, from [xAI's pricing page](https://docs.x.ai/developers/pricing).

| Model | Input | Cached input | Output | Context | Good for |
|---|---|---|---|---|---|
| `grok-4.3` (default) | $1.25 | $0.20 | $2.50 | 1M | Fast and the cheapest; quick enough to check as you type. |
| `grok-4.5` | $2.00 | $0.30 | $6.00 | 500k | Stronger reasoning for hard sentences; slower. |
| `grok-4.7` | $2.00 | $0.50 | $6.00 | 500k | xAI's frontier model; the best style suggestions, the slowest. |

Any other model ID xAI offers can be typed under *Other…*; the list button shows what your key
can use (`GET /v1/models`). The usage meter in Settings → AI → Usage prices requests from this
table; models not in it show as unpriced.

## What's particular to xAI

- **Every Grok 4 model reasons, and reasoning can't be turned off.** The app sends
  `reasoning_effort: "low"`, the fastest setting, for every check. (`grok-4.3` also accepts
  `none`; the others take `low`, `medium`, `high` and, on 4.6 and 4.7, `xhigh`.) The reasoning
  comes back in a separate `reasoning_content` field and never reaches your text. Reasoning tokens
  are billed as output tokens.
- **Token limit:** xAI deprecated `max_tokens`; the app sends `max_completion_tokens`, which caps
  the visible answer only.
- **Structured output:** checks and tone detection send `response_format: json_schema` with
  `strict: true`, which Grok 4 models enforce. xAI treats `additionalProperties` as `false` by
  default; the app's schemas say so explicitly anyway.
- **Rejected parameters:** reasoning models refuse `presence_penalty`, `frequency_penalty` and
  `stop`. The app sends none of them, and no sampling parameters.
- **Rate limits** are per model and depend on your team's tier (cumulative spend since January
  2026): `grok-4.3` allows 37 requests per second and 10M tokens per minute at Tier 0, which an
  as-you-type checker never approaches. Exceeding a limit returns HTTP 429; the app shows "Grok is
  busy — try again shortly" and tries again on the next edit.
- **Long prompts cost double:** requests of 200k+ prompt tokens are billed at twice the rate. The
  app sends one paragraph at a time (at most the length cap in Settings), so this never applies.

## Data handling

Requests go to `https://api.x.ai`, with xAI's own regions (`us-east-1`, `us-west-2`, and
`eu-west-1` for some models). xAI's terms for API data (retention, training, enterprise
options) are in its [privacy policy](https://x.ai/legal/privacy-policy) and
[enterprise terms](https://x.ai/legal/terms-of-service-enterprise); read them before sending
confidential text. Grammar Review itself sends only the paragraphs you changed, the text whose
tone you asked about and what you rewrite or draft, and stores none of it.

## Troubleshooting

| The app says | Why | What to do |
|---|---|---|
| Invalid xAI (Grok) API key | xAI returned 401: the key is missing, mistyped or revoked. | Paste a key from console.x.ai and press Save, then Test. |
| Your xAI (Grok) key can't use this model | 403: your team doesn't have access to the model. | Ask your team admin, or pick another model. |
| xAI (Grok) doesn't have this model | 404: the model ID doesn't exist (any more). | Choose one from the list, or check the ID at docs.x.ai. |
| Grok is busy — try again shortly | 429 rate limit, or a 5xx from xAI. | Wait a moment; the next check tries again. Check [status.x.ai](https://status.x.ai) if it persists. |
| Grok's answer was cut off | The answer hit `max_completion_tokens`. | Rare for one paragraph; shorten the paragraph. |
| Grok's answer wasn't in the expected format | The JSON didn't match the schema. | Try again; if it keeps happening with a non-Grok-4 model, use one of the models above. |

Sources: [Models and pricing](https://docs.x.ai/developers/models), [Chat completions
reference](https://docs.x.ai/developers/rest-api-reference/inference/chat-completions),
[Models endpoints](https://docs.x.ai/developers/rest-api-reference/inference/models),
[Structured outputs](https://docs.x.ai/developers/model-capabilities/text/structured-outputs),
[Reasoning](https://docs.x.ai/docs/guides/reasoning), [Rate limits](https://docs.x.ai/docs/key-information/consumption-and-rate-limits),
[Error codes](https://docs.x.ai/developers/debugging). All read in October 2026.
