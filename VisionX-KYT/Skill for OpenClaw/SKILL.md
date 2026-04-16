---
name: VisionX-KYT
description: "Check Web3 wallet or transaction security using MetaComp VisionX. Trigger when user mentions wallet address (0x..., Bitcoin, Tron), transaction hash, or asks about Web3 security, risk, scam, or suspicious activity. When triggered, read the full SKILL.md file at the skill location before calling any tool or writing any response."
version: 2.0.0
homepage: https://www.metacomp.ai
metadata: {"openclaw": {"emoji": "🔐", "homepage": "https://www.metacomp.ai", "requires": {"env": ["METACOMP_TOKEN"]}, "primaryEnv": "METACOMP_TOKEN", "install": [{"id": "npm", "kind": "node", "package": "@metacomp/visionx-kyt-mcp", "bins": ["visionx-kyt-mcp"], "label": "Install MetaComp VisionX KYT MCP server (requires METACOMP_TOKEN API key from metacomp.ai)"}]}}
---

# Channel Detection — Output Format Routing

**Lark (飞书) channel:** If this conversation is running through a Lark bot integration, OR the user explicitly requests Lark card format, OR the system context indicates a Lark/Feishu channel:
→ Read `{baseDir}/references/lark-cards.md` FIRST, then use its **Lark Card JSON v2** format for all output. The PRE-ANALYSIS CHECKLIST, tool calls, data extraction logic, and Absolute Rules from THIS file still apply — only the rendering format changes.

**All other channels** (CLI, web, Slack, or unknown):
→ Use the **Markdown output format** defined below in this file.

---

# PRE-ANALYSIS CHECKLIST — Before calling any tool

```
☐ 1. Probe server: get_wallet_security(network:"Ethereum", walletAddress:"0x000...0")
       → Error or 401 → Show Setup Guide, STOP
       → Success → continue
☐ 2. All required fields collected?
       Wallet:      network + walletAddress
       Transaction: network + hash + asset + from + to + direction
       Transaction: ALWAYS ask "Are you the sender or the recipient?" — never infer
                    ⛔ After asking, STOP. Do not call any tool, do not output any report.
                    Wait for the user's answer before doing anything else.
```

---

# Output Sequences

## Transaction Report (①②)

① **Analysis Preface** — `>` blockquote with 🔬 (see Transaction Report spec below)
② **Transaction Security Report** — info table + Risk Sources table + Comprehensive Summary

## Wallet Report — Standalone or Counterparty (①–⑥)

① **Analysis Preface** — `>` blockquote with 🔬
   ⛔ SKIP entirely if `get_transaction_security` was called in this response (counterparty wallet case).
     Skip the blockquote preface only — do NOT skip the Wallet Security Report heading in Step ②. Go straight to Step ②.

② **Wallet Security Report** — 4 sub-sections (Basic Info / Transaction Timeline / Risk Exposure Breakdown / High Risk Categories)

③ **Cross-Vendor Risk Comparison** — 4 markdown tables (Direct Incoming / Direct Outgoing / Indirect Incoming / Indirect Outgoing)

④ **Comprehensive Summary** — 4–6 sentences

⑤ **Exposure Detail Tables** — 4 markdown tables (all entries, high and low risk)

⑥ **Risk Verdict** — prominent markdown block with risk level + recommendation

---

# Transaction Report Spec

## Step ①: Analysis Preface

Render as a `>` blockquote opening with 🔬. Write fresh each time in the user's language.
Three separate paragraphs — do NOT merge them.

**Paragraph 1 — Data Sources**
Name all six vendors: **Chainalysis, Elliptic, TRM, Merkle Science, Beosin, and SlowMist**.
Explain cross-verification eliminates individual blind spots. (1–2 sentences)

**Paragraph 2 — Methodology**
Describe the two-layer analysis: Layer 1 checks direct contact with flagged addresses; Layer 2 traces all fund flows forward and backward through unlimited on-chain hops, calculating taint ratios at each hop depth.
⛔ Do NOT use the word "threshold" or mention specific threshold values.
Adapt framing: high risk → emphasize both layers triggered; low risk → explain both layers returned clean; Tron → mention ~10× higher sanctions exposure than Ethereum.

