# OpenAI

Grammar Review can check your writing with OpenAI's GPT models instead of Claude, using your own
OpenAI API key. You pay OpenAI directly for what the app uses; the app itself adds nothing.

_Verified against OpenAI's documentation on 21 October 2026 (pages listed at the end). The
integration has not yet been exercised against the live API with a real key._

## Getting a key

1. Sign in at [platform.openai.com](https://platform.openai.com) and open
   [Settings → API keys](https://platform.openai.com/settings/organization/api-keys).
2. Create a key for a project. Keys begin with `sk-` (project keys with `sk-proj-`). Copy it
   right away: OpenAI shows it only once.
3. Make sure the project can spend: OpenAI's API runs on prepaid credits. A free tier exists in
   some countries with a monthly usage cap; buying credits moves you to a paid tier (see
   [Rate limits and tiers](#rate-limits-and-tiers)).

## Setting it up in Grammar Review

Open Settings → AI, choose **OpenAI (API key)** as the service and paste the key. The app checks
it by listing the models your key can see (`GET /v1/models`) and keeps it in your Keychain; it
never leaves your Mac except in requests to `api.openai.com`.

Pick a model from the list, or type any model ID your project can use. **Test** proofreads a
sample sentence with the chosen model, exactly as a check would, and reports how long it took.

## Models

Prices are OpenAI's list prices in US dollars per million tokens, as of October 2026.

| Model | ID | Input | Cached input | Output | Good for |
|---|---|---|---|---|---|
| GPT-6 Luna | `gpt-6-luna` | $0.10 | $0.01 | $0.50 | As-you-type checks: fast, cheap, answers without a reasoning step. **Default.** |
| GPT-6.1 Sol | `gpt-6.1-sol` | $2.00 | $0.10 | $10.00 | Better style and clarity suggestions; thinks briefly before answering. |
| GPT-6 Astra | `gpt-6-astra` | $10.00 | $1.00 | $50.00 | OpenAI's most capable model. Rarely worth it for grammar; 100× Luna's price. |

A check sends the paragraph you just edited with a fixed instruction of roughly 500 tokens and
gets back a short list of edits, so a typical check costs about a hundredth of a cent with Luna,
around half a cent with Sol (its brief reasoning is billed as output) and a few cents with Astra.

**Why Luna is the default.** The app checks after every typing pause, so latency and cost matter
more than anything. Luna is OpenAI's cheapest current model and the only GPT-6 model that accepts
`reasoning_effort: none`, which makes it answer like a classic non-reasoning model: no reasoning
tokens to wait for or pay for. Sol and Astra don't take `none`, so the app asks them for `low`
effort, the least they accept.

**Cache prices.** GPT-6 models cache prompt prefixes of 1,024 tokens or more automatically and
bill cached reads at the "cached input" price; a write to the cache costs 1.25× the input price
(Luna $0.125, Sol $2.50, Astra $12.50). The check's fixed instruction is under that threshold and
the rest of the prompt changes with every paragraph, so checks are rarely cached in practice. The
usage meter in Settings → AI prices cached reads at the cached-input price (OpenAI reports them
with each answer) and everything else as input; your [usage page](https://platform.openai.com/usage)
is what counts.

**Models not offered.** The GPT-5 family (`gpt-5`, `gpt-5-mini`, `gpt-5-nano`) is scheduled for
shutdown on 11 December 2026, `gpt-4.1` and `gpt-4.1-mini` on 14 January 2027, `gpt-5.4-nano` and
`gpt-5.1` on 1 April 2027. You can still type their IDs while they last, but the app's usage
meter won't know their prices.

## How requests are made

Everything goes to `POST https://api.openai.com/v1/chat/completions` with `Authorization: Bearer
<key>`, following OpenAI's Chat Completions reference for reasoning models:

- `max_completion_tokens` caps the answer (`max_tokens` is deprecated and reasoning models reject
  it). The cap counts reasoning tokens too; the app leaves about 2,000 tokens of room plus one per
  character of the paragraph, so a `low`-effort think fits comfortably.
- The instruction goes in a `developer` message, which for reasoning models replaces `system`.
- `reasoning_effort` is `none` for Luna and `low` for every other model, including any ID you
  type. A model that doesn't accept the value answers with HTTP 400, which the app shows as
  "OpenAI error: …".
- Checks use Structured Outputs: `response_format: {type: json_schema, json_schema: {name,
  strict: true, schema}}`. The app's schema satisfies strict mode (every property required,
  `additionalProperties: false` on every object, an object at the root). All three models
  support it. Rewrites and tone detection ask for plain text.
- No `temperature`, `top_p` or other sampling parameters are sent, so the models' defaults apply.
- `stream` is `false`; nothing is retried. A `finish_reason` of `length` means the cap was hit
  and shows as "GPT's answer was cut off"; `content_filter` shows as "GPT declined to check this
  text".

Key validation and the model list use `GET /v1/models`; embedding models are left out of the list.

## Rate limits and tiers

OpenAI's limits depend on your usage tier, which depends on how much credit the project has
bought in total: **Free** (allowed countries only, $100 of usage a month), **Build** ($5 in
credits, $500 a month), **Launch** ($100, $5,000 a month) and **Grow** ($500, $200,000 a month).
At Build, Luna allows 5,000 requests and 2 million tokens a minute, Sol and Astra 5,000 requests
and 1 million tokens: far more than a grammar checker needs. The app sends at most three paragraph
requests at once.

Two kinds of HTTP 429 exist: a real rate limit (`rate_limit_error`, including `slow_down` when
traffic ramps up too fast) and spent credit or a spend limit (`insufficient_quota`,
`credit_balance_exhausted`, `project_spend_limit_exceeded`). The app shows a rate limit as "GPT
is busy — try again shortly", and spent credit or a spend limit as "OpenAI rate limit or quota
reached": waiting won't fix that one, so add credit or raise the limit in the OpenAI dashboard.

## Your data

Under OpenAI's [API data policy](https://developers.openai.com/api/docs/guides/your-data), text
sent through the API is not used to train OpenAI's models unless you opt in. OpenAI keeps API
inputs and outputs for up to 30 days for abuse monitoring, longer only where the law requires;
eligible customers can apply for Zero Data Retention, and data residency (EU and others) is a
per-project setting. The app sends only the paragraph being checked, or the selection being
rewritten, with its instructions: no file names, app names or anything else about you.

Grammar Review doesn't check text in terminals, password managers and code editors by default
(Settings → Apps).

## Environment variable

For development, `OPENAI_API_KEY` in the app's environment stands in for the Keychain when no key
is stored. It is the same variable OpenAI's SDKs read.

## Troubleshooting

| Message | Cause | What to do |
|---|---|---|
| Invalid OpenAI API key | HTTP 401: the key is wrong, revoked, or belongs to another organization or project. | Paste the key again from [API keys](https://platform.openai.com/settings/organization/api-keys), watching for spaces. |
| Enter your OpenAI API key / Add your OpenAI API key in Settings → AI | No key stored. | Add one in Settings → AI. |
| GPT is busy — try again shortly | HTTP 429 rate limit, or a 5xx from an overloaded model. | Wait a moment; the next check tries again. |
| OpenAI rate limit or quota reached | HTTP 429 that reports spent credit or a spend limit (`insufficient_quota`, `credit_balance_exhausted`, `…_spend_limit_exceeded`). | Add credit or raise the project's limit in the OpenAI dashboard. |
| Your OpenAI key can't use this model | HTTP 403: the project's model restrictions, or an unsupported country. | Allow the model in the project's settings, or choose another. |
| OpenAI doesn't have this model. Check the model in Settings → AI. | HTTP 404: a mistyped ID, a shut-down model, or one your key can't see. | Pick a listed model or fix the ID. |
| OpenAI error: Unsupported value: 'reasoning_effort' … | HTTP 400: a typed model doesn't take `low` (older non-reasoning models reject the field). | Use one of the listed models. |
| OpenAI error: … max_tokens … | HTTP 400 from a model that wants a different token cap. | Use one of the listed models. |
| GPT's answer was cut off | The answer hit `max_completion_tokens`, usually because the model reasoned at length. | Check a shorter paragraph, or switch to Luna. |
| GPT declined to check this text | OpenAI's content filter stopped the answer. | Nothing to do; other text checks normally. |
| GPT's answer wasn't in the expected format | The model returned something other than the edit list. | Try again; if it keeps happening with a typed model, use a listed one. |
| Couldn't reach OpenAI / You're offline | No connection to `api.openai.com`. | Check the network, proxy or firewall. |
| GPT took too long to respond | The request timed out (20 s). | Try again; prefer Luna. |
| Billing problem — check your OpenAI account | HTTP 402. | Check billing in the OpenAI dashboard. |

## Sources (read 21 October 2026)

- [Models](https://developers.openai.com/api/docs/models), with the pages for
  [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
  [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) and
  [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)
- [Pricing](https://developers.openai.com/api/docs/pricing)
- [Chat Completions reference](https://developers.openai.com/api/reference/resources/chat) and
  [List models](https://developers.openai.com/api/reference/resources/models/methods/list)
- [API overview: authentication](https://developers.openai.com/api/reference)
- [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- [Reasoning models](https://developers.openai.com/api/docs/guides/reasoning)
- [Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Rate limits](https://developers.openai.com/api/docs/guides/rate-limits) and
  [Error codes](https://developers.openai.com/api/docs/guides/error-codes)
- [Deprecations](https://developers.openai.com/api/docs/deprecations)
- [Your data](https://developers.openai.com/api/docs/guides/your-data)
