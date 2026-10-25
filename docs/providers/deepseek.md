# DeepSeek

Grammar Review can use DeepSeek's models instead of Claude, with your own API key, through
DeepSeek's OpenAI-compatible chat completions API. Checks, rewrites, tone detection and Write with
AI all go through it.

Verified against [api-docs.deepseek.com](https://api-docs.deepseek.com/) in October 2026. Nothing
was tested against the live API; the request and response shapes come from the API reference.

## Setting it up

1. Create a key at [platform.deepseek.com](https://platform.deepseek.com/api_keys) and top up the
   balance; the API is prepaid. Keys start with `sk-`.
2. In Grammar Review, open Settings → AI and choose **DeepSeek**.
3. Paste the key and press *Save*. It goes into your Keychain, never into the settings file.
   *Test* checks the key by listing the models it can use.
4. Pick a model and press *Test* under it to proofread a sample sentence end to end.

For development, the `DEEPSEEK_API_KEY` environment variable is used when the Keychain has no key.

## Models

Prices per million tokens in USD, as of October 2026, from
[DeepSeek's pricing page](https://api-docs.deepseek.com/quick_start/pricing). These are the peak
prices; **off-peak is half**. Peak hours are 01:00–04:00 and 06:00–10:00 UTC on weekdays (Chinese
public holidays excepted); the app prices requests at the peak rate regardless, so the usage meter
shows an upper bound.

| Model | Input | Cached input | Output | Context | Good for |
|---|---|---|---|---|---|
| `deepseek-flash` (default) → DeepSeek-V4.1-Flash | $0.30 | $0.006 | $1.20 | 1M | Fast and very cheap; quick enough to check as you type. |
| `deepseek-v4-pro` → DeepSeek-V4-Pro | $1.32 | $0.044 | $3.96 | 1M | Better style and clarity suggestions; slower. |

The older names `deepseek-chat`, `deepseek-reasoner` and `deepseek-v4-flash` still work but route
to current models; type one under *Other…* if you need it. The list button shows what your key can
use. Repeated prompt prefixes are served from DeepSeek's cache at the cached-input price; the app
reads the cache-hit count from each answer and prices it that way.

## What's particular to DeepSeek

- **JSON without a schema.** DeepSeek enforces that an answer is valid JSON
  (`response_format: json_object`) but can't be given a schema. The app puts the schema into the
  system prompt instead, which must mention JSON (it does), and its parser tolerates stray prose or
  code fences. Answers that still don't match show as "DeepSeek's answer wasn't in the expected
  format"; the next check tries again. DeepSeek also warns that JSON mode occasionally returns
  empty content, which the app treats the same way.
- **Thinking off.** Both models think by default (`reasoning_effort: high`). The app sends
  `reasoning_effort: "none"`, which turns thinking off, so checks come back quickly. Rewrites and
  drafts use the same setting.
- **Token limit:** `max_tokens` (up to 384K); the app sends a few thousand, enough for any
  paragraph, so JSON isn't cut off.
- **Sampling:** the app sends no `temperature` or `top_p`; DeepSeek ignores them in thinking mode
  anyway, and `presence_penalty`/`frequency_penalty` are deprecated.
- **Rate limits** are per account; exceeding them returns HTTP 429, and a busy server returns 503.
  The app shows both as "DeepSeek is busy — try again shortly" and tries again on the next edit.
  Answers can take a few seconds at busy times.
- **Prepaid:** when the balance runs out, DeepSeek returns 402 and the app says "Billing problem —
  check your DeepSeek account".

## Data handling

Requests go to `https://api.deepseek.com`; DeepSeek is based in China and processes and stores
API data there. Its [privacy policy](https://platform.deepseek.com/downloads/DeepSeek%20Privacy%20Policy.html)
and [terms of use](https://platform.deepseek.com/downloads/DeepSeek%20Open%20Platform%20Terms%20of%20Service.html)
set out how prompts and outputs may be used, including for improving the service; read them
before sending confidential or personal text, and consider whether your organisation allows it.
Grammar Review itself sends only the paragraphs you changed, the text whose tone you asked about
and what you rewrite or draft, and stores none of it.

## Troubleshooting

| The app says | Why | What to do |
|---|---|---|
| Invalid DeepSeek API key | 401 `Authentication Fails`: the key is wrong or revoked. | Paste a key from platform.deepseek.com and press Save, then Test. |
| Billing problem — check your DeepSeek account | 402 `Insufficient Balance`. | Top up at platform.deepseek.com. |
| DeepSeek is busy — try again shortly | 429 rate limit, or 503 `Server Overloaded`. | Wait; off-peak hours are quieter. |
| DeepSeek's answer wasn't in the expected format | JSON mode returned something the schema didn't allow, or empty content. | Try again; use `deepseek-v4-pro` if it keeps happening. |
| DeepSeek error: … | 400 or 422: a request DeepSeek didn't accept. | Try another model; report it if it persists. |

Sources: [Models and pricing](https://api-docs.deepseek.com/quick_start/pricing), [Chat completions](https://api-docs.deepseek.com/api/create-chat-completion),
[List models](https://api-docs.deepseek.com/api/list-models), [JSON output](https://api-docs.deepseek.com/guides/json_mode),
[Thinking mode](https://api-docs.deepseek.com/guides/reasoning_model), [Error codes](https://api-docs.deepseek.com/quick_start/error_codes).
All read in October 2026.
