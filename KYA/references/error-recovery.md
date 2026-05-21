---
name: kya-prod-error-recovery
description: "Canonical error handling for every non-success MCP envelope. Routes by error.category and code; defines user-facing copy, retry behaviour, and phase outcome. Loaded on any non-200 response and whenever a recovery decision is ambiguous."
---

# Error Recovery

The skill never improvises error prose. Every non-success envelope is
routed through this file to the right user-facing line, retry policy,
and phase outcome.

## Routing priority

When the response is a failure envelope:

1. If `error.user_message` is populated → render it verbatim (bilingual
   block, picking the active language). Server-supplied copy always wins
   because it carries context the skill doesn't have (specific limits,
   ticket numbers, regulator references).
2. Else route by `error.code` if there's an entry in the table below.
3. Else route by `error.category`.

Never expose `error.code`, `error.details`, or `trace_id` to the user.

## Per-code handlers

### `auth_required` (401, category: auth)

Phase-dependent:
- In `module_1`: this is the **expected** state until the user signs in.
  Not an error — render the sign-in card per `module-1-identity.md`.
- In any other phase: the user's session expired or was revoked
  mid-flow. Render `i18n.md → auth_expired` and route to `module_1` via
  `update_session_state({ phase: "module_1" })`. The user re-links and
  picks up where they left off — their answers and evidence persist
  because they're keyed on `aid`, not on the auth session.

### `forbidden` (403, category: auth)

Account is blocked from KYA — sanction list, internal hold, or
compliance flag. Terminal in this skill. Render `i18n.md →
forbidden_terminal` and route to `done(rejected_already_verified)` via
`update_session_state`. The user must resolve the block out-of-band; the
chat surface cannot.

### `conflict_already_verified` (category: conflict)

Returned by `issue_kya_aid`. Server refused because the underlying
account already has a Trust Mark. Route to
`done(rejected_already_verified)` immediately. Render `i18n.md →
already_verified`.

### `conflict_idempotency` (category: conflict)

Same `idempotency_key` was submitted previously with a **different**
payload. This is a skill bug — the key should be deterministic per
logical operation. Log the trace_id (server-side log, not user chat),
render `i18n.md → internal_error`, and stay in the current phase. Do
not retry; do not invent a new key (that papers over the bug and
poisons audit).

### `conflict_phase` (category: conflict)

Tried to mutate in a phase that disallows it. Symptom of a stale local
cache. Call `get_session_state` and re-derive the right action from the
returned phase. Do not re-attempt the original call until the cache is
refreshed. If the second attempt also hits `conflict_phase`, surface
`i18n.md → internal_error` — the skill is genuinely out of sync.

### `validation_failed` (category: validation)

The server-supplied `user_message` is the truth. Render it. Stay in the
current phase. Do not retry without a new user input (a fresh file, a
re-typed consent phrase, etc.) — the validation will fail again on the
same input.

### `av_scan_rejected` — this code does not appear

The server returns AV outcomes as a 200 with `av_status == "rejected"`,
not a failure envelope. See `evidence-handling.md`. If you see
`av_scan_rejected` as an error code, treat as `validation_failed`.

### `rate_limited` (429, category: rate_limit, retryable: yes)

Back off per `Retry-After` (default: 5s if header absent). Retry up to
2 times. If still failing after 2 retries, route to `transient_fail`.

The retry happens silently — no user-facing line on the first retry.
Show `i18n.md → please_wait` on the second retry to acknowledge the
delay.

### `server_error` (5xx, category: server, retryable: yes)

Same retry policy as `rate_limited`. After exhausting retries, route to
`transient_fail`.

### `network_error` (category: network, retryable: yes)

Same retry policy. After exhausting retries, route to `transient_fail`.

## Per-category fallbacks

If the code is not in the table above, route by category:

| Category | Render | Phase outcome |
|---|---|---|
| `auth` | `i18n.md → generic_auth_error` | Stay (or route to module_1 if mid-flow). |
| `validation` | `i18n.md → generic_validation_error` | Stay; wait for new input. |
| `conflict` | `i18n.md → internal_error` | Stay; refresh `get_session_state`. |
| `rate_limit` | `i18n.md → please_wait` | Retry per policy. |
| `server` / `network` | `i18n.md → transient_fail` after retry exhaustion | Stay. |

## Named recovery scenarios

These are the ones the rest of the skill references by name. Same
copy keys, called out separately because they have phase-specific
nuance.

### `env_check_fail`

`run_env_check` returned `all_ok: false`. List the failed subsystems
using their `label_{lang}` and tell the user this is an operator
incident — they can come back later. Render `i18n.md →
env_check_fail`. Stay in `env_check`. Do not auto-retry; env failures
typically persist on the order of minutes-to-hours.

### `aid_issue_fail`

`issue_kya_aid` failed with a non-conflict, non-rejection error. If
retryable, retry per policy. If non-retryable after retries, render
`i18n.md → aid_issue_fail` and stay in `aid_issue`. The user can
issue `resume` to retry; the same idempotency key guarantees no
duplicate AIDs.

### `question_bank_unavailable`

`get_question_bank` failed past the retry budget. Render `i18n.md →
question_bank_unavailable`. Stay in `env_check`. There is no client-side
fallback bank — letting a stale local copy diverge from the
regulator-approved bank is worse than telling the user to come back.

### `transient_fail`

Generic landing for retryable categories that have exhausted retries.
Render `i18n.md → transient_fail`. The session stays put; on the user's
next message, retry from the current phase using the same idempotency
keys.

### `av_rejected` (not an error envelope — see `evidence-handling.md`)

`upload_evidence` returned 200 with `av_status: rejected`. Drop the
ref. Render `i18n.md → evidence_av_rejected` asking for a different
file.

### `submit_application_fail`

`submit_kya_application` failed non-retryably **after** consent already
succeeded. The consent record exists; the application does not. This is
operationally awkward and the skill must not pretend submission worked.
Render `i18n.md → submit_application_fail` and route to `paused`. The
user (or operator) can resume later; the same idempotency key will
either retry cleanly or surface the same error.

## Retry budgets in one place

| Class | Retries | Backoff |
|---|---|---|
| `rate_limited` | 2 | `Retry-After` header, default 5s |
| `server_error` | 2 | Exponential: 1s, 3s |
| `network_error` | 2 | Exponential: 1s, 3s |
| Anything else | 0 | n/a |

**Same idempotency key on every retry.** Never refresh the key on a
retry — that defeats the entire point of idempotency.

## What the skill never does in an error path

- Silently advance the phase. If you cannot complete the current step,
  stay in the current step.
- Show internal IDs, codes, or stack info to the user.
- Loop indefinitely. Every retryable failure has a budget; every
  non-retryable failure terminates the attempt.
- Mix recovery paths. A 401 in Module 1 is normal; a 401 in
  `results_and_consent` is auth expiry. Never confuse them by sharing
  copy.
- Hide a non-retryable failure as "we're still working on it". If
  submission failed, say so.
