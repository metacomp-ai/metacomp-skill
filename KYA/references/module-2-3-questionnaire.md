---
name: kya-prod-module-2-3-questionnaire
description: "Module 2 (Entity Control) and Module 3 (Proper Control) — question rendering, answer acceptance, meta-reply handling, and per-question persistence via submit_module_answer. Loaded by SKILL.md while phase is module_2 or module_3."
---

# Modules 2 & 3 — Questionnaire

Both modules share the same machinery; only the question set differs.
Module 2 covers Entity Control. Module 3 covers Proper Control.
**Question counts are not hardcoded** — they come from
`session.question_bank.module_totals[<module>]`. The bank may add or
remove questions between versions (under regulator guidance); the skill
must adapt without code changes.

The question bank is server-pushed via `get_question_bank` and lives at
`session.question_bank.items` (filtered by `module`) and
`session.question_bank.module_totals` (the authoritative cardinality).

## Question selection

The current question is `session.question_bank.items` filtered by
`module == session.phase` and indexed by `session.{module_2|module_3}.current_q_index`.
**Never iterate by qid string.** `current_q_index` is the SOR for "where
we are"; the server bumps it as a side effect of `submit_module_answer`
returning a populated `next_qid`.

If `session.question_bank` is empty or stale (`bank_version` differs from
the latest fetched), re-call `get_question_bank` before rendering. The
server caches the bank on the session record so this is usually free;
the cost is only paid on first entry or after a published bank update.

## Rendering a question

Header line (bold Markdown, bilingual-symmetric):

| Language | Module 2 header | Module 3 header |
|---|---|---|
| en | `**Entity Control · {i}/{N} — {question_en}**` | `**Proper Control · {i}/{M} — {question_en}**` |
| zh | `**实体控制核验 · {i}/{N} — {question_zh}**` | `**运行控制核验 · {i}/{M} — {question_zh}**` |

`{i}` is `current_q_index + 1`. `{N}` is
`session.question_bank.module_totals.module_2`; `{M}` is the equivalent
for `module_3`. Always render bold so consecutive questions visually
separate.

Then, depending on `attachment_mode`:

- `single_file`:
  - en: `  📎 Attachment: Required (single file)`
  - zh: `  📎 附件：必填（单个文件）`
- `multi_doc`:
  - en: `  📎 Attachment: Required (one or more files; reply "done" when finished)`
  - zh: `  📎 附件：必填（一个或多个文件；上传完毕请回复「完成」）`
- `not_required`: no attachment line. The user already knows by default
  that questions accept plain text; rendering "Attachment: Not Required"
  on 90% of the questions would be visual noise.

The `multi_doc` line telegraphs the done-signal because some hosts
deliver each attachment as its own user message. See `evidence-handling.md`.

### `not_required` exception — M3_Q1 autonomy level

The only `not_required` question (in the current bank) uses
`answer_type == "autonomy_level_with_text"`. Render the header plus a
single one-line hint that names the four levels in prose, not a numbered
menu — the answer is open-text and "Level 2" is a hint, not an enum
constraint:

- en: `  Pick one of Level 1 (Fully Controlled), Level 2 (Assisted), Level 3 (Conditional Autonomy), Level 4 (Full Autonomy), and briefly explain how you decided.`
- zh: `  请选择 Level 1（完全受控）、Level 2（辅助）、Level 3（条件自治）、Level 4（完全自治）中的一个，并简述判定依据。`

The `options` array on the question item is **not** rendered as a numbered
menu. It exists for the post-submission audit pipeline (server can extract
a structured level if the user named one) and for the render hint above
— that's it.

### Why no numbered options anywhere

Production KYA captures qualitative claims about the user's controls. A
numbered `1) Yes / 2) No / 3) Partially` menu both biases responses
(users pick the safest option) and loses the explanatory text that makes
the answer auditable. Open-text answers are the entire point.

## Accepting an answer

Classify the user reply before anything else:

1. **Command** (`pause`, `back`, `redo`, `restart module`, `语言 zh|en`,
   `status`, `done` while not in multi_doc trickle): route to the
   Commands table in `SKILL.md`. The answer slot is untouched.
2. **Meta-reply** (request for explanation): render the explanation, do
   not advance. See "Meta replies" below.
3. **Real answer**: persist via `submit_module_answer`.

