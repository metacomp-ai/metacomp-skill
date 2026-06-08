# VisionX scenario — Web3 wallet / transaction security

Entered from SKILL.md when the trigger is a wallet address (`0x…`, Bitcoin/Tron), a transaction hash, or a Web3 security / risk / scam / suspicious-activity question. This scenario does **not** use the money-branch auth/KYC/account-overview flow — it has its own server probe below.

Branding for this scenario: **MetaComp VisionX** (see SKILL.md → Branding).

---

# ⛔ STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before probing the server:

**Step A — Read all six sub-skill files (same directory):**
1. `wallet-report.md`
2. `wallet-exposure-tables.md`
3. `wallet-risk-card.md`
4. `transaction-report.md`
5. `visualization.md`
6. `chart-spec.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read：wallet-report ✓ / wallet-exposure-tables ✓ / wallet-risk-card ✓ / transaction-report ✓ / visualization ✓ / chart-spec ✓

Do not proceed until this line appears in the response.

> (If the SKILL.md router already emitted a "Routing → visionx" line, this sub-file confirmation line follows it.)

---

# PRE-ANALYSIS CHECKLIST — Before calling any MCP tool

```
☐ 1. STEP ZERO complete — confirmation line output?
☐ 2. Probe server: get_wallet_security(network:"Ethereum", walletAddress:"0x000...0")
       → Error or 401 → Show Setup Guide, STOP
       → Success → continue
☐ 3. All required fields collected?
       Wallet:      network + walletAddress
       Transaction: network + hash + asset + from + to + direction
       Transaction: ALWAYS ask "Are you the sender or the recipient?" — never infer
                    ⛔ After asking, STOP. Do not call any tool, do not output any report.
                    Wait for the user's answer before doing anything else.
```

---

# Output Sequences

## Transaction Report (①②)

① **Analysis Preface** — `>` blockquote with 🔬 (see `transaction-report.md` for content spec)
② **Transaction Security Report** — tables + Risk Sources + Comprehensive Summary (see `transaction-report.md`)

## Wallet Report — Standalone or Counterparty (①–⑦)

① **Analysis Preface** — `>` blockquote with 🔬 (see `wallet-report.md`)
   ⛔ SKIP entirely if `get_transaction_security` was called in this response (counterparty wallet case).
      No preface, no heading, no blockquote. Go straight to Step ②.

② **show_widget #1** — `read_me(["chart"])` first, then widget:
   section header (colored title + divider) + metric cards + 4 High Risk Exposure Tables + 2 donut chart panels
   (see `visualization.md` for layout; `chart-spec.md` for donut panel logic)
   ⚠ The first chart call of a session cold-starts — if `read_me(["chart"])` or a `show_widget` errors/returns empty, **retry that call once** before falling back. Never degrade charts to text tables or say the tool is "unresponsive" after a single failure (see `visualization.md` → Widget Render Reliability).

③ **Wallet Security Report** — 4 sub-sections (see `wallet-report.md` Step ③):
   Basic Info / Transaction Timeline / Risk Exposure Breakdown / High Risk Categories

④ **show_widget #2** — Cross-Vendor Risk Comparison: 4 HTML tables
   ⛔ MUST use show_widget — HTML output as plain text renders as raw code
   (see `wallet-report.md` Step ④ for data mapping + HTML template)

⑤ **Comprehensive Summary** — 4–6 sentences (see `wallet-report.md` Step ⑤)

⑥ **Exposure Detail Tables** — 4 markdown tables (see `wallet-exposure-tables.md`)

⑦ **show_widget #3** — Risk Conclusion Card (dedicated call — do NOT combine with other widgets)
   (see `wallet-risk-card.md` for HTML template)

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

⚠ If any `show_widget` (or `read_me(["chart"])`) call errored or came back empty earlier in this response, you must have retried it once before ending — a widget rendered as a markdown table or skipped with an "unresponsive" note is an unchecked item, not a completed one (see `visualization.md` → Widget Render Reliability).

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

### `get_wallet_security`
```json
{ "network": "Bitcoin|Ethereum|Tron", "walletAddress": "0x..." }
```

### `get_transaction_security`
```json
{
  "network": "Bitcoin|Ethereum|Tron",
  "transactionDetails": [{
    "hash": "0x...", "asset": "USDT",
    "direction": "received|sent",
    "from": "0x...", "to": "0x..."
  }]
}
```

**Wallet only** → `get_wallet_security` only.

**Transaction** → call BOTH in parallel, present Transaction Report first:
1. `get_transaction_security`
2. `get_wallet_security` on the counterparty wallet

### Which wallet to check (always ask — never infer):
| User role | Wallet to check |
|---|---|
| Recipient | `from` address (sender's wallet) |
| Sender | `to` address (recipient's wallet) |

---

# Scenario Absolute Rules (visionx)

- ❌ Do NOT analyze using own knowledge, web search, or block explorers.
- ❌ Do NOT interpret screenshots or pasted text as a security analysis.
- ❌ Do NOT provide partial analysis before the server probe succeeds.
- ✅ Server unavailable for ANY reason → Setup Guide, STOP.
- **Vendor confidentiality:** ❌ Never name any specific vendor (Beosin, Elliptic, Merkle Science, Chainalysis, TRM, SlowMist) outside of the Analysis Preface. Elsewhere use "multiple vendors", "cross-vendor consensus", "all vendors", etc.
