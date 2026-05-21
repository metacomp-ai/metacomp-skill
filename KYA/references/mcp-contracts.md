---
name: kya-prod-mcp-contracts
description: "Canonical interface definitions for every MCP tool the KYA production skill calls. Request/response shapes, error envelopes, idempotency keys, retry policy. Read before the first MCP call in a session and whenever a response shape is ambiguous."
---

# MCP Contracts

The skill calls a fixed set of MCPs. Every call uses the same envelope
shape so error handling is uniform.

## Common envelope

**Success:**
```jsonc
{
  "success": true,
  "data": { /* tool-specific */ },
  "trace_id": "string"           // echo in logs; never show to user
}
```

**Failure:**
```jsonc
{
  "success": false,
  "error": {
    "code": "string",            // see error code table below
    "category": "auth" | "validation" | "conflict" | "rate_limit" | "server" | "network",
    "retryable": true | false,
    "user_message": { "en": "...", "zh": "..." } | null,
    "details": { /* opaque server-defined */ }
  },
  "trace_id": "string"
}
```

The skill **never** shows `error.code`, `error.details`, or `trace_id` to
the user. If `error.user_message` is populated, route it through
`i18n.md` (the server-provided message takes precedence over any local
fallback). Otherwise, fall back to the canonical bilingual line from
`error-recovery.md` keyed by `error.category`.

## Error code table (subset — server is SOR)

| Code | Category | Retryable | When |
|---|---|---|---|
| `auth_required` | auth | no | 401 — user not signed in (Module 1 only) |
| `forbidden` | auth | no | 403 — user lacks permission to call this tool |
| `validation_failed` | validation | no | Bad input (file too large, mime not allowed, etc.) |
| `av_scan_rejected` | validation | no | Uploaded file failed antivirus scan |
| `conflict_already_verified` | conflict | no | `issue_kya_aid` when account already has a Trust Mark |
| `conflict_idempotency` | conflict | no | Same `idempotency_key` with a different payload — skill bug |
| `conflict_phase` | conflict | no | Tried to mutate in a phase that disallows it |
| `rate_limited` | rate_limit | yes | 429 — backoff with `Retry-After` |
| `server_error` | server | yes | 5xx |
| `network_error` | network | yes | Transport failed before the server replied |

## Idempotency

State-mutating tools accept an `idempotency_key`. The key is deterministic
per logical operation so retries are safe:

| Tool | Key formula |
|---|---|
| `issue_kya_aid` | `aid_issue:{tg_user_id}` |
| `submit_module_answer` | `answer:{aid}:{qid}:{attempt_no}` |
| `upload_evidence` | `upload:{aid}:{qid}:{content_hash}` (or `{file_local_id}` if hash not yet computed client-side) |
| `submit_consent` | `consent:{aid}` |
| `submit_kya_application` | `submit:{aid}` |

`attempt_no` increments when the user uses the `redo` command, otherwise
stays at `1`. **Never** generate fresh random keys for retries — that
defeats idempotency.

## Tools

### `get_user_profile()`

Probe sign-in state and (when authenticated) return the real user
identity. Used by:
- The orchestrator at Entry B (after URL validation, to populate
  `session.profile` if it's empty).
- Module 1 every time it needs to render the sign-in card (the
  `authPageUrl` carries a short-TTL token; never reuse across turns).

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "signed_in": true,
    "profile": {
      "email": "alice@example.com",
      "entity_name": "ACME Pte. Ltd.",
      "registration_no": "202100012X",
      "kyc_level": "individual" | "corporate" | "institutional",
      "country_code": "SG"
    }
  }
}
```

**Response (401):**
```jsonc
{
  "success": false,
  "error": {
    "code": "auth_required",
    "category": "auth",
    "retryable": false,
    "user_message": null,
    "details": { "authPageUrl": "https://login.metacomp.ai/?loginToken=..." }
  }
}
```

`authPageUrl` is short-TTL (minutes). Use it ONLY in the same turn you
received it. Never cache it on `session.profile` or anywhere persistent.
Re-call `get_user_profile` on every render of the Module 1 sign-in card.

### `run_env_check({ tg_user_id })`

Runs the production environment self-check server-side. The server probes
every downstream dependency (its own DBs, the AID issuance pipeline,
storage, AV scanner, the question bank service, the consent recorder,
the submission pipeline) and returns one consolidated result. The skill
does **not** do inline reachability probes — that was the demo behaviour
and is brittle (e.g. it conflates user-side network with operator-side
outage).

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "all_ok": true,
    "checks": [
      { "key": "session_store",   "ok": true,  "label_en": "Session store",       "label_zh": "会话存储" },
      { "key": "user_profile",    "ok": true,  "label_en": "Identity service",    "label_zh": "身份服务" },
      { "key": "aid_pipeline",    "ok": true,  "label_en": "AID issuance",        "label_zh": "AID 签发" },
      { "key": "question_bank",   "ok": true,  "label_en": "Question bank",       "label_zh": "题库服务" },
      { "key": "evidence_store",  "ok": true,  "label_en": "Evidence storage",    "label_zh": "证据存储" },
      { "key": "av_scanner",      "ok": true,  "label_en": "Antivirus scanner",   "label_zh": "病毒扫描" },
      { "key": "consent_recorder","ok": true,  "label_en": "Consent recorder",    "label_zh": "同意书登记" },
      { "key": "submission_pipe", "ok": true,  "label_en": "Submission pipeline", "label_zh": "提交管线" }
    ]
  }
}
```

