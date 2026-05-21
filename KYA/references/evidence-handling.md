---
name: kya-prod-evidence-handling
description: "Real file evidence — upload via upload_evidence MCP, trickle-tolerant intake across multi-message attachments, AV scan status handling, and cardinality enforcement. Loaded when a question's attachment_mode is single_file or multi_doc."
---

# Evidence Handling

The skill never inspects file contents. It uploads each attachment to
`upload_evidence`, which returns a content-addressable `evidence_ref`
plus a validation verdict. The skill renders the verdict, accumulates
the refs in the current question's `evidence_refs[]`, and hands them to
`submit_module_answer` when the question completes.

## Extraction — what counts as a file

In priority order:

1. **Real attachment(s)** on the user message — image, PDF, doc, anything
   the chat host exposes as a binary. The host-surface filename and mime
   are used verbatim if available. A message with only an attachment
   (no text) is a complete reply.
2. **Textual filename tokens** the user typed: `attached: report.pdf`,
   `here's the file: X.pdf`, `上传 X.pdf`, `文件名 X.pdf`, or a bare
   `X.pdf` with a recognised extension. Multiple in one message are
   extracted in order. Text around the token(s) becomes `text_answer`.

A textual filename is **only** valid if the chat host doesn't support
real attachments. When real attachments are available, prefer them and
ignore typed filename patterns to avoid duplicate counting. The server
audits the trail by content hash — typed-name only entries have no hash
and get flagged downstream.

## Upload

For each extracted file, call:

```
upload_evidence({
  aid,
  qid: <current_qid>,
  file: <host attachment object>,
  idempotency_key: `upload:${aid}:${qid}:${content_hash_or_local_id}`
})
```

The server returns `{ evidence_ref, content_hash, filename, mime,
size_bytes, av_status }`. Cardinality is enforced after extraction (see
below), but uploads happen per file as they arrive.

## AV scan verdict — three branches

The server's AV scanner is typically synchronous for small files,
asynchronous for large ones. The response always carries `av_status`:

### `av_status: "clean"`

Append `evidence_ref` to `session.{module_n}.answers[current_q_index].evidence_refs`.
Render the one-line ack from `i18n.md → evidence_received`.

### `av_status: "pending"`

The scan is still running. Accept the ref (append to `evidence_refs`)
but render the bilingual `evidence_av_pending` note so the user knows
the scan may flag the file later — submission is still permitted; the
backend will quarantine and re-review if AV rejects after the fact.

### `av_status: "rejected"`

The file failed AV. Do **not** append the ref. Render
`evidence_av_rejected` asking for a different file. Do not retry the
upload with the same content — the verdict is deterministic on content
hash; the same bytes will fail again.

## Cardinality

After extraction (and before submission):

| `attachment_mode` | Rule |
|---|---|
| `not_required` | Reject any uploads silently (do not call `upload_evidence`). The question is text-only. |
| `single_file` | Keep the first `clean`/`pending` file. If more arrive in the same message, silently drop the rest. If more arrive in later messages while still on this question, drop them too (the user may not realise; this is intentional, not an error). |
| `multi_doc` | Keep all `clean`/`pending` files, capped at `evidence_constraints.max_files` (server enforces too, this is a courtesy cap). |

## Trickle-tolerant intake (multi_doc)

Some hosts (Hermes, certain bots) deliver each attachment as its own
user message. The skill MUST coalesce these — heavy renders between
files get interrupted, and the iteration noise destroys throughput.

**Per-incoming-file behaviour while `current_q_index` is unchanged and
the question is `multi_doc`:**

1. Extract file(s) from the message.
2. Call `upload_evidence` per file.
3. Append `clean`/`pending` refs to `evidence_refs[]`.
4. Emit a **single-line bilingual ack only**. Do not re-render the
   question header, do not render any progress / status footer, do not
   advance.
   - en: `📎 Received {n} file(s) so far. Send more, or reply "done" to finish this question.`
   - zh: `📎 已收到 {n} 份附件。继续发送，或回复「完成」结束本题。`
   `{n}` is the cumulative count in `evidence_refs[]` for this question.

