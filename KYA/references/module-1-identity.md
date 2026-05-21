---
name: kya-prod-module-1-identity
description: "Module 1 — real identity linkage via get_user_profile. Loaded by SKILL.md while phase == module_1. Owns sign-in probe, short-TTL authPageUrl rendering, signed-in persistence, and the handoff to module_2."
---

# Module 1 — Identity Linkage

The first module verifies that the chat-session user is the same human
(or service principal) that owns the MetaComp / VisionX identity the AID
was issued for. There is no questionnaire here — just a probe and a
linkage record.

## Why this is its own module (and not just env_check)

Two reasons it can't collapse into `env_check`:

1. **`env_check` is operator health, not user identity.** A green env
   says "the platform is up"; it says nothing about who is on the other
   end of the chat.
2. **`authPageUrl` is short-TTL** (server-side token, minutes). It must
   be rendered in the **same turn** it's fetched and never persisted.
   `env_check` runs once at session start; Module 1 may re-render the
   sign-in card several turns later (after the user comes back from
   clicking the link), so it owns its own fresh call.

## Step 1 — Probe

On every turn while `phase == "module_1"`, call `get_user_profile()`
first. Three outcomes:

### 1a. 200 — signed in

The response carries `profile = { email, entity_name, registration_no,
kyc_level, country_code }`. Persist the linkage by calling:

```
submit_module_answer({
  aid,
  qid: "module_1_signed_in",
  text_answer: profile.email,
  evidence_refs: [],
  language,
  idempotency_key: `answer:${aid}:module_1_signed_in:1`
})
```

The server returns the new phase (`module_2`) and `next_qid`. Render the
sign-in confirmation block (`i18n.md → module_1_confirmed`) plus the
first question of Module 2 in the **same turn** — the user does not
need to type "continue" between Module 1 and Module 2.

The confirmation block names the entity (`profile.entity_name`) and the
email (`profile.email`) so the user can spot a wrong-account sign-in
immediately. If they signed in with the wrong account, the only recovery
is to sign out at the MetaComp dashboard and call `pause` here — the
skill cannot un-link an AID from a profile once `submit_module_answer`
has succeeded.

### 1b. 401 — not signed in

Response carries `error.details.authPageUrl`. Render the sign-in card
(`i18n.md → module_1_sign_in_card`) with the URL inlined verbatim,
including any `loginToken` query string. The user clicks it, completes
sign-in in their browser, and returns to the chat to say "done" /
"登好了" / "continue".

**Critical rules for `authPageUrl`:**

- Use the URL from **this turn's** `get_user_profile` response. Never
  read it from `session.profile`, session cache, or any prior turn —
  the token expires in minutes and an expired URL fails silently when
  the user clicks it.
- Do not append query parameters of your own (no `aid=...`, no
  `lang=...`). The server has already encoded everything it needs.
- Do not URL-encode, decode, or otherwise transform the value. Pass-through.

After rendering, stop and wait for the user.

### 1c. Other error envelopes

Route to `error-recovery.md` keyed by `error.category`. Common ones in
this phase:

- `forbidden` (403) — user is blocked from KYA (e.g. account under
  sanction review). Render the corresponding terminal message; do not
  retry, do not advance.
- `rate_limited` (429) — back off per `Retry-After` and re-probe.
- `server_error` (5xx) / `network_error` — retry-with-backoff per the
  policy in `mcp-contracts.md`.

## Step 2 — Handle the "I signed in" reply

When the user comes back with any continue-synonym (`done`, `登好了`,
`continue`, `好了`, `ok`), the skill is in `module_1` and must re-probe.
**Never trust the user's claim alone.** Common failure modes if you do:

- User typed "done" by reflex before actually completing sign-in →
  treat as signed in → `submit_module_answer` succeeds with an empty
  profile → AID is now linked to a phantom identity.
- User signed in with a different account than the AID was minted for →
  caught only if you re-probe and compare.

So the flow is: continue-synonym received → call `get_user_profile`
fresh → branch per 1a/1b/1c above. If 401 again, re-render the sign-in
card with the **just-returned** fresh URL and a one-line hint that we
didn't see the sign-in yet.

## Step 3 — Profile drift detection

If `session.profile` already has values from a prior turn AND this
turn's `get_user_profile` returns a profile with a different `email`
or `entity_name`, the user has switched accounts mid-session. This is
not necessarily wrong (they may have realised they signed in with the
wrong account in 1a's display), but it is consequential — the AID was
issued for the **original** profile and re-issuing against the new
profile may collide.

Handle by:

1. Calling `update_session_state({ profile: <new>, profile_drift: true })`.
   The server logs the drift for audit.
2. Rendering `i18n.md → profile_drift_warning` — tell the user we noticed
   the account switch and confirm they want to continue with the new
   identity.
3. On affirmative, proceed normally (the AID stays as minted; the
   linkage record will note the drift).
4. On negative, route to `pause` so the user can re-sign-in with the
   correct account.

## Resume into Module 1

If the user comes back from `paused` and the saved phase was `module_1`,
re-call `get_user_profile` immediately on resume. The previous
`authPageUrl` is definitely expired; you need a fresh one before
rendering anything.

## What Module 1 does NOT do

- It does not display the entity name or email anywhere except the
  confirmation block. Specifically, it does not pre-fill any later
  question with the user's name — the questionnaire is independent.
- It does not write to `session.profile` from any source other than a
  fresh `get_user_profile` response. The demo's `demo_owner` field does
  not exist here.
- It does not retry on a 401. A 401 is the expected steady state until
  the user clicks the link; treat it as a render trigger, not an error.
