# Anthropic (Claude)

Claude is Grammar Review's default AI service: it checks grammar, clarity and style, rewrites
selections, writes with AI and detects tone, using your own Anthropic API key. You pay Anthropic
directly for what the app uses; the app itself adds nothing.

_Verified against Anthropic's documentation on 22 October 2026 (pages listed at the end). The
integration has not yet been exercised against the live API with a real key._

## Getting a key

1. Sign in to the [Claude Console](https://platform.claude.com) and open
   [API keys](https://platform.claude.com/settings/keys).
2. Click **Create key**. Keys begin with `sk-ant-api`. Copy it right away: the Console shows it
   only once.
   - **Scope it to one workspace.** Grammar Review sends no `anthropic-workspace-id` header, so a
     key that works across several workspaces is turned away with "This API key isn't scoped to a
     workspace".
   - **Mind the expiration.** The Console offers 3 hours to 30 days, or **Never**. An expired key is
     rejected as invalid, and Anthropic emails you before a key of a week or longer expires.
3. Add credit on the [Billing](https://platform.claude.com/settings/billing) page: the API is
   prepaid.

## Setting it up in Grammar Review

Open Settings → AI, choose **Claude (Anthropic API)** as the service and paste the key (or paste
it during onboarding). The app checks the key with a free token count (`POST /v1/messages/count_tokens`)
for the chosen model and keeps it in your Keychain; it never leaves your Mac except in requests
to `api.anthropic.com`.

## Models

Prices are Anthropic's list prices in US dollars per million tokens, as of October 2026. Cache
writes are for the default five-minute cache.

| Model | ID | Input | Cache write | Cache read | Output | Good for |
|---|---|---|---|---|---|---|
| Claude Haiku 5.5 | `claude-haiku-5-5` | $0.10 | $0.125 | $0.01 | $0.50 | As-you-type checks: fast and cheap. **Default.** |
| Claude Sonnet 5.5 | `claude-sonnet-5-5` | $2.00 | $2.50 | $0.10 | $10.00 | Better style and clarity suggestions; slower. |
| Claude Opus 5.5 | `claude-opus-5-5` | $4.00 | $5.00 | $0.20 | $20.00 | Highest quality; slowest and most expensive. |

A check sends the paragraph you just edited with a fixed instruction of about 500 tokens and gets
back a short list of edits, so a typical check costs about two hundredths of a cent with Haiku,
under half a cent with Sonnet and about a cent with Opus. Thinking at low effort is billed as
output.

**Haiku's second price.** Claude Haiku 5.5 costs five times as much ($0.50 / $2.50) for a
request whose prompt is over 100,000 tokens. Grammar Review never sends one: Settings caps the
text sent to AI at 20,000 characters, and a check sends only the changed paragraphs.

**Cache prices.** The fixed instruction is marked for caching. Claude 5.5 models cache prompts of
512 tokens or more, which the instruction is close to, so some checks read it from the cache and
some don't. Sonnet 5.5 and Opus 5.5 bill cache reads at 0.05× input rather than the usual 0.1×.
The usage meter in Settings → AI prices cache writes and reads at these rates (Anthropic reports
them with each answer); the [Usage](https://platform.claude.com/usage) page in the Console is
what counts.

**Other models.** Claude Fable 5.1 ($10 / $50) is Anthropic's most capable model and far more
than grammar needs, so Settings doesn't offer it. When a safety classifier declines a Sonnet or
Opus request, Anthropic may answer with another model (see below); the meter knows the prices of
Claude Opus 5, Sonnet 5, Opus 4.8 and Fable 5.1 for that case.

## How requests are made

Everything goes to `POST https://api.anthropic.com/v1/messages` with the key in `x-api-key`
(which Anthropic still accepts alongside `Authorization: Bearer`) and `anthropic-version:
2026-10-21`, the current API version:

- The instruction goes in `system`, marked `cache_control: {type: "ephemeral"}`; the paragraph
  and writing goals go in the one `user` message. There is no assistant prefill: the 5.5 models
  reject it.
- `output_config.effort` is `low` for checks, rewrites, Write with AI and tone detection, and
  `thinking` is left out. The 5.5 models think adaptively by default; Opus 5.5 can't turn thinking
  off at all and Sonnet 5.5 only with a setting of its own, so one lever, effort, serves all three.
  Thinking counts toward `max_tokens`; for a check the app leaves about 2,000 tokens of room plus
  one per character of the paragraph.
- Checks and tone detection use structured outputs: `output_config.format: {type: json_schema,
  schema}`. Rewrites and Write with AI ask for plain text.
- No `temperature`, `top_p` or `top_k`: API version 2026-10-21 rejects them on every model.
- Sonnet 5.5 and Opus 5.5 requests opt into server-side fallbacks (`fallbacks: "default"` with
  the `server-side-fallback-2026-07-01` beta): when a safety classifier declines, Anthropic
  retries on a model that can answer, and the app reads the text after the `fallback` block. If
  your organization doesn't have the beta, the API says so with a 400 and the app stops asking for
  it until it restarts. Haiku 5.5 has no server-side fallback, so the app doesn't ask.
- `stream` is off. A 429, 529 or 5xx is retried once, after `retry-after` (at most 5 seconds) or
  one second. A `stop_reason` of `max_tokens` shows as "Claude's answer was cut off", `refusal` as
  "Claude declined to check this text".

## Rate limits and tiers

Anthropic places organizations on a usage tier: **Start**, **Build** or **Scale** (new
organizations may begin on a lower Evaluation tier). Each has a monthly spend cap, $500, $1,000
and $200,000 respectively. At Start, Haiku 5.5, Sonnet 5.5 and Opus 5.5 each allow 1,000 requests,
2 million input tokens and 400,000 output tokens a minute: far more than a grammar checker needs.
Cached reads don't count toward the input limit. The app sends at most three paragraph requests at
once. See your tier on the [Rate limits](https://platform.claude.com/usage/limits) page.

Three limits can stop requests:

- **A rate limit**: HTTP 429 with a `retry-after` header. The app retries once and then shows
  "Claude is busy — try again shortly".
- **The tier's monthly spend cap**: also HTTP 429, but with `error_code:
  enforced_spend_limit_reached` and no `retry-after`. Requests fail until the first of the next
  month (UTC) or until the organization moves to a higher tier, so the app doesn't retry and says
  "Your Anthropic organization reached its monthly usage limit".
- **A spend limit you set** on the Billing page, for the organization or a workspace: HTTP 400
  "You have reached your specified … API usage limits", shown as "You've reached the spend limit
  set in the Claude Console".

## Your data

Under Anthropic's commercial terms, API inputs and outputs are
[not used to train models](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training)
unless you choose to share them (for example by sending feedback), and they are
[deleted within 30 days](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data),
longer only when a request is flagged under the Usage Policy or the law requires it. Zero data
retention is available by agreement. The app sends only the paragraph being checked, or the text
being rewritten, with its instructions: no file names, app names or anything else about you.

Grammar Review doesn't check text in terminals, password managers and code editors by default
(Settings → Apps).

## Environment variable

For development, `ANTHROPIC_API_KEY` in the app's environment stands in for the Keychain when no
key is stored. It is the same variable Anthropic's SDKs read.

## Troubleshooting

| Message | Cause | What to do |
|---|---|---|
| Invalid API key | HTTP 401: the key is wrong, revoked, disabled or expired. | Paste the key again from [API keys](https://platform.claude.com/settings/keys), or create a new one. |
| This API key isn't scoped to a workspace. Create one for a single workspace. | HTTP 400: the key works across workspaces, and the app doesn't name one. | Create a key scoped to one workspace. |
| Your Anthropic credit balance is too low | HTTP 400. | Add credit on the [Billing](https://platform.claude.com/settings/billing) page. |
| You've reached the spend limit set in the Claude Console | HTTP 400: an organization or workspace spend limit you set. | Raise or remove it on the Billing page. |
| Your Anthropic organization reached its monthly usage limit | HTTP 429 with `enforced_spend_limit_reached`: the tier's monthly cap. | Wait for the next month, or use **Request tier increase** on the [Rate limits](https://platform.claude.com/usage/limits) page. |
| Claude is busy — try again shortly | HTTP 429 rate limit, 529 overloaded, or a 5xx, after one retry. | Wait a moment; the next check tries again. Check [status.anthropic.com](https://status.anthropic.com) if it persists. |
| Billing problem — check your Anthropic account | HTTP 402. | Check billing in the Console. |
| Claude error: … (or "Your API key isn't allowed to use this model") | HTTP 403: the organization or workspace isn't allowed this request, for example a region restriction or identity verification. Other errors also show Anthropic's message this way. | Do what the message says, or check the workspace's settings in the Console. |
| This model isn't available for your API key | HTTP 404: the model doesn't exist or your organization can't use it. | Choose another model in Settings → AI. |
| Text is too long for Claude | HTTP 413. | Check a shorter text. |
| Claude's answer was cut off | The answer hit `max_tokens`, usually after a long think. | Check a shorter paragraph, or switch to Haiku. |
| Claude declined to check this text | `stop_reason: refusal`: a safety classifier declined, and no fallback answered. | Nothing to do; other text checks normally. |
| Unexpected response from Claude | The answer wasn't the expected edit list. | Try again. |
| Couldn't reach Claude / You're offline | No connection to `api.anthropic.com`. | Check the network, proxy or firewall. |
| Claude took too long to respond | The request timed out (20 s for checks, longer for long rewrites). | Try again; prefer Haiku. |

## Sources (read 22 October 2026)

- [Models overview](https://platform.claude.com/docs/en/about-claude/models/overview) and
  [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Versions](https://platform.claude.com/docs/en/api/versioning) and
  [Migrating to API version 2026-10-21](https://platform.claude.com/docs/en/api/migration-2026-10-21)
- [Authentication](https://platform.claude.com/docs/en/manage-claude/authentication)
- [Errors](https://platform.claude.com/docs/en/api/errors) and
  [Rate limits](https://platform.claude.com/docs/en/api/rate-limits)
- [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching),
  [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) and
  [Structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [API and data retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention),
  [How long do you store my organization's data?](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
  and [Is my data used for model training?](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training)
