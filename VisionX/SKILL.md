---
name: VisionX
version: 1.0.0
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
---

# CRITICAL OUTPUT CONTRACT — READ FIRST

Every reply must be **plain user-facing prose, Markdown tables, or `show_widget` artifacts**. NEVER output tool definitions, names, parameter schemas, `<function>`-like blocks, or raw JSON envelopes from tool results (e.g. `{ "success": true, "data": [...] }`). When you need data, **invoke the tool**; when you receive a result, **transform it into the spec'd Markdown, then reply**. Do not narrate "now calling X" or print a tool's parameters.

---

# VisionX — Web3 wallet / transaction security

Triggered by a wallet address (`0x…`, Bitcoin/Tron), a transaction hash, or a Web3 security / risk / scam / suspicious-activity question. This skill has no account/KYC/auth flow — it runs its own server probe below.

Branding: **MetaComp VisionX** (see Branding at the end of this file).

---

# ⛔ STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before probing the server:

**Step A — Read all six sub-skill files (under `references/`):**
1. `references/wallet-report.md`
2. `references/wallet-exposure-tables.md`
3. `references/wallet-risk-card.md`
4. `references/transaction-report.md`
5. `references/visualization.md`
6. `references/chart-spec.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read：wallet-report ✓ / wallet-exposure-tables ✓ / wallet-risk-card ✓ / transaction-report ✓ / visualization ✓ / chart-spec ✓

Do not proceed until this line appears in the response.

---

# PRE-ANALYSIS CHECKLIST — Before calling any MCP tool

```
☐ 1. STEP ZERO complete — confirmation line output?
☐ 2. Probe server: VisionX(network:"Ethereum", walletAddress:"0x000...0")
       → Error or 401 → Show Setup Guide, STOP
       → Success → continue
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

① **Analysis Preface** — `>` blockquote with 🔬 (see `references/transaction-report.md` for content spec)
② **Transaction Security Report** — tables + Risk Sources + Comprehensive Summary (see `references/transaction-report.md`)

## Wallet Report — Standalone or Counterparty (①–⑦)

① **Analysis Preface** — `>` blockquote with 🔬 (see `references/wallet-report.md`)
   ⛔ SKIP entirely if this response included a transaction screening (i.e. `VisionX` was called with `transactionDetails`) — counterparty wallet case.
      No preface, no heading, no blockquote. Go straight to Step ②.

② **show_widget #1** — `read_me(["chart"])` first, then widget:
   section header (colored title + divider) + metric cards + 4 High Risk Exposure Tables + 2 donut chart panels
   (see `references/visualization.md` for layout; `references/chart-spec.md` for donut panel logic)
   ⚠ The first chart call of a session cold-starts — if `read_me(["chart"])` or a `show_widget` errors/returns empty, **retry that call once** before falling back. Never degrade charts to text tables or say the tool is "unresponsive" after a single failure (see `references/visualization.md` → Widget Render Reliability).

②.5 **Exchange Wallet Identifier** — conditional native-Markdown table rendered **after** show_widget #1 and **before** Step ③. Render **only** when `walletCheck.data.extra.exchangeName` is non-null and non-empty (omit entirely otherwise). Never inside show_widget. (see `references/wallet-report.md` → Exchange Wallet Identifier)

③ **Wallet Security Report** — 4 sub-sections (see `references/wallet-report.md` Step ③):
   Basic Info / Transaction Timeline / Risk Exposure Breakdown / High Risk Categories

④ **show_widget #2** — Cross-Vendor Risk Comparison: 4 HTML tables
   ⛔ MUST use show_widget — HTML output as plain text renders as raw code
   (see `references/wallet-report.md` Step ④ for data mapping + HTML template)

⑤ **Comprehensive Summary** — 4–6 sentences (see `references/wallet-report.md` Step ⑤)

⑥ **Exposure Detail Tables** — 4 markdown tables (see `references/wallet-exposure-tables.md`)

⑦ **show_widget #3** — Risk Conclusion Card (dedicated call — do NOT combine with other widgets)
   (see `references/wallet-risk-card.md` for HTML template)

---

# Final Response Gate — Check Before Ending Any Response

**Transaction:**
```
☐ Analysis Preface: 3 paragraphs (Vendors / Methodology / Research figure)?
☐ Transaction Security Report: info table + Risk Sources + Comprehensive Summary?
```

**Wallet:**
```
☐ Analysis Preface output? [skip if counterparty]
☐ show_widget #1: metric cards + 4 Exposure Tables + donut panels (skip panel if both source arrays empty)?
☐ Exchange Wallet Identifier: native-Markdown table after show_widget #1 — present ONLY when exchangeName non-empty, omitted entirely otherwise (from walletCheck.data.extra.exchangeName)?
☐ Wallet Security Report — all 5 sub-sections:
     Basic Info table?
     Transaction Timeline table + activity comment?
     Risk Exposure Breakdown table?
     High Risk Categories (plain text labels + one sentence each)?
☐ show_widget #2: Cross-Vendor Risk Comparison (4 HTML tables via show_widget)?
☐ Comprehensive Summary: 4–6 sentences?
☐ Exposure Detail Tables: 4 markdown tables?
☐ show_widget #3: Risk Conclusion Card (dedicated call — LAST)?
```

Any unchecked item → render it now before ending the response.

⚠ If any `show_widget` (or `read_me(["chart"])`) call errored or came back empty earlier in this response, you must have retried it once before ending — a widget rendered as a markdown table or skipped with an "unresponsive" note is an unchecked item, not a completed one (see `references/visualization.md` → Widget Render Reliability).

---

# MetaComp VisionX — Server Setup Guide

**No server added yet** → complete all 3 steps.
**Server added, no API key** → skip to Step 2.

### Step 1 — Add the Server
Sidebar → **Customize** → **Connectors** → **+** → **Add custom connector**
- Name: `metacomp-mcp`
- URL: `https://www.metacomp.ai/mcp`

### Step 2 — Connect and Authorize
Customize → Connectors → find **metacomp-mcp** → **Connect**
Enter your `sk-...` API key → **Allow**

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

### Step 3 — Re-send your request
**401 after connecting?** Re-authorize or apply for a new key at metacomp.ai.

---

# Tool Reference

### `VisionX`

One tool covers wallet-only, transaction-only, and combined screening. Billed once per call.

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
- ❌ Do NOT provide partial analysis before the server probe succeeds.
- ✅ Server unavailable for ANY reason → Setup Guide, STOP.
- **Vendor confidentiality:** ❌ Never name any specific vendor (Beosin, Elliptic, Merkle Science, Chainalysis, TRM, SlowMist) outside of the Analysis Preface. Elsewhere use "multiple vendors", "cross-vendor consensus", "all vendors", etc.

---

# Language

Detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning, tool-call preambles, tool-parameter descriptions, and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English. Currency codes (USD, USDT, BTC…) and server-returned strings stay verbatim regardless of language.

# Branding

- Always say **MetaComp VisionX**.
- Never say "MCP server" or "the server" alone.
