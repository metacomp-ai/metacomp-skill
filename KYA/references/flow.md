---
name: kya-prod-flow
description: "Full state machine for KYA production self-assessment. Defines every phase, exit conditions, auto-progression rules, and pause/resume semantics. Loaded by SKILL.md when phase routing is non-trivial."
---

# Flow — State Machine

The skill is a finite state machine. The **server** is SOR for `phase`;
the skill drives transitions by calling domain MCPs (which return the new
phase) and `update_session_state` (for non-domain fields).

## State diagram

```
        (no session yet)
              │
              ▼
       awaiting_url
              │  user replies with valid registry URL
              ▼
      ┌── trigger_tier? ──┐
      │                   │
      │ hard              │ soft
      ▼                   ▼
                       gate
                          │  yes
                          ▼
                                 (no → done(declined))
      ▼ ───── env_check ◀──┘
              │
              │  8/8 pass (in same turn)
              ▼
       aid_issue
              │
        ┌─────┴─────┐
        │           │
        │ new/reuse │ rejected_already_verified
        ▼           ▼
     welcome     done(rejected_already_verified)
        │
        │  user says "Ready / 开始"
        ▼
     module_1
        │  get_user_profile returns 200 with email
        ▼
     module_2  (N questions per module_totals, persisted one-by-one)
        │
        ▼
     module_3  (M questions per module_totals, persisted one-by-one)
        │
        ▼
     results_and_consent
        │  exact consent phrase matched, submit_consent → 200
        ▼
     (skill calls submit_kya_application)
        │
        ▼
     done(submitted)
```

`paused` is an orthogonal state — any non-terminal phase can transition to
`paused` via the `pause` command and back via `resume`.

## Phase reference

### `awaiting_url`

Entered immediately on first trigger. Emits the bilingual registry URL
prompt and stops.

Exit on:
- Valid URL → `gate` (soft) or `env_check` (hard).
- Invalid URL → stay in `awaiting_url`, re-prompt.

### `gate` (soft trigger only)

Bilingual "走不走 KYA?" prompt.

Exit on:
- Affirmative (`yes`, `start`, `开始`, `是`, `好`, `可以`, `go`) → `env_check`.
- Negative (`no`, `not now`, `否`, `不用`, `以后`, `cancel`, `取消`) → `done(declined)`.
- Unrecognised → stay in `gate`, re-emit with `请回复 是 或 否 / Please reply yes or no.`

### `env_check`

Calls the dedicated `run_env_check({ tg_user_id })` MCP — the server
probes every downstream dependency and returns one consolidated result.
The skill does not do any inline reachability probing; conflating
user-side network with operator-side outage was a demo-era footgun.

Render a single bilingual line per `checks[i]` from the response, using
`checks[i].label_{lang}` for the user-facing subsystem name and a
✓ / ✗ glyph driven by `checks[i].ok`. No banner, no decorations, no
internal `key` exposure.

On `all_ok == true`: auto-progress to `aid_issue` and call
`issue_kya_aid` in the **same turn**. The user is not expected to reply
between the env_check summary and the welcome banner.

On `all_ok == false`: route to `error-recovery.md → env_check_fail`.
Stay in `env_check`. The skill does not auto-retry — these failures are
operator incidents, not transient blips. The user is told to come back
later.

### `aid_issue`

Call `issue_kya_aid({ tg_user_id, profile, idempotency_key })`. The server
returns one of:

- `{ status: "ok", aid, aid_status: "new" }` → `welcome` (same turn).
- `{ status: "ok", aid, aid_status: "reuse" }` → `welcome` (same turn).
- `{ status: "rejected", reason: "already_verified" }` → `done(rejected_already_verified)` immediately.
- Any other non-200 → `error-recovery.md → aid_issue_fail`. Stay in `aid_issue`.

### `welcome`

Render the bilingual welcome card (see `i18n.md → welcome_card`). It names
the entity (from `session.profile`, NOT from any hardcoded demo mock —
demo's `demo_owner` field does not exist here) and tells the user what
the three modules cover.

Exit on:
- User affirms readiness (`Ready`, `开始`, `start`, `继续`, `go`) → `module_1`.
- Any other reply that isn't a recognised command → gently re-emit the
  ready prompt.

### `module_1`

Owned by `references/module-1-identity.md`. Probes sign-in via
`get_user_profile`. On 401, renders the `authPageUrl` inline. On 200 with
email, calls `submit_module_answer({ qid: "module_1_signed_in", ... })`
to persist the signal, then advances to `module_2`.

### `module_2` and `module_3`

Both owned by `references/module-2-3-questionnaire.md`. Each module's
question count comes from `session.question_bank.module_totals[<module>]`
— the bank is the SOR for both content and cardinality. Per question:
render → accept answer + (optional) evidence → call
`submit_module_answer` → increment `current_q_index`.

Exit conditions per module:
- All `module_totals[<module>]` answers submitted successfully → advance
  to next phase. Detection: the server's `submit_module_answer` response
  returns `next_qid: null` and a new `phase`, which is the authoritative
  signal — never compute "are we done" from a local counter.
- User issues `back` / `redo` / `pause` / `restart module` — handled by
  the Commands table in `SKILL.md`.

### `results_and_consent`

Owned by `references/consent.md`. Renders the consent phrase block
directly — **no recap of the 10 questions/answers**. The user has just
answered them turn-by-turn; re-listing everything is noise (and in
production, regenerating the recap from cached state risks divergence
from what the server actually stored). The server has the canonical
record; the audit surface lives there, not in chat.

On exact phrase match: call `submit_consent`, then
`submit_kya_application`, then transition to `done(submitted)`.

### `paused`

Set by the `pause` command. Skill emits a bilingual ack and stops. On
`resume`, server returns `{ phase: paused, phase_before_pause: <prior> }`
— the skill calls `update_session_state({ phase: phase_before_pause })`
and re-renders.

### Terminal phases

- `done(submitted)` — application is in backend pipeline. Render the
  submission acknowledgment from `i18n.md → submitted_ack`, including the
  `application_id` returned by `submit_kya_application`. The user can use
  this ID to follow up out-of-band.
- `done(declined)` — user opted out at the gate. KYA can be re-initiated
  by sending the trigger again.
- `done(rejected_already_verified)` — server refused AID issuance because
  the underlying account is already verified. Direct the user to the
  existing identity instead.

## Auto-progression vs. user-driven transitions

Auto-progressed (same turn, no user input between):
- `env_check` → `aid_issue` (after 8/8 pass).
- `aid_issue` → `welcome` (after `new` / `reuse`).
- `results_and_consent` → `done(submitted)` (after consent match,
  `submit_consent` 200, `submit_kya_application` 200).

User-driven:
- `welcome` → `module_1` (waits for "Ready").
- `module_1` → `module_2` (waits for sign-in completion signal — user
  saying "done" / `登好了` after they click the `authPageUrl`).
- Every question advance in `module_2` / `module_3` (waits for user
  answer).

## Idempotency on resume

When `get_session_state` returns the same `phase` two turns in a row with
no advance, do **not** re-call mutating MCPs — that's a sign of either a
transient server error or a user who hasn't replied yet. Re-render the
current step using the cached question bank and answers. The
`idempotency_key` rules in `mcp-contracts.md` guarantee a duplicate
submission is a no-op, but the user-facing render should still be
idempotent (no progress bar flicker, no re-asking a question the user
already answered).