### Persistence

When a reply is classified as a real answer, call:

```
submit_module_answer({
  aid,
  qid,
  text_answer,            // verbatim user text, trimmed
  evidence_refs,          // [] for not_required; otherwise from evidence-handling.md
  language,               // current session language
  idempotency_key: `answer:${aid}:${qid}:${attempt_no}`
})
```

`attempt_no` is 1 by default; it increments only when the user issued
`redo` on this question. The server's response carries the new `phase`
and `next_qid`. The skill renders the next question using whatever the
server returned — do **not** compute next_qid client-side.

### Empty / whitespace-only reply

Re-ask with the bilingual one-line nudge from `i18n.md → answer_empty`.
Do not persist, do not advance. This applies regardless of
`attachment_mode`.

### Required-attachment but no file or filename token

For `single_file` and `multi_doc`, if the reply is text-only with
no attachment and no filename token, ask once for the file (bilingual
prompt, see `evidence-handling.md`). The text is preserved in
`text_answer`. Do not loop more than once on the same question without
new input — a stuck user gets the question re-rendered, not the same
prompt 10 times.

## Meta replies

Some replies are requests for clarification, not answers. They render
the question's `explanation_{lang}` and re-anchor the user on the
question — but do not advance and do not persist.

Detect via substring intent (case-insensitive). This is a recognition
hint, not an exhaustive whitelist — judge intent:

| Language | Phrases the user might send |
|---|---|
| en | `why`, `what does this mean`, `what do you mean`, `explain`, `can you explain`, `i don't understand`, `example`, `give me an example`, `what's this asking`, `huh?`, `?` (lone question mark) |
| zh | `为什么`, `什么意思`, `这是什么意思`, `这题啥意思`, `不懂`, `没懂`, `解释一下`, `举个例子`, `能举例吗`, `这问的是什么`, `啥意思` |

Render template:

**English:**
```
{question_text}

— {explanation_en}

Take your time. {question_text}
```

**Chinese:**
```
{question_text}

— {explanation_zh}

慢慢来。{question_text}
```

The trailing repeat of `{question_text}` keeps the user anchored without
forcing them to scroll up. Stay on the same `current_q_index`; the next
reply is evaluated against the same accept rules.

### Disambiguating answers that contain meta-words

A real answer that happens to contain `why` or `example` is still an
answer — `we use multi-factor auth — for example, FIDO2 keys for admins`
is a real answer to a question about access control. The test is whether
the message is **predominantly** a meta-question or a substantive reply.
When in doubt, lean toward treating it as an answer — over-asking-for-clarity
is more annoying than over-accepting, and the user can always type
`why` again on the next turn.

## Multi-turn evidence collection

For `multi_doc`, the user may trickle files in across several messages.
Module rendering must not flicker during the trickle — the entire
multi-file ack flow is owned by `evidence-handling.md`. From this
module's perspective: control returns here only when the user has issued
the done-signal **and** `evidence-handling.md` has assembled the final
`evidence_refs[]`. At that point, this module calls
`submit_module_answer` and advances.

## Module boundaries

There is no "end of Module 2" banner. When `submit_module_answer`
returns with `phase == "module_3"` and `next_qid == "M3_Q1"`, the skill
renders the Module 3 header on Q1 directly. The visual transition
(header text changes from `实体控制核验` to `运行控制核验`) is enough —
adding a "Module 2 complete!" line is celebratory noise that production
does not need.

The same applies to the transition from `module_3` to
`results_and_consent`.

## Resume into a question

On `resume`, render the current question (per `current_q_index`) using
the cached question bank. Already-uploaded evidence (`session.{module_n}.answers[current_q_index].evidence_refs`)
is preserved server-side — there's no need to re-upload. If the user
sends another file, append it; if they say "done" / "完成", call
`submit_module_answer` with the existing refs.

If the question is `not_required` and was answered before pausing,
moving back to it via `back` should re-show the user's previous
`text_answer` (from `session` cache) as a hint that they already
answered, so they can decide whether to overwrite.

## Status command

`status` / `进度` renders:

- Current module name (bilingual).
- `{current_q_index + 1} / {module_totals[current_module]}`.
- Count of evidence files attached to the current question (if it's
  evidence-required).

It does **not** dump every prior answer. The server holds those; the
skill just shows where you are.