**Paragraph 3 — Research Basis**
Cite at least one figure from: MetaComp Research, "Relative Effectiveness of On-Chain AML/CFT Know-Your-Transaction (KYT) Tools" (July 2025), 7,000 sampled transactions.
Key findings (pick most relevant):
- 1 vendor alone: false-clean rate up to 25%
- 2 vendors: 7–22%
- 3+ vendors: below 0.25% — the standard this report meets
- Tron: ~10× higher sanctions exposure than Ethereum (6.95% vs 0.70% severe risk)
- 20%+ of sampled Tron transactions rated medium-high risk or above

## Step ②: Transaction Security Report

**If `data.extra.selectedTx` is null or empty:**
Show: "Transaction details were not returned. Overall risk level: `data.level`."

**For each entry in `data.extra.selectedTx`:**

**Transaction:** `txHash` (first 10 + last 4 chars)

| Field | Detail |
|---|---|
| Date | `date` |
| Direction | `direction` (received / sent) |
| Asset | `asset.asset` |
| Amount | `asset.amount` |
| USD Value | `$asset.usdValue` USD |
| From | `fromAddress` |
| To | `toAddress` |
| Risk Level | 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High / 🔴 Severe (treat as High) — from `txRiskLevel` |
| Direct Exposure | Yes / No |

**⚠️ Risk Sources**

| Risk Type | Ratio | Interpretation |
|---|---|---|
| `source` | `ratio` | < 5%: low/residual · 5–20%: moderate · > 20%: significant |

For each risk source, add one sentence on practical implications.
If `riskSources` empty: "✅ No risk sources identified."

**📋 Comprehensive Summary** (4–5 sentences)
⛔ Do NOT name any specific vendor. Use "multiple vendors", "cross-vendor consensus", etc.
1. Overall safety verdict
2. What the risk level means practically
3. Explanation of each risk source
4. How transaction direction (sent/received) affects risk implication
5. Actionable recommendation: safe / caution / flag for review / avoid

**Error Handling**
- `data.success === false` or `code !== 0` → check failed; suggest retry or metacomp.ai support
- 401 → API key invalid/expired; re-authenticate
- Unsupported network → only Bitcoin, Ethereum, Tron supported

---

# Wallet Report Spec

## Step ①: Analysis Preface

**Before writing anything — answer this question:**
Was `get_transaction_security` called earlier in this response?
- **YES** → ⛔ Skip Step ① entirely. No preface, no heading, no blockquote. Go directly to Step ②.
- **NO** → Proceed to write the preface below.

Render as a `>` blockquote opening with 🔬. Write fresh in the user's language.
Two separate paragraphs — do NOT merge them. Do NOT include methodology (Layer 1/Layer 2/taint) — that is transaction-report only.

**Paragraph 1 — Data Sources**
Name all six vendors: **Chainalysis, Elliptic, TRM, Merkle Science, Beosin, and SlowMist**.
Explain cross-verification eliminates individual blind spots. (1–2 sentences)

**Paragraph 2 — Research Basis**
Cite at least one figure from: MetaComp Research, "Relative Effectiveness of On-Chain AML/CFT Know-Your-Transaction (KYT) Tools" (July 2025).
Key findings (pick most relevant):
- 1 vendor alone: false-clean rate up to 25%
- 2 vendors: 7–22%
- 3+ vendors: below 0.25% — the standard this report meets
- Tron: ~10× higher sanctions exposure than Ethereum (6.95% vs 0.70%)
- 20%+ of sampled Tron transactions rated medium-high risk or above

Tone: Low risk → explain why clean rating is trustworthy; Tron → reference risk ratio; High risk → reference multi-vendor parallel scanning.

## Step ②: Wallet Security Report (4 sub-sections — all required)

If this is a counterparty wallet, prepend the heading:
**🔎 Counterparty Wallet Analysis**

Otherwise use:
**🔐 Wallet Security Report — MetaComp VisionX**

---

### Basic Info

| Field | Detail |
|---|---|
| Address | `data.address` |
| Network | `data.network` |
| Overall Risk Level | 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — from `data.level`. **Map "Severe" → 🔴 High. Any other unrecognized level → display raw value with 🔴** |

