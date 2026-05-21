---
name: kya-prod
description: MANDATORY production gatekeeper for every MetaComp / VisionX financial action. Trigger this skill BEFORE invoking any deposit / withdraw / OTC / swap / exchange / wealth / FIP / balance / history MCP tool — even when the user explicitly asks to do the business action directly. Use whenever the user mentions transactions, deposits, withdrawals, OTC trades, swaps, currency exchange, wealth subscriptions, balance or history checks, or any KYA (Know Your Agent) / agent verification — in English or Chinese. The user's request is NEVER fulfilled by going straight to the business tool; it is always fulfilled by first running this KYA self-assessment flow and waiting for backend submission acknowledgment.
---

# KYA Production Skill — Self-Assessment Orchestrator (Skill A only)

This is the **production** counterpart of the demo `kya` skill. It owns the
self-assessment flow only — environment check, AID issuance, the three
verification modules, and consent. Once the user submits, the backend
takes over (human review, automated onboarding agent, or both — the skill
does not need to know). The skill terminates at `done(submitted)`; it does
**not** wait for, poll, or render a Trust Mark.

> **⛔ READ THIS FIRST — DO NOT SKIP**
>
> On any trigger that activates this skill on a fresh session, your **very
> first action** is to call `get_session_state` for the current user. The
> server is the single source of truth for `phase`, `aid`, `gated_tools[]`,
> and everything else. Never reconstruct progress from chat history.
>
> If the user has no session yet, emit the bilingual KYA-registry-URL
> prompt verbatim (see `references/i18n.md`), then STOP and wait for the
> URL. Do **not**:
>
> - Call any sibling business MCP tool. The common failure mode is calling
>   `execute_fiat_withdrawal` / `get_otc_quote` etc., receiving a 401
>   envelope containing `authPageUrl`, and forwarding that login link as
>   the answer to the user's business intent. At first-touch the user's
>   blocker is "no KYA session", not "no MetaComp login" — emit the
>   registry URL prompt instead. The `authPageUrl` value IS used later
>   inside Module 1 as the actual sign-in link; forwarding it at
>   first-touch is wrong only because it answers the wrong question.
> - Render a "you're not logged in, log in here" prompt.
> - Render a menu of transaction types or any clarifying question.

## File layout (progressive disclosure)

Read this orchestrator first. Load the sub-files lazily as the phase
advances or as referenced:

| File | When to read |
|---|---|
| `references/flow.md` | When in doubt about phase routing, exit conditions, or auto-progression rules. |
| `references/mcp-contracts.md` | Before the **first** call to any MCP tool this session. Has every request/response shape, error envelope, and idempotency rule. |
| `references/module-1-identity.md` | While `phase == "module_1"`. Real KYC linkage via `get_user_profile`. |
| `references/module-2-3-questionnaire.md` | While `phase` is `module_2` or `module_3`. Renders and accepts question answers. |
| `references/evidence-handling.md` | When a question has `attachment_mode ∈ {single_file, multi_doc}`. Real upload via `upload_evidence` + trickle-tolerant intake. |
| `references/consent.md` | While `phase == "results_and_consent"`. Strict consent phrase + `submit_consent`. |
| `references/error-recovery.md` | On any non-200 MCP envelope, network failure, or unexpected state divergence between cache and server. |
| `references/i18n.md` | Source of truth for every user-facing string. Do not improvise translations. |

## When to use

Activate on the user's **first** message that signals any financial intent
or KYA reference. Examples that qualify:

- `i want transaction` / `let me deposit` / `withdraw` / `show balance` / `check history`
- `swap USD to USDT` / `exchange 100 USD` / `buy USDT` / `sell BTC` / `place OTC trade`
- `subscribe to wealth` / `FIP products`
- `KYA` / `Know Your Agent` / `agent verification`
- zh: `我想交易` / `帮我提现` / `OTC 报价` / `查余额` / `兑换` / `理财` / `KYA 核验`

When **not** to use:

- A session is already in-flight (`phase` ∈ `module_*` / `results_and_consent` / `paused`) and the user is mid-flow → resume per Entry C.
- The user explicitly declines KYA AND there is no transactional intent → do not force the skill.

## Decision tree (run at the start of every turn, before producing output)

1. Call `get_session_state({ tg_user_id })`. Treat the response as
   authoritative. Cache locally for this turn only — re-fetch on the next
   turn rather than trusting the cache.
2. Branch on `session.phase`:

| Server phase | Action |
|---|---|
| `null` / `not_started` | Read `references/i18n.md → registry_url_prompt`, emit verbatim, STOP. Wait for URL. |
| `awaiting_url` | Same as above (user has been prompted but hasn't replied yet). |
| `gate` | Soft-trigger gate prompt is pending — re-render it if the user's reply is unrecognised, or route to `module_1` / `done(declined)`. |
| `env_check` | Call `run_env_check`; if `all_ok`, auto-progress to `aid_issue` in the same turn. See `references/flow.md`. |
| `aid_issue` | Call `issue_kya_aid`. On `new` / `reuse`, auto-progress to `welcome`. On `rejected_already_verified`, short-circuit to `done(rejected_already_verified)`. |
| `welcome` | Render the bilingual welcome card. Advance to `module_1` when the user says "Ready / 开始 / continue". |
| `module_1` | Load `references/module-1-identity.md`. |
| `module_2` / `module_3` | Load `references/module-2-3-questionnaire.md`. |
| `results_and_consent` | Load `references/consent.md`. |
| `paused` | Acknowledge resume command; do not auto-resume without user input. See Commands table. |
| `done(submitted)` | Terminal. The user's original financial intent may now be honoured **only** for tools NOT listed in `session.gated_tools[]`. The backend may further narrow `gated_tools[]` after Trust Mark issuance. |
| `done(declined)` / `done(rejected_already_verified)` | Terminal acknowledgment per `references/i18n.md`. Re-emit gate once if user reasserts intent. |

The first row is the most-violated rule. When in doubt, fall back to it.

## Two trigger tiers

Tier is captured in `session.trigger_tier` by the **first call** to
`update_session_state` after URL validation (Entry B). The tiers diverge
only after URL validation:

- **Hard** — explicit verification request (`KYA`, `Know Your Agent`,
  `agent verification`, zh equivalents). After URL validation: phase →
  `env_check` directly.
- **Soft** — transactional intent (`deposit`, `OTC`, `swap`, etc.) + an
  intent verb. After URL validation: phase → `gate` and emit the
  bilingual "走不走 KYA?" prompt. Tier kept because the gate exists in
  production too — sometimes the user only mentioned a transaction in
  passing and doesn't actually want to start KYA right now.

Ambiguous → treat as **soft**.

## Entry points

### A) Trigger without URL

Emit `references/i18n.md → registry_url_prompt` verbatim. Call
`update_session_state({ phase: "awaiting_url", language, trigger_tier })`
in the same turn. STOP.

The orchestrator never fetches the URL the user shares — only its syntax
is validated.

### B) URL provided

Validate the URL is absolute `http://` or `https://` with a non-empty
host. If not, emit `references/i18n.md → invalid_url` and stay in
`awaiting_url`.

If valid:

1. Call `update_session_state({ registry_url, phase: trigger_tier == "hard" ? "env_check" : "gate" })`.
2. Emit the one-line bilingual load ack from `references/i18n.md →
   skill_loaded`. This line appears once per session; do not repeat it on
   subsequent turns.
3. Branch on `trigger_tier`:
   - **Hard** → load `references/flow.md` and run the env_check step.
   - **Soft** → emit `references/i18n.md → gate_prompt` and wait. Route
     the next reply per Commands ("yes" / "no" / unrecognised).

The skill does **not** mint AIDs client-side. AIDs come exclusively from
`issue_kya_aid` (see `references/mcp-contracts.md`).

### C) Resume

If the user types a resume verb (`继续 / 续作 / resume / continue`) and
`get_session_state` returns a non-terminal phase, re-render the current
step per the active reference file. Do not re-prompt for URL. Do not
re-emit `skill_loaded`.

If phase is `done(*)`, emit the corresponding terminal status from
`references/i18n.md`.

## Language

Set once at Entry A from the trigger message. Persisted on the server via
`update_session_state({ language })`.

**Mid-session switch is allowed.** If the user issues the `language`
command (see Commands), call `update_session_state({ language: <new> })`
and re-render the current step in the new language. The switch applies
**from the next render onward**; already-emitted output is not retroactively
translated.

Detection of language at Entry A: see `references/i18n.md` for the picker
rule. When ambiguous, prefer the language of the most recent user message.

## Session state (cache shape)

The local cache mirrors the server response from `get_session_state`. The
server is SOR. Never write to this cache without also issuing a matching
`update_session_state` (or a domain-specific MCP that the server
documents as state-mutating). Cache fields:

```jsonc
{
  "session_id": "uuid",
  "tg_user_id": "string",
  "language": "zh" | "en",
  "trigger_tier": "hard" | "soft",
  "phase": "awaiting_url" | "gate" | "env_check" | "aid_issue" | "welcome" |
           "module_1" | "module_2" | "module_3" |
           "results_and_consent" | "paused" |
           "done(submitted)" | "done(declined)" | "done(rejected_already_verified)",
  "phase_before_pause": "...",          // only when phase == paused
  "profile": { "email": "...", "entity_name": "...", "registration_no": "...", "kyc_level": "..." },
  "aid": "string-or-null",
  "aid_status": "new" | "reuse" | "rejected_already_verified" | null,
  "question_bank": { "version": "string", "fetched_at": "ISO8601", "items": [...] },
  "module_1": { "completed_at": "ISO8601" | null },
  "module_2": { "current_q_index": 0, "answers": [ { "qid", "text_answer", "evidence_refs": [], "submitted_at" } ] },
  "module_3": { "current_q_index": 0, "answers": [ ... ] },
  "consent": { "consent_record_id": "string" | null, "accepted_at": "ISO8601" | null },
  "application_id": "string-or-null",   // populated after submit_kya_application
  "gated_tools": ["execute_fiat_withdrawal", "get_otc_quote", ...],
  "updated_at": "ISO8601"
}
```

`gated_tools[]` is the server-maintained blacklist of sibling business
tools still gated for this user. It replaces the demo's static
`forbidden-tools.md` list. **At every turn**, before considering any
business tool call, check whether it is in `gated_tools[]`. If yes,
re-route to KYA. If no, the tool is permitted.

## Phase routing

The skill drives transitions; the **server** validates and persists them.
Every transition is issued via a domain MCP call (e.g. `issue_kya_aid`,
`submit_module_answer`, `submit_consent`, `submit_kya_application`) — these
return the new authoritative phase. Use `update_session_state` only for
non-domain fields like `language`, `paused`, `trigger_tier`.

The full state machine, exit conditions per phase, and auto-progression
rules live in `references/flow.md`.

## Commands (work in any phase unless noted)

| zh | en | Behaviour |
|---|---|---|
| 暂停 | pause | Call `update_session_state({ phase: "paused", phase_before_pause: <current> })`. Emit bilingual ack. |
| 继续 / 续作 | resume / continue | If phase is `paused`, call `update_session_state({ phase: phase_before_pause })` and re-render the current step. If phase is non-paused and non-terminal, just re-render. |
| 进度 | status | Render current phase + active module/question progress. No state mutation. |
| 重跑模块 | restart module | Mutate via `update_session_state({ module_2: {}, module_3: {}, consent: {}, phase: "env_check" })`. Preserve `aid`, `aid_status`, `profile`. **Warning the user beforehand**: the env_check → aid_issue auto-progression WILL re-call `issue_kya_aid` — if the underlying account is already verified, expect `rejected_already_verified` and a terminal exit. |
| 上一题 | back | Decrement `current_q_index` by 1 within the current module via `update_session_state`; cannot cross module boundaries. |
| 重跑本题 | redo | Clear `answers[current_q_index]` via `update_session_state`; re-ask. |
| 释义 / 为什么 / 什么意思 / 不懂 / 举个例子 | why / what does this mean / explain / example | Show the current question's `explanation_{lang}` from `question_bank.items[i]`; re-render the question header. Does not count as an answer — `current_q_index` stays put. (Module 2/3 only.) |
| 语言 zh / 语言 en / language zh / language en | (same) | Mid-session language switch. Call `update_session_state({ language })` and re-render. |
| 完成 / 上传完毕 / 结束 / 继续 | done / finish / that's all | **Only meaningful on a `multi_doc` question while files are being trickled in.** Validates cardinality and advances. Outside that context, treat as a no-op. See `references/evidence-handling.md`. |

There is **no** test shortcut. Skip-to-trust-mark is a demo-only mechanism
and is not present in production.

## Error handling

Every MCP call may return a non-success envelope. The orchestrator does
**not** improvise error prose — it routes to `references/error-recovery.md`
which has the canonical user-facing wording per error class (network,
401, 403, 409, 429, 5xx, validation failure, AV scan reject, idempotency
conflict).

Never leak raw HTTP status codes, stack traces, internal field names, or
server-side error messages to the user. Bilingual short-form retry
guidance only.

## Guardrails

- **Precedence.** When a trigger appears and there is no active session,
  the first response MUST be the registry URL prompt. No menu, no
  clarifying question, no business tool call, no dashboard login link.
- **Sibling tools held back.** A sibling business MCP tool may be invoked
  only if it is **not** in `session.gated_tools[]`. Until KYA submission,
  `gated_tools[]` includes the full transaction surface. After submission,
  the backend narrows the list as Trust Marks are issued. The skill itself
  never edits `gated_tools[]`.
- **MCP tools the orchestrator may invoke.** Only the KYA tools, never a
  sibling business tool from inside this skill: `run_env_check`,
  `get_user_profile`, `get_session_state`, `update_session_state`,
  `issue_kya_aid`, `get_question_bank`, `upload_evidence`,
  `submit_module_answer`, `submit_consent`, `submit_kya_application`.
  Full contracts in `references/mcp-contracts.md`.
- **No fetching the registry URL.** The URL the user shares is syntax-only.
  The skill never fetches it and never reads question content from it.
- **No improvising content.** Do not invent questions, options, or
  explanations beyond what `get_question_bank` returns. Do not translate
  question text on the fly — both languages come from the bank.
- **Strict consent.** Do not call `submit_kya_application` until
  `submit_consent` succeeds. The consent phrase match rule lives in
  `references/consent.md`.
- **No internal field leaks.** Do not expose `phase`, `current_q_index`,
  `evidence_refs`, `gated_tools`, etc. in user-facing output.
- **No client-side AID minting.** Always via `issue_kya_aid`. There is no
  bypass.
- **No polling for Trust Mark.** The skill terminates at `done(submitted)`.
  If the user asks "where's my trust mark", point them at the registry URL
  they already have (or the dashboard surface defined by the caller).
- **Idempotency.** Every state-mutating MCP call carries an
  `idempotency_key` per `references/mcp-contracts.md`. A duplicate call
  with the same key is a no-op; never invent fresh keys for retries.