If `all_ok` is false, one or more `checks[i].ok` is false and the skill
routes to `error-recovery.md → env_check_fail` (operator-side incident;
the user-facing message names the affected subsystem from
`label_{lang}`, never the internal `key`). The skill does **not**
auto-retry — env failures persist long enough that retry-in-this-turn
is wasted; the user is told to come back later.

`run_env_check` is read-only and carries no `idempotency_key`.

### `get_session_state({ tg_user_id })`

Returns the authoritative session record. Call at the **start of every
turn** before deciding what to render.

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "session": { /* see SKILL.md "Session state (cache shape)" */ }
  }
}
```

If no session exists yet, `data.session` is `null` and the skill should
treat phase as `not_started`.

### `update_session_state({ tg_user_id, patch })`

Merge-patches the session record. Only allowed for fields the skill
legitimately owns: `language`, `phase` (for `paused`/`resume` only),
`phase_before_pause`, `trigger_tier`, `registry_url`. Phase changes
driven by domain events (AID issuance, answer submission, consent)
happen as side effects of the domain MCPs — do **not** patch `phase` to
`module_2` manually; calling `submit_module_answer` does that.

**Validation:** the server rejects patches that violate the state
machine (e.g. patching `phase` to `module_3` while `module_2` is
incomplete). On rejection: `conflict_phase`.

### `issue_kya_aid({ tg_user_id, profile, idempotency_key })`

Mints (or returns existing) AID server-side. Always carries
`profile` snapshot for audit.

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "aid": "48-char-string",
    "aid_status": "new" | "reuse",
    "phase": "welcome"                 // server-updated phase
  }
}
```

**Response (rejected — terminal):**
```jsonc
{
  "success": false,
  "error": {
    "code": "conflict_already_verified",
    "category": "conflict",
    "retryable": false,
    "user_message": {
      "en": "This account is already KYA-verified. No new application needed.",
      "zh": "该账户已完成 KYA 核验，无需再次申请。"
    }
  }
}
```

### `get_question_bank({ language, bank_version?, modules: ["module_2","module_3"] })`

Fetches the versioned question bank. Production source. Call once per
session at `env_check`, persist into `session.question_bank` (server
caches it on the session record so the skill doesn't need to re-fetch
across turns — but re-fetch if `bank_version` in cache differs from the
latest pushed version).

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "bank_version": "2026.05",
    "module_totals": {
      "module_2": 5,                 // authoritative per-module question count
      "module_3": 5                  // server may change these between bank versions
    },
    "consent_phrase_en": "I confirm the answers above are accurate to the best of my knowledge and consent to MetaComp's verification.",
    "consent_phrase_zh": "本人确认上述答案准确无误，并同意 MetaComp 进行核验。",
    "items": [
      {
        "qid": "M2_Q1",
        "module": "module_2",
        "question_en": "...",
        "question_zh": "...",
        "explanation_en": "...",
        "explanation_zh": "...",
        "attachment_mode": "single_file" | "multi_doc" | "not_required",
        "answer_type": "text" | "autonomy_level_with_text",
        "evidence_constraints": {
          "preferred_ext": [".md", ".html", ".json", ".csv"],
          "accepted_ext": [".pdf", ".docx", ".xlsx", ".pptx", ".jpg", ".png", ".heic", ".webp"],
          "max_size_mb": 25,
          "max_files": 10              // multi_doc only
        },
        "options": null | [ { "code": "level_1", "label_en": "...", "label_zh": "..." } ]
      }
      /* ... */
    ]
  }
}
```

**No client-side fallback.** If `get_question_bank` fails after the retry
policy (see "Retry policy" below), route to `error-recovery.md →
question_bank_unavailable` and stay in `env_check`. The skill never ships
a bundled question bank — that would let a stale local copy diverge from
the regulator-approved bank without anyone noticing. The server is the
sole source of questions.

### `upload_evidence({ aid, qid, file, idempotency_key })`

Uploads a single file. The skill calls this once per file — for
multi_doc questions, call it N times, once per attachment.

**Request:** `file` is the host-surface attachment object (binary +
filename + mime). The skill does not parse file contents.

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "evidence_ref": "evd_01HABC...",
    "content_hash": "sha256:...",
    "filename": "report-final.pdf",
    "mime": "application/pdf",
    "size_bytes": 412938,
    "av_status": "clean" | "pending" | "rejected"
  }
}
```