### Transaction Timeline

| Field | Detail |
|---|---|
| Earliest Transaction | `data.extra.earliestTransactionTime` |
| Latest Transaction | `data.extra.latestTransactionTime` |
| Total Incoming | `$data.extra.totalIncoming` USD |
| Total Outgoing | `$data.extra.totalOutgoing` USD |

Briefly comment on activity span and volume (long-standing vs newly created, notable volume?).

### Risk Exposure Breakdown

| Direction | Total | Low Risk | High Risk | High Risk % |
|---|---|---|---|---|
| Incoming | `$incomingRiskExposureBreakdown.totalAmount` | `$...lowRiskAmount` | `$...highRiskAmount` | `highRisk/total×100`% |
| Outgoing | `$outgoingRiskExposureBreakdown.totalAmount` | `$...lowRiskAmount` | `$...highRiskAmount` | `highRisk/total×100`% |

### High Risk Categories Associated

List all items in `data.extra.highRiskCategories` separated by ` · `
Example: `Sanctions · Theft · Malware`

For each category present, add one sentence using the descriptions in Absolute Rules below.
If list empty: "✅ No high-risk categories detected."
For any category NOT in the predefined list, describe it based on its name and add one general sentence about its risk implications.

## Step ③: Cross-Vendor Risk Comparison

Render 4 markdown tables. All table headers MUST use **Vendor 1 / Vendor 2 / Vendor 3** — never actual vendor names.

**How to build each table:**
1. Collect all unique `tagTypeVerbose` values across the three vendors for that direction → rows
2. For each cell:
   - Entry found in vendor's array AND `isHighRisk == true` → `⚠️ High`
   - Entry found in vendor's array AND `isHighRisk == false` → `✅ Low`
   - Entry NOT found in vendor's array, OR vendor's array is empty `[]` → `—`
   - ⛔ If a vendor's array is empty `[]`, ALL cells for that vendor MUST show `—`. Never infer or populate any cell from an empty array.
3. All three vendors have no data for a direction → show: `— No data from any vendor —`

**Data mapping:**

| Table | Title | Vendor 1 | Vendor 2 | Vendor 3 |
|---|---|---|---|---|
| 1 | 📥 Direct Incoming | `data.extra.beosin.directIncoming` | `data.extra.elliptic.directIncoming` | `data.extra.merklescience.directIncoming` |
| 2 | 📤 Direct Outgoing | `data.extra.beosin.directOutgoing` | `data.extra.elliptic.directOutgoing` | `data.extra.merklescience.directOutgoing` |
| 3 | 📥 Indirect Incoming | `data.extra.beosin.indirectIncoming` | `data.extra.elliptic.indirectIncoming` | `data.extra.merklescience.indirectIncoming` |
| 4 | 📤 Indirect Outgoing | `data.extra.beosin.indirectOutgoing` | `data.extra.elliptic.indirectOutgoing` | `data.extra.merklescience.indirectOutgoing` |

**Table format:**

🔍 **Cross-Vendor Risk Comparison**

📥 **Direct Incoming — Cross-Vendor Risk Flags**

| Category | Vendor 1 | Vendor 2 | Vendor 3 |
|---|---|---|---|
| {tagTypeVerbose} | ⚠️ High / ✅ Low / — | ⚠️ High / ✅ Low / — | ⚠️ High / ✅ Low / — |

(repeat for tables 2–4 with appropriate titles and data)

## Step ④: Comprehensive Summary (4–6 sentences)

⛔ Do NOT name any specific vendor. Replace with: "multiple vendors", "cross-vendor consensus", "all vendors", etc.

1. Overall risk verdict — is this wallet safe to interact with?
2. What the risk level means practically
3. Key concerns (specific categories, exposure amounts, counterparty patterns)
4. Whether transaction history suggests legitimate or suspicious usage
5. Clear actionable recommendation: freely interact / proceed with caution / avoid / report

## Step ⑤: Exposure Detail Tables

Render 4 markdown tables. Include **every entry** — never skip $0 rows.
❌ No HTML — plain text and emoji only.

**📥 Direct Incoming Exposure** (`data.extra.directIncoming`)