The intent is to keep the per-file response short enough that it
completes before the next attachment-message lands. Anything heavier
(progress footer, next question render) is deferred to the done-signal
turn, when no more files are expected.

**Text replies while files are accumulated** (no file in the message):
update `text_answer` (last-write wins) and emit the same one-line ack.
Still do not advance — the user might still be uploading.

**Done-signal vocabulary** (substring match, case-insensitive):
`done`, `finish`, `that's all`, `完成`, `上传完毕`, `结束`, `继续`.

When the done-signal is matched (and we're in `multi_doc`):

1. Validate cardinality: if `evidence_refs[]` has at least 1 clean/pending
   file, proceed. If zero, re-ask once per the missing-file prompt below.
2. Call `submit_module_answer` with the accumulated refs.
3. Render the next question per the server's response (`next_qid` /
   `phase`).

**Done-signal with a file in the same message:** append the file(s)
first, then treat as done. This handles the user who attaches the last
file along with "完成 就这些".

## `single_file` quirk

`single_file` does not need the trickle protocol — by definition only
one file matters. But the same per-file ack pattern applies if the user
sends 2+ files across separate messages **before** the question advances
(e.g. they sent file 1, the skill called `submit_module_answer`, the
server returned the next question, then file 2 arrives meant for the
prior question). The ack is the only safe response: the previous
question is already submitted server-side; the new file is dropped and
the user is told they're already on the next question.

## Missing-file prompts

When a Required question received text but no file:

- en (single_file): `This question needs a supporting file. Please attach a document — preferred: .md / .html / .json / .csv; accepted: .pdf / .docx / .xlsx / .pptx / .jpg / .png / .heic / .webp etc.`
- en (multi_doc): `This question needs one or more supporting files. Please attach the document(s) — preferred: .md / .html / .json / .csv; accepted: .pdf / .docx / .xlsx / .pptx / .jpg / .png / .heic / .webp etc.`
- zh (single_file): `本题需要上传一份支持文件，请直接发送附件 — 优先推荐：.md / .html / .json / .csv；同时接受 .pdf / .docx / .xlsx / .pptx / .jpg / .png / .heic / .webp 等。`
- zh (multi_doc): `本题需要上传一个或多个支持文件，请直接发送附件 — 优先推荐：.md / .html / .json / .csv；同时接受 .pdf / .docx / .xlsx / .pptx / .jpg / .png / .heic / .webp 等。`

The exact wording lives in `i18n.md` and may diverge there — those keys
above are the rendered output reference. Do not loop more than once on
the same question without new input.

## Filename and size validation

The skill does not enforce extensions or sizes locally. `upload_evidence`
returns `validation_failed` with a specific `user_message` when the
server's `evidence_constraints` are violated (too large, mime not in
the accepted list, etc.). The skill renders the server's
`error.user_message` verbatim and asks for a different file.

The bundled hint lists (`.pdf / .docx / ...`) in the missing-file
prompts are guidance for the user, not a client-side filter. The
authoritative list is in `question_bank.items[i].evidence_constraints`
and is enforced server-side.

## Idempotency and retries

The `idempotency_key` for an upload includes the file's content hash
when computable. If the user re-sends the same file (network glitch,
duplicate attachment), the second `upload_evidence` returns the same
`evidence_ref` and the skill should de-duplicate before appending to
`evidence_refs[]`.

If content hash isn't available client-side (some hosts give the file
as an opaque blob), use a `file_local_id` instead — a stable identifier
the host gives for this specific attachment. Two separate attachments
with the same content but different `file_local_id`s will get two
`evidence_ref`s; the server de-duplicates by content hash on its side
and may collapse them into one record in the audit log. That's fine.

## What the skill never does with evidence

- Open, parse, OCR, or read the file contents. The server owns content
  understanding; the skill is a courier.
- Show file contents back to the user. The ack lists the filename
  (server-returned) and that's it.
- Compute or display file hashes. They exist in audit logs, not in chat.
- Retain a copy of file bytes anywhere. The `evidence_ref` is the only
  thing kept; the actual bytes live in the server's evidence store with
  the configured retention policy.
