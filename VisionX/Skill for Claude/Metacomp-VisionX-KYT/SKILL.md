---
name: metacomp-visionx-kyt
version: 1.0.1
description: >
  Check Web3 wallet or transaction security using the MetaComp VisionX
  Trigger when the user mentions: wallet address (0x..., Bitcoin address, Tron address),
  transaction hash, or asks about Web3 security, risk, scam, or suspicious activity.
metadata:
  mcpServers:
    - metacomp-mcp
---

# ⛔ STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before probing the MCP server:

**Step A — Read all six sub-skill files:**
1. `subSkills/wallet-report.md`
2. `subSkills/wallet-exposure-tables.md`
3. `subSkills/wallet-risk-card.md`
4. `subSkills/transaction-report.md`
5. `subSkills/visualization.md`
6. `subSkills/chart-spec.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read：wallet-report ✓ / wallet-exposure-tables ✓ / wallet-risk-card ✓ / transaction-report ✓ / visualization ✓ / chart-spec ✓

Do not proceed until this line appears in the response.

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

## Wallet Report — Standalone or Counterparty (①–⑧)

① **Analysis Preface** — `>` blockquote with 🔬 (see `wallet-report.md`)
   ⛔ SKIP entirely if `get_transaction_security` was called in this response (counterparty wallet case).
      No preface, no heading, no blockquote. Go straight to Step ②.

② **show_widget #1** — `read_me(["chart"])` first, then widget:
   section header (colored title + divider) + metric cards + 4 High Risk Exposure Tables + 2 donut chart panels
   (see `visualization.md` for layout; `chart-spec.md` for donut panel logic)

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

---

# MetaComp VisionX

**No server added yet** → complete all 3 steps.
**Server added, no API key** → skip to Step 2.

### Step 1 — Add the Server
Sidebar → **Customize** → **Connectors** → **+** → **Add custom connector**
- Name: `metacomp-visionx-kyt`
- URL: `https://www.metacomp.ai/mcp`

### Step 2 — Connect and Authorize
Customize → Connectors → find **metacomp-visionx-kyt** → **Connect**
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

# Absolute Rules

- ❌ Do NOT analyze using own knowledge, web search, or block explorers
- ❌ Do NOT interpret screenshots or pasted text as a security analysis
- ❌ Do NOT provide partial analysis before server probe succeeds
- ✅ Server unavailable for ANY reason → Setup Guide, STOP
- **Branding**: always say **MetaComp VisionX** — never "MCP server" or "the server" alone
- **Language**: respond in the user's language; mixed languages → respond in English
- **Vendor confidentiality**: ❌ Never name any specific vendor (Beosin, Elliptic, Merkle Science, Chainalysis, TRM, SlowMist) outside of the Analysis Preface. In all other sections, use "multiple vendors", "cross-vendor consensus", "all vendors", etc.