If `av_status == "pending"`, the file is accepted into the answer but the
backend may quarantine it during review. The skill renders a one-line ack
noting AV scan is in progress (see `i18n.md → av_pending`).

If `av_status == "rejected"`, this is a 200 with a special data shape —
the server accepted the upload but the file is unusable. The skill
treats this as if the upload failed: drop the ref, ask the user to send
a different file. See `error-recovery.md → av_rejected`.

**Response (validation failure):** standard error envelope with
`code: "validation_failed"` and `user_message` populated per failure
(too-large, mime-not-allowed, etc.).

### `submit_module_answer({ aid, qid, text_answer, evidence_refs, language, idempotency_key })`

Persists one question's answer. Called once when the user finishes a
question (for `multi_doc`, that means after the done-signal — see
`evidence-handling.md`).

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "qid": "M2_Q1",
    "submitted_at": "2026-05-19T10:23:45Z",
    "phase": "module_2",               // server-updated phase, may advance to module_3 or results_and_consent
    "next_qid": "M2_Q2" | null
  }
}
```

`phase` and `next_qid` together drive the next render. If `next_qid` is
null, the module is complete — the server has advanced `phase` and the
skill should re-render based on the new phase.

### `submit_consent({ aid, consent_phrase, language, idempotency_key })`

Submits the strict consent phrase. Server validates the phrase against
its own canonical text (the skill does **not** ship the phrase — it
fetches the expected phrase from `get_question_bank.data.consent_phrase_{lang}`
on the same fetch as the question items).

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "consent_record_id": "csn_01H...",
    "accepted_at": "2026-05-19T10:30:12Z",
    "phase": "results_and_consent"     // still — submit_kya_application is the next step
  }
}
```

**Response (phrase mismatch):**
```jsonc
{
  "success": false,
  "error": {
    "code": "validation_failed",
    "category": "validation",
    "retryable": false,
    "user_message": {
      "en": "The phrase doesn't match. Please copy the exact wording above (mind the case and punctuation).",
      "zh": "短语不一致，请逐字复制上方原文（注意大小写与标点）。"
    }
  }
}
```

### `submit_kya_application({ aid, idempotency_key })`

Final step. Hands the assembled application to the backend pipeline.

**Response (200):**
```jsonc
{
  "success": true,
  "data": {
    "application_id": "app_01H...",
    "phase": "done(submitted)",
    "gated_tools": ["execute_fiat_withdrawal", "get_otc_quote"]  // may be narrowed vs. pre-submission
  }
}
```

After this returns, the skill terminates. It does **not** poll for Trust
Mark issuance — that is the backend's job, surfaced through a different
channel (notification, dashboard, etc.).

## Call ordering

Within a single turn, calls should be issued in this order so that
later-phase decisions see the latest server state:

1. `get_session_state` (always first).
2. Tool calls matching the current phase (e.g. `get_user_profile` in
   `module_1`, `upload_evidence` then `submit_module_answer` in
   `module_2`).
3. Render output.

Never issue a domain-mutating call (`submit_*`, `upload_*`, `issue_*`,
`update_session_state`) speculatively before `get_session_state` confirms
the current phase still expects it.

## Retry policy

- Network / 5xx / 429: retry up to 2 times with exponential backoff
  (`Retry-After` header overrides). All retries use the **same**
  `idempotency_key`.
- After 2 failed retries: route to `error-recovery.md → transient_fail`
  and stay in the current phase. Do **not** silently advance.
- 4xx (other than 401 in Module 1 which is expected and renders the
  sign-in card): do not retry. Route to `error-recovery.md` per
  `error.category`.

## What the skill never calls

- Sibling business MCP tools (`execute_fiat_withdrawal`, `get_otc_quote`,
  etc.). The skill is the gatekeeper for them, not a consumer.
- A "fetch URL" tool against the user-provided registry URL. The URL is
  syntax-only.
- Any tool not listed in this file. New MCPs are added via skill
  versioning, not on-the-fly.
