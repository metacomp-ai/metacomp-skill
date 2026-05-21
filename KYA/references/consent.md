---
name: kya-prod-consent
description: "Strict consent phrase capture and binding submission. Loaded while phase == results_and_consent. Owns the consent phrase render, exact-match validation via submit_consent, and the final submit_kya_application call that terminates the skill."
---

# Consent and Submission

This phase is the legal gate. Everything before it can be paused,
backed-out, re-done. After `submit_consent` succeeds, the application is
binding: the user has consented to MetaComp running KYC + KYA review on
the captured answers and evidence.

## What's rendered

A single bilingual block: the consent phrase (verbatim from the server),
a one-line instruction asking the user to type it back exactly, and
nothing else. Specifically — **no recap** of the 10 questions and
answers. Reasoning:

- The server has the canonical record. Re-rendering from cache risks
  silent divergence (a question the user thinks they answered may have
  failed `submit_module_answer` and not actually been persisted).
- A 10-item recap in chat is wall-of-text that nobody reads carefully —
  it creates the illusion of review without the substance. Audit happens
  on the server-side dashboard, not in the chat scroll.
- The user already answered each question moments ago. Re-asking them to
  review their own typing is theatrical.

If the user wants to review before consenting, they can use `back` to
walk through their answers — `back` is supported up to the start of
Module 2 (it cannot cross from `results_and_consent` directly into
Module 1 since Module 1 is identity linkage, not a question).

## Consent phrase source

The phrase comes from `session.question_bank.consent_phrase_{lang}` —
the same fetch that delivers the question items also delivers the
canonical consent text per language. The skill ships **no** consent
text of its own; that would split the regulator-approved phrase into
two places and let one rot.

Render template:

**English:**
```
To submit your application, please copy the following phrase exactly
(case and punctuation must match):

  {consent_phrase_en}

Type the phrase as your reply.
```

**Chinese:**
```
请逐字复制下方短语（大小写与标点须完全一致）作为提交确认：

  {consent_phrase_zh}

请将短语作为本轮回复发送。
```

If the user switches language mid-phase via the `language` command,
re-render in the new language with the corresponding phrase. The phrase
the user must type is whichever language they're submitting in — the
server stores the language alongside the consent record.

## Validation

Pass the user's raw reply to `submit_consent` — the server validates,
not the skill. Reasoning: the canonical phrase is on the server; copying
the comparison logic into the skill duplicates an audit-critical
decision and lets a typo in one place drift from the other.

```
submit_consent({
  aid,
  consent_phrase: <user reply, untrimmed>,
  language,
  idempotency_key: `consent:${aid}`
})
```

The server normalises (trims edge whitespace, collapses internal runs of
spaces) and then does exact comparison. Mismatches return
`validation_failed` with a `user_message` populated. The skill renders
that message verbatim and stays in `results_and_consent` — same question
remains open.

**Do not pre-validate locally.** Tempting optimisations like "if it
doesn't contain the substring `I consent` reject early" produce false
negatives when the canonical phrase is updated server-side without the
skill knowing. Pass-through is the safe pattern.

## Mismatch UX

After a mismatch, re-render the consent block in the same turn so the
user has the phrase visible on screen along with the error note. The
error note is brief — one line, bilingual — and goes **above** the
re-rendered phrase block so the user sees the correction context first.

After three mismatches in a row, render an extra hint suggesting the
user copy-paste rather than re-type. Do not block them — the regulator
phrase is non-trivial to type and three retries is a frustration
threshold, not a fraud signal.

## After consent succeeds

`submit_consent` returns `{ consent_record_id, accepted_at, phase }`.
Phase is still `results_and_consent` because submission is the next
step. In the **same turn**:

1. Call `submit_kya_application({ aid, idempotency_key: \`submit:${aid}\` })`.
2. On 200, the server returns `{ application_id, phase:
   "done(submitted)", gated_tools }`.
3. Render the bilingual submission acknowledgment (`i18n.md →
   submitted_ack`) naming the `application_id` so the user can use it
   for any out-of-band follow-up.
4. Update the local cache from the response (`session.application_id`,
   `session.phase`, `session.gated_tools`).

If `submit_kya_application` fails with a retryable error, the consent
is already recorded — retry submission with the same idempotency key
per the retry policy in `mcp-contracts.md`. If it fails non-retryably,
route to `error-recovery.md → submit_application_fail`. Do not
re-collect consent.

## Why this is one turn, not two

The consent and submission could be split into two turns ("you consented;
shall I submit?"), but production deliberately fuses them:

- The legal effect of typing the consent phrase IS the intent to submit.
  Adding a follow-up confirmation creates ambiguity about which click
  was the binding one.
- A two-turn flow opens a window where consent is recorded but
  application is not, and the user closes the chat. Now the server has
  a dangling consent record with no application — operationally
  awkward to clean up.

So: consent phrase matches → submit_consent succeeds → submit_kya_application
in the same turn. One atomic legal step from the user's perspective.

## Edge case — language switch right before consent

A user could plausibly type `语言 en` (or `language zh`) at the
consent step. Honour the command, re-render in the new language with
the corresponding phrase, then wait. **Do not accept a phrase typed in
language A while the session is now in language B** — the server will
reject on phrase mismatch and the user will be confused.

## What this phase does NOT do

- Display the application as a PDF / preview / receipt. The acknowledgment
  is a chat message; the dashboard surface is where the user can view
  their submitted application as a document.
- Compute a confirmation code, hash, or signature. The `application_id`
  is the receipt; everything else lives in the audit trail.
- Send confirmation email. That's the backend's job, triggered by the
  `submit_kya_application` success event.
- Poll for Trust Mark issuance after submission. The skill terminates;
  Trust Mark surfacing is a separate channel.