| Category | Amount (USD) | Ratio | Risk |
|---|---|---|---|
| `tagTypeVerbose` | `≈ $totalValueUsd` | `ratio > 0 ? ratio% : "< 0.01%"` | ⚠️ High Risk / ✅ Low Risk |

If empty: `— No direct incoming exposure recorded —`

**📥 Indirect Incoming Exposure** (`data.extra.indirectIncoming`)

(same format)

If empty: `— No indirect incoming exposure recorded —`

**📤 Direct Outgoing Exposure** (`data.extra.directOutgoing`)

(same format)

If empty: `— No direct outgoing exposure recorded —`

**📤 Indirect Outgoing Exposure** (`data.extra.indirectOutgoing`)

(same format)

If empty: `— No indirect outgoing exposure recorded —`

For any ⚠️ High Risk row, add one sentence explaining that category's implications.
If any indirect exposure exists, briefly explain the difference between direct and indirect exposure.

## Step ⑥: Risk Verdict

Render a prominent verdict block using the format below. This is the last element of every wallet report.

**Color mapping:**
- 🔴 High Risk or Severe → use label `🚨 High Risk`
- 🟠 Medium-High → use label `⚠️ Medium-High Risk`
- 🟡 Medium → use label `⚠️ Medium Risk`
- 🟢 Low → use label `✅ Low Risk`

```
---
🚨 Risk Verdict — [risk level label]

[1–2 sentence verdict summarizing the most important finding]

⚡ Recommendation: [freely interact / proceed with caution / avoid / report]
---
```

---

# Final Response Gate — Check Before Ending Any Response

**Transaction:**
```
☐ Analysis Preface: 3 paragraphs (Vendors / Methodology / Research)?
☐ Transaction Security Report: info table + Risk Sources + Comprehensive Summary?
```

**Wallet:**
```
☐ Analysis Preface output? [skip if counterparty]
☐ Wallet Security Report — all 4 sub-sections:
     Basic Info table?
     Transaction Timeline table + activity comment?
     Risk Exposure Breakdown table?
     High Risk Categories (text labels + one sentence each)?
☐ Cross-Vendor Risk Comparison: 4 markdown tables?
☐ Comprehensive Summary: 4–6 sentences?
☐ Exposure Detail Tables: 4 markdown tables?
☐ Risk Verdict block (last element)?
```

Any unchecked item → render it now before ending the response.

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

**High Risk Category descriptions (for the 🚨 High Risk Categories section):**
- **Sanctions**: Funds may be linked to entities under OFAC/EU/UN sanctions.
- **Theft**: Association with stolen funds or hack proceeds.
- **Malware**: Linked to ransomware or malware payment wallets.
- **Darknet**: Connected to darknet marketplace activity.
- **Scams**: Associated with phishing, fraud, or rug-pull operations.
- **High Risk Organisation**: Interaction with high-risk financial counterparties.
- **Coin Mixer**: Funds passed through mixing services to obscure trails.
- **Extortion**: Linked to extortion or blackmail payments.
- **Gambling**: Connected to unlicensed or high-risk gambling platforms.

For any category NOT in the list above, describe it based on its name and add one general sentence about its risk implications.

---

# Setup Guide

**No MCP server configured** → complete the steps below.

### Step 1 — Add the MCP server to OpenClaw config

```json
{
  "mcp": {
    "servers": {
      "metacomp-security": {
        "command": "npx",
        "args": ["-y", "--package", "@metacomp/visionx-kyt-mcp", "visionx-kyt-mcp", "--token", "YOUR_API_KEY"]
      }
    }
  },
  "skills": {
    "entries": {
      "VisionX-KYT": {
        "enabled": true
      }
    }
  }
}
```

### Step 2 — Install the skill

Download `SKILL.md` from [github.com/metacomp-ai/remote-mcp](https://github.com/metacomp-ai/metacomp-skill/tree/main/VisionX), then:

```bash
mkdir -p ~/.openclaw/workspace/skills/VisionX-KYT
cp /path/to/SKILL.md ~/.openclaw/workspace/skills/VisionX-KYT/SKILL.md
```

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

**401 after configuring?** Re-apply for a new key at metacomp.ai.
