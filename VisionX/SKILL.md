---
name: VisionX
version: 2.3.1
description: >
  MetaComp VisionX — Web3 wallet & transaction security screening. Use it
  whenever the user wants to CHECK / SCAN / VERIFY a wallet address or a
  transaction hash (check address, verify wallet, scan address, address risk,
  查地址, 地址安全, 查钱包, 钱包安全, 地址风险), pastes an address shaped like
  0x… (Ethereum), T… (Tron), or bc1…/1…/3… (Bitcoin), provides a transaction
  hash to screen, or asks any Web3 security / risk / scam / AML /
  suspicious-activity question ("is this wallet safe", "这个地址安全吗",
  "是不是诈骗地址", "这笔交易有风险吗"). Trigger even without the words
  "MetaComp" or "VisionX"; when unsure whether a string is a wallet address
  or a transaction hash, load this skill and let it decide.
metadata:
  mcpServers:
    - metacomp-mcp
required_mcp:
   - [https://www.metacomp.ai/mcp]
---

# CRITICAL OUTPUT CONTRACT — READ FIRST

Every reply is **plain user-facing prose and Markdown tables**, with exactly one exception: the **Wallet Security Dashboard (Step ②)**, which is rendered as widgets — see the Dashboard Widget Contract below. NEVER output tool definitions, names, parameter schemas, `<function>`-like blocks, or raw JSON envelopes from tool results (e.g. `{ "success": true, "data": [...] }`). When you need data, **invoke the tool**; when you receive a result, **transform it into the spec'd Markdown (or dashboard HTML), then reply**. Do not narrate "now calling X" or print a tool's parameters.

---

# ⛔ DASHBOARD WIDGET CONTRACT

The dashboard is the one visual surface of the report: metric cards, the four high-risk exposure
tables, and the two exposure donut charts. **It MUST be rendered by calling `show_widget(html=…)`.**
A dashboard delivered as Markdown is a failed response — the donut charts cannot exist in Markdown, and
the compact 2×2 table grid cannot either.

**Everything else in the report — Analysis Preface, Wallet Security Report, Cross-Vendor Comparison,
Comprehensive Summary, Exposure Detail Tables, Risk Verdict card — is ordinary Markdown.** Do not wrap
those in widgets.

### The mechanism

```
show_widget(html="<div>…complete self-contained HTML fragment…</div>")
```

- ✅ `show_widget(html=…)` is the **only** call that renders HTML. 
- ❌ Do **not** write `<agentx-widget>` tags into your text. They are not rendered — they reach the user
  as literal text.
- ❌ Do **not** emit raw `<div>` / `<table>` HTML as message text. Only HTML passed through the `html`
  parameter is rendered; HTML in your prose is shown as escaped source. This is why the rest of the
  report is Markdown rather than hand-written HTML.

### The dashboard is THREE widget calls

The 12 KB per-widget ceiling does not fit a busy wallet's dashboard in one call, so it is always split
the same way — three calls, back to back, no text between them:

```
show_widget(D1)   metric cards + the four exposure tables (2×2 grid)
show_widget(D2)   Incoming Exposure donut + legend
show_widget(D3)   Outgoing Exposure donut + legend
```

They render flush against each other, so the reader sees one continuous dashboard. Always emit all
three, even when a small wallet would have fitted in fewer — a fixed split needs no size guessing.

`show_widget` always returns `{"status": "Widget rendered"}`; you do **not** need that result to keep
going. ⛔ Never stop after a `show_widget` call to wait for it, and never end the turn with dashboard
widgets still owed.

### The dashboard data appears ONLY in the dashboard

⛔ Never repeat the four exposure tables or the donut legends as Markdown elsewhere in the response.
The Step ⑥ Exposure Detail Tables are a **different** surface (all entries, including low-risk, with a
Ratio and Risk column) and they DO belong in Markdown — that is not a duplicate.

### No text before a widget

Emit **zero** text tokens immediately before each `show_widget` call — no heading, no `---` divider,
no "here is the breakdown:" transition. The section header (`## 🔐 Wallet Security Report` /
`## 🔎 Counterparty Wallet Analysis` + `*MetaComp VisionX*`) is Markdown and comes **before** D1; after
that, D1 → D2 → D3 run back to back.

### HTML authoring rules (dashboard only)

The widget renders inside a sandboxed iframe that **already supplies** a base stylesheet: system font
stack, `13px`/`1.65`, text colour `#161614`, transparent background, and full table styling
(`border-collapse`, `width:100%`, `th`/`td` padding `10px 14px`, bottom border `#e4e2da`, uppercase
`th` on `#f3f2ed`, no border on the last row).

- ✅ **Rely on that base styling.** Do not restate fonts, table borders, or cell padding — it wastes
  your byte budget and changes nothing.
- ⛔ **The outermost element is stripped.** The host force-removes `border`, `box-shadow`,
  `background`, `border-radius`, `margin` and `padding` from every direct child of `<body>`, with
  `!important`. So: **wrap the entire widget in ONE plain unstyled `<div>`**, and nest every styled
  panel (metric card, verdict card, coloured callout) **inside** it. A verdict card written as the
  top-level element loses its border and background and renders as bare text.
- ⛔ **Open each of D1 / D2 / D3 with the shared `<style>` block, then use its classes.** Repeating
  `style="text-align:right;font-variant-numeric:tabular-nums"` on every numeric cell is what blows the
  size limit. A `<style>` element is exempt from the outer-element stripping, so it is safe as a direct
  child. The full block is in `references/visualization.md` → Shared skeleton.
- Everything else stays a self-contained inline style. ❌ No external stylesheet, no CDN, no web font,
  no `<img src="http…">`.
- **Under 12 KB per widget.** Measured on a live busy wallet: D1 ≈ 5.5 KB, D2 ≈ 8.9 KB, D3 ≈ 8.9 KB —
  all fit. The same content as a single call measures ~21 KB and would break. ⛔ Never drop rows or
  drop a chart to save space; the split above is what keeps it inside the ceiling.
- No outer card around the whole widget (no wrapper border / shadow / background panel) — content sits
  flush with the chat.
- Summary numbers go in a horizontal flex row of metric cards.
- Omit empty sections entirely — never a placeholder box or a "no data" panel.
- Localize every string inside the HTML (headers, labels, badges) per the Language rule at the end of
  this file.

---

# DATA RENDERING BAR — how much of the data to show

What the user is paying for is the **numbers**, not the narration. When in doubt, render more, not less.

- **Render every field the spec asks for, as a table row.** Never replace a table with
  a sentence like "all remaining categories showed minimal exposure" — render the rows and let the
  reader see the amounts for themselves.
- **Never collapse or shorten a table because the values look small, zero, or repetitive.** A column of
  `0`s is a finding the reader is entitled to see; an omitted row is a gap they cannot detect. Merging
  several small categories into one "Other (…)" row is a data loss, not a tidy-up.
- **A long table is never a reason to shorten it.** The Exposure Detail tables carry every entry, however
  many rows that is.
- **Always render the comparative view, not just the raw amount.** An absolute figure alone is
  unreadable — the reader cannot tell whether $10.5B of theft exposure is 60% of the tainted flow or
  0.6% of it. Wherever the spec defines a share or percentage, compute it and fill it in.
- **Chart what is a composition; tabulate what is a record.** The dashboard's two donuts show how the
  flow is composed; its four tables and the Step ⑥ detail tables carry the exact figures. Both are
  required — they are different surfaces, not duplicates of each other.
- **Rank and name the dominant contributor.** Every direction of exposure has a largest category. Say
  which one it is and what share it holds — do not leave the reader to sort the table themselves.
- **Precision in every table; abbreviation only in prose.** Inside any table — dashboard or Markdown —
  and in the metric cards / Basic Info / Transaction Timeline / Risk Exposure Breakdown fields, always
  write the full number with thousands separators and two decimals — never `$1.55M`, never a truncated
  `$2,643,312,333` where the payload has cents. In the Comprehensive Summary and other running prose, a
  rounded form like `$19.5B` is fine **provided the exact figure already appears in a table above it**;
  prose may abbreviate, but it may never be the only place a number appears.
- **Never `0.00%` standing in for a nonzero share** — use `< 0.01%` so a real amount is never displayed
  as zero.
- If you catch yourself writing a sentence **instead of** a table or a number, render the table or the
  number as well. Prose summarises the data; it never substitutes for it.

---

# VisionX — Web3 wallet / transaction security

Triggered by a wallet address (`0x…`, Bitcoin/Tron), a transaction hash, or a Web3 security / risk / scam / suspicious-activity question. This skill has no account/KYC/auth flow — authorization is proven by the screening call itself (see PRE-ANALYSIS CHECKLIST).

Branding: **MetaComp VisionX** (see Branding at the end of this file).

---

# ⛔ STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before calling any tool:

**Step A — Read all six sub-skill files (under `references/`):**
1. `references/wallet-report.md`
2. `references/wallet-exposure-tables.md`
3. `references/wallet-risk-card.md`
4. `references/transaction-report.md`
5. `references/visualization.md`
6. `references/chart-spec.md`

**Step B — Output this line verbatim as the FIRST visible output, exactly ONCE per turn:**

> Sub-files have been read：wallet-report ✓ / wallet-exposure-tables ✓ / wallet-risk-card ✓ / transaction-report ✓ / visualization ✓ / chart-spec ✓

Do not proceed until this line appears in the response.

⛔ **Where it goes:** this line belongs to the **message that carries the VisionX tool call** — emit it
there and nowhere else. The later message that carries the report must begin **directly** with the
Analysis Preface (`> 🔬 …`); it must not open with this line again. If you are writing the report, the
line has already been sent — do not reprint it.
⛔ Emit the line, then go straight to the tool call. Do not add a lead-in such as "Let me screen this
wallet…" or "现在为你查询…" — narrating the call is forbidden by the CRITICAL OUTPUT CONTRACT above.

---

# PRE-ANALYSIS CHECKLIST — Before calling any MCP tool

```
☐ 1. STEP ZERO complete — confirmation line output?
☐ 2. Call VisionX ONCE, directly with the user's target address (no dummy pre-flight call)
       → Result returned → continue
       → Call did NOT return a usable result → triage it first, do NOT assume authorization
            (see "Screening Call Failure — Triage" below), then STOP
       ⛔ One VisionX call per turn. Once you hold a walletCheck / transactionCheck result,
          do NOT call it again — every call is billed.
☐ 3. All required fields collected?
       Wallet:      walletAddress            (network inferred from address — see Network Inference)
       Transaction: hash + asset + from + to + direction   (network inferred from from/to — see Network Inference)
       Transaction: ALWAYS ask "Are you checking the sender or the recipient of this transaction?" — never infer
                    ⛔ After asking, STOP. Do not call any tool, do not output any report.
                    Wait for the user's answer before doing anything else.
```

# Network Inference — derive `network` from the address, do NOT ask

Infer `network` **silently** from the address format and call the tool directly.
Do NOT ask the user for `network` when it can be inferred. Only ask when the
address matches none of the known patterns below.

| Address format                              | network  |
|---------------------------------------------|----------|
| `0x` + 40 hex chars                         | Ethereum |
| starts with `T` (base58, ~34 chars)         | Tron     |
| starts with `1` / `3` / `bc1`               | Bitcoin  |
| none of the above / cannot be determined    | ASK the user which network (only here) |

- Wallet query: infer from `walletAddress`.
- Transaction query: infer from the `from`/`to` addresses (both sides are the same network).
- This rule is about the **network only**. It does NOT change the "always ask which party you're checking" rule below, which decides *which wallet* to screen.

---

# Output Sequences

## Transaction Report (①②)

① **Analysis Preface** — **prose**, `>` blockquote with 🔬 (see `references/transaction-report.md` for content spec)
② **Transaction Security Report** — Markdown: info table + Risk Sources + per-source sentences, then the Comprehensive Summary (see `references/transaction-report.md`)

## Wallet Report — Standalone or Counterparty (①–⑦)

**Markdown throughout, except the dashboard — which is three `show_widget` calls.**

| Step | Surface | Emitted as |
|---|---|---|
| ① | Analysis Preface | Markdown (`>` blockquote) |
| — | Section header + `*MetaComp VisionX*` | Markdown |
| ② | Dashboard: metric cards + 4 exposure tables (2×2) | **D1** `show_widget` |
| ② | Incoming Exposure donut + legend | **D2** `show_widget` |
| ② | Outgoing Exposure donut + legend | **D3** `show_widget` |
| ②.5 | Exchange Wallet Identifier (conditional) | Markdown table |
| ③ | Wallet Security Report (4 sub-sections) | Markdown |
| ④ | Cross-Vendor Risk Comparison (4 tables) | Markdown |
| ④.5 | Vendor Alert Flags (1 table) | Markdown |
| ⑤ | Comprehensive Summary | Markdown prose |
| ⑥ | Exposure Detail Tables (4 tables + notes) | Markdown |
| ⑦ | Risk Conclusion Card | Markdown blockquote |

① **Analysis Preface** — `>` blockquote with 🔬 (see `references/wallet-report.md`)
   ⛔ SKIP entirely if this response included a transaction screening (i.e. `VisionX` was called with `transactionDetails`) — counterparty wallet case. No preface, no blockquote; go straight to the section header.

— **Section header (Markdown, immediately before D1):**
   Standalone: `## 🔐 Wallet Security Report` · Counterparty: `## 🔎 Counterparty Wallet Analysis`
   then `*MetaComp VisionX*` on the next line.

② **D1 / D2 / D3 — Wallet Security Dashboard** — call `read_me(["chart"])` first to load the donut + merging rules, then emit three `show_widget` calls back to back:
   **D1** metric cards, two rows (Overall Risk / Wallet Balance / Total Incoming / Total Outgoing + High Risk Incoming / High Risk Outgoing) + the 4 high-risk exposure tables in a 2×2 grid
   **D2** Incoming Exposure donut + legend · **D3** Outgoing Exposure donut + legend
   (see `references/visualization.md` for the widget spec; `references/chart-spec.md` for the donut construction + category colours)
   ⚠ Cold-start: if `read_me(["chart"])` errors or returns empty on the first call of a session, **retry that call once** before continuing. Never tell the user the tool is unresponsive after a single failure.

②.5 **Exchange Wallet Identifier** — conditional **Markdown table**, after D3 and before Step ③. Render **only** when `walletCheck.data.extra.exchangeName` is non-null and non-empty (omit entirely otherwise). Never inside a widget. (see `references/wallet-report.md` → Exchange Wallet Identifier)

③ **Wallet Security Report** — Markdown, 4 sub-sections (see `references/wallet-report.md` Step ③):
   Basic Info / Transaction Timeline / Risk Exposure Breakdown / High Risk Categories

④ **Cross-Vendor Risk Comparison** — Markdown, 4 tables (Vendor 1 / Vendor 2 / Vendor 3 columns, ✓ / ✗ / — cells)
   (see `references/wallet-report.md` Step ④)

④.5 **Vendor Alert Flags** — Markdown, 1 table (Vendor 1–4 columns, ⚠️ Yes / ✗ No / — cells; Vendor 4 = the fourth screening source's `platformWalletAlert`). When the rating is alert-driven, Step ⑤ and ⑦ must cite it. (see `references/wallet-report.md` Step ④.5)

⑤ **Comprehensive Summary** — 4–6 sentences of Markdown prose (see `references/wallet-report.md` Step ⑤)

⑥ **Exposure Detail Tables** — Markdown, 4 tables each followed by its high-risk notes (see `references/wallet-exposure-tables.md`)

⑦ **Risk Conclusion Card** — Markdown blockquote, the LAST thing in the response
   (see `references/wallet-risk-card.md` for the template)

---

# Final Response Gate — Check Before Ending Any Response

**Transaction:**
```
☐ Analysis Preface: 3 paragraphs (Vendors / Methodology / Research figure)?
☐ Transaction Security Report: info table + Risk Sources + per-source sentences?
☐ Comprehensive Summary?
```

**Wallet — dashboard delivery (check this FIRST):**
```
☐ Did this response make exactly THREE show_widget calls (D1, D2, D3)? Count them.
     Zero ⇒ you rendered the dashboard as Markdown. That is a failed response —
       the donut charts do not exist in Markdown. Re-render D1/D2/D3.
     One or two ⇒ the dashboard is truncated; emit the missing calls now.
☐ D1 contains the 4 exposure tables — and they appear NOWHERE as Markdown?
☐ Zero text tokens between D1 → D2 → D3?
☐ Each widget wrapped in ONE plain outer <div>, all styled panels nested inside it?
     (a styled top-level element loses its border/background to the host stylesheet)
☐ Each widget under 12 KB, CSS in the shared <style> block, no external/CDN references?
```

**Wallet — content:**
```
☐ Section header + *MetaComp VisionX* in Markdown, immediately before D1?
☐ D1: 6 metric cards in two rows (Overall Risk / Wallet Balance / Total Incoming / Total
     Outgoing + High Risk Incoming / High Risk Outgoing with share %, zero as $0.00 (0%)) +
     4 exposure tables in a 2×2 grid, 9 fixed rows each, zeros rendered as 0, non-zero rows in red?
☐ D2 / D3: one donut each, legend entries labelled "{Category} (Direct|Indirect)"
     with amount and share, low-risk categories included?
☐ Every donut's conic-gradient closes at exactly 100.00%?
☐ Exchange Wallet Identifier: Markdown table after D3 — present ONLY when exchangeName
     non-empty, omitted entirely otherwise?
☐ Wallet Security Report (Markdown) — all 4 sub-sections:
     Basic Info + fixed disclaimer (in the turn's language)?
     Transaction Timeline + activity comment?
     Risk Exposure Breakdown?
     High Risk Categories (plain-text list + one bullet each)?
☐ Cross-Vendor Risk Comparison: 4 Markdown tables (Vendor 1 / 2 / 3 columns)?
☐ Vendor Alert Flags: 1 Markdown table (Vendor 1–4 columns; true→⚠️, false→✗, null→—;
     all-null → no-data line; no real vendor name printed)?
☐ Comprehensive Summary: 4–6 sentences of prose, no numbered list, no "Recommendation"?
☐ Exposure Detail: 4 Markdown tables, every entry, no merged rows, each followed by its
     high-risk notes?
☐ Risk Conclusion Card: Markdown blockquote, LAST?
```

**Wallet — turn hygiene.** Scan the whole turn, not just the final message:

```
☐ STEP ZERO confirmation line: present, and appearing EXACTLY ONCE across every message
     in this turn? (zero occurrences and two occurrences are both failures)
☐ VisionX called exactly ONCE this turn? (a second call is billed and returns nothing new)
☐ No tool-call narration anywhere ("Let me screen…", "现在为你查询…")?
```

**Wallet — numeric self-check.** Compute each of these before ending the response; any failure means
re-render that block. Structural checkboxes alone do not catch wrong numbers.

```
☐ Sum of the isHighRisk amounts in the Step ② tables:
     Incoming (direct + indirect) == `incomingRiskExposureBreakdown.highRiskAmount`
     Outgoing (direct + indirect) == `outgoingRiskExposureBreakdown.highRiskAmount`
   A mismatch means the tables were built from the wrong array
   → see `visualization.md` → Data-source exclusivity.
☐ Total Incoming ≠ Total Outgoing (distinct fields; equal values mean one was copied twice)
☐ Wallet Balance / Total Incoming / Total Outgoing identical in Step ② and Step ③,
     each rendered in full with thousands separators AND two decimals
☐ High Risk % magnitude check: (rendered % ÷ 100) × totalAmount ≈ highRiskAmount.
     Off by 100× or 1000× ⇒ the `× 100` was dropped or duplicated — recompute.
     Two significant digits, never rounded down to `0.00%`.
☐ Every percentage that appears more than once in the response has the same magnitude
     in all places (tables, summary lines, prose, Risk Verdict card)
☐ Each donut legend's shares sum to 100.00% (±0.05)
☐ Each conic-gradient's last slice ends at exactly 100.00% (a short close means the
     denominator is wrong)
☐ Step ⑥ row count per table == length of its source array (no dropped entries)
☐ Any Step ④ vendor column whose source array is empty is `—` on every row
☐ Risk level rendered as one of the four mapped badges only — no raw `level` string,
   no `🔴 High (Severe)`
```

**Failed screening call — check before sending any error message:**

```
☐ Did the error carry an explicit access signal (401 / 403 / invalid key / expired token /
     authPageUrl)?
       Yes → Authorization Guide is correct.
       No  → you MUST use the Data Unavailable notice instead. An empty result, a blank error
             with no message, or a long wait followed by nothing is a data-service timeout —
             the connection and the key are fine.
☐ If the cause was NOT an access error: is the message free of "re-authorize", "enter your key",
     "Allow", "connect", "not connected", and "add a connector"?
```

Any unchecked item → render it now before ending the response.

---

# Screening Call Failure — Triage

⛔ **A failed VisionX call is NOT evidence of an authorization problem.** Read the error before you
choose a message. Only Case A below may show the Authorization Guide; everything else must not
mention keys, authorization, connecting, or re-sending credentials — those are already fine.

### Case A — the error actually says it is an access problem
Trigger **only** when the error carries an explicit access signal: HTTP `401` / `403`, or wording such
as *unauthorized*, *forbidden*, *invalid key*, *expired token*, *authentication failed*, or a payload
containing `authPageUrl`.
→ Render the **Authorization Guide** below. STOP.

### Case B — anything else (this is the common case)
Trigger when the call returns **no usable result** and there is no explicit access signal:

- an empty or blank error with no message
- `null`, `{}`, or an empty string as the result
- a result whose `walletCheck` **and** `transactionCheck` are both `null`
- a timeout, a `5xx`, a gateway/network error

A blank error after a long wait is a **timeout on the data service** — the connector is connected and
the key is valid. Saying "please re-authorize" here is simply wrong, and it sends the user to fix
something that is not broken.

→ Render the **Data Unavailable notice** below. STOP.

⛔ Do **not** silently retry the call in the same turn: a retry costs another full call and another
timeout wait. Ask the user to re-send instead.

### Data Unavailable notice (Case B template)

```markdown
> ⚠️ **MetaComp VisionX returned no data**
>
> The screening request for `{address}` completed without returning any result. This is a data-service
> issue, not an access issue — your connection and your key are both fine.
>
> Please wait a moment and send the address again. If it keeps coming back empty, contact the MetaComp
> VisionX service team.
```

**中文报告：**

```markdown
> ⚠️ **MetaComp VisionX 未返回数据**
>
> 针对 `{address}` 的筛查请求已完成，但接口数据返回为空。这是数据服务侧的问题，不是访问权限问题
> —— 连接与密钥均正常。
>
> 请稍候后重新发送该地址；若持续返回为空，请联系下游服务。
```

⚠ Render the notice in the user's dominant language (per the Language rule at the end of this file).
❌ Never tell the user in Case B to re-authorize, to enter a key, to reconnect, or to add a connector.
❌ Never claim MetaComp VisionX is "not connected" / "unreachable" / "not added".

---

# MetaComp VisionX — Authorization Guide

⛔ **Only for Case A above.** Do not render this guide for an empty result, a blank error, or a timeout.

Two steps. Never instruct the user through a host-app navigation path (sidebar / settings menus / "add custom connector") — the connector already exists; the only action the user takes is re-authorizing it.

⚠ **Framing constraint for your lead-in sentence:** state that MetaComp VisionX access needs to be **(re-)authorized**, then render the guide. Do NOT claim the server is "not connected" / "unreachable" / "not added yet", and do NOT tell the user to add or configure a connector.

### Step 1 — Re-authorize / change your key in **Metacomp MCP**
Enter your `sk-...` key → **Allow**

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

### Step 2 — Re-send your request
**Still 401 after authorizing?** Re-authorize, or apply for a new key at metacomp.ai.

⚠ **Render this guide in the user's dominant language** (per the Language rule at the end of this file) — translate the headings and body, do NOT paste the English above verbatim when the user is writing in another language. Only these stay verbatim in every language: `Metacomp MCP`, `sk-...`, `Allow`, `401`, `metacomp.ai`.

---

# Tool Reference

### `VisionX`

One tool covers wallet-only, transaction-only, and combined screening. **Billed once per call — call it at most once per turn.**

```json
{
  "network": "Bitcoin|Ethereum|Tron",
  "walletAddress": "0x...",            // optional — wallet to screen
  "transactionDetails": [{             // optional — transactions to screen
    "hash": "0x...", "asset": "USDT",
    "direction": "received|sent",
    "from": "0x...", "to": "0x..."
  }]
}
```

`network` is required **in the tool call** — infer it from the address format (see Network Inference); only ask the user if it cannot be determined. Provide `walletAddress`, `transactionDetails`, or both (at least one).

**Returns:**
```json
{
  "transactionCheck": { ... } | null,
  "walletCheck": { ... } | null
}
```
- Read `transactionCheck` for the Transaction Report.
- Read `walletCheck` for the Wallet Report. The counterparty wallet is screened automatically, resolved server-side from the transaction `direction` (received → sender's `from`; sent → recipient's `to`).

**Wallet only** → call `VisionX({ network, walletAddress })`; read `walletCheck`.

**Transaction** → call `VisionX({ network, transactionDetails })` ONCE (one call returns both the transaction and the single counterparty-wallet result). Present the Transaction Report first, then the counterparty Wallet Report from `walletCheck`.

### Set `direction` from which party you're checking (always ask — never infer):
The "Are you checking the sender or the recipient?" answer sets the transaction `direction`. The server then screens that party's wallet automatically.
| Party you're checking | `direction` value | Wallet screened (server-side) |
|---|---|---|
| Sender | `received` | `from` address (sender's wallet) |
| Recipient | `sent` | `to` address (recipient's wallet) |

---

# Absolute Rules

- ❌ Do NOT analyze using own knowledge, web search, or block explorers.
- ❌ Do NOT interpret screenshots or pasted text as a security analysis.
- ❌ Do NOT provide partial analysis before the screening call succeeds.
- ✅ The screening call fails for ANY reason → STOP, and triage the failure before writing anything
  (see "Screening Call Failure — Triage"). An explicit access error (401/403/invalid key/expired
  token/`authPageUrl`) → Authorization Guide. Empty result, blank error, or timeout → Data Unavailable
  notice. ⛔ Never default to the Authorization Guide just because a call failed.
- **Vendor confidentiality:** ❌ NEVER display any real vendor name (Beosin, Elliptic, Merkle Science, Chainalysis, TRM, SlowMist, or any other) ANYWHERE in the output — including the Analysis Preface, all prose, and every table (Cross-Vendor Risk Comparison included). ✅ ALWAYS refer to vendors only by the anonymous labels **Vendor 1 / Vendor 2 / Vendor 3 / …** (assign in a stable order within one response), or by aggregate phrasing ("multiple vendors", "cross-vendor consensus", "all vendors"). There is NO exception — the Analysis Preface must NOT name vendors either.

---

# Language

Detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning, tool-call preambles, tool-parameter descriptions, and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English.

**Tables and widgets are NOT exempt.** Every string this skill generates is covered: Markdown table headers, field names, row labels, risk badges (`⚠️ High Risk` → `⚠️ 高风险`), verdict and recommendation lines, empty-state lines (`— No direct incoming exposure recorded —` → `— 无直接流入敞口记录 —`), section headings, and every label inside widget HTML. The table templates in `references/*.md` are **structural specs written in English, not verbatim strings** — in a non-English turn, translate every header, label, and badge in them, exactly as the 中文报告 example in `wallet-report.md` (Exchange Wallet Identifier) demonstrates; that treatment applies to EVERY table. Reproducing an English template verbatim in a non-English turn is a Language-rule violation, not fidelity to the spec.

The ONLY strings that stay verbatim in every language: the STEP ZERO `Sub-files have been read` confirmation line; currency/asset codes (USD, USDT, BTC…); network names; addresses and hashes; brand and proper names (MetaComp, MetaComp VisionX, and entity/exchange names such as OKX or Uniswap); and `DeFi` (a term of art in every language — also when the data spells it `Defi` or `Deft`). The anonymous vendor labels localize naturally (`Vendor 1` → `厂商 1`) while staying anonymous.

**Category vocabulary is LOCALIZED, never left in English in a non-English turn.** Every risk/exposure category name — `tagTypeVerbose` values, the fixed nine high-risk rows of the D1 tables, donut-legend entries, detail-table rows, high-risk category lists — follows the turn's language. Display format: **English turn → English name only** (`Gambling`); **non-English turn → the localized name ONLY** (`赌博`) — ⛔ never append the English original in parentheses (`赌博（Gambling）` is wrong), in tables, widgets, legends, lists, AND prose alike. Canonical Chinese renderings (use these exact words every time):

| High-risk (fixed 9) | 中文 | Low-risk / other | 中文 |
|---|---|---|---|
| Sanctions | 制裁 | Exchange | 交易所 |
| High Risk Organisation | 高风险机构 | DeFi / Defi / Deft | DeFi |
| Theft | 盗窃 | Smart Contract Platform | 智能合约平台 |
| Malware | 恶意软件 | Others | 其他 |
| Scams | 诈骗 | Service | 服务 |
| Extortion | 勒索 | Mining | 挖矿 |
| Coin Mixer | 混币器 | Unknown | 未知 |
| Darknet | 暗网 | | |
| Gambling | 赌博 | | |

Other languages: translate the category names with the same care, localized name only. A server value with no row above and no self-evident translation stays verbatim rather than guessed. Terms kept as-is (`DeFi`, proper names) stay exactly as they are.

# Branding

- Always say **MetaComp VisionX**.
- Never say "MCP server" or "the server" alone.
