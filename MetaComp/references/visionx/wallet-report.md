# Wallet Report — Content Specifications

---

## Step ①: Analysis Preface Content

**Before writing anything — answer this question:**
Did this response include a transaction screening (i.e. `VisionX` called with `transactionDetails`)?

- **YES** → ⛔ This is a counterparty wallet. Skip Step ① entirely. No preface, no heading, no blockquote. Go directly to Step ②.
- **NO** → This is a standalone wallet check. Proceed to write the preface below.

---

Render as a `>` blockquote opening with 🔬. Write fresh in the user's language.
Two separate paragraphs — do NOT merge them. Do NOT include methodology (Layer 1/Layer 2/taint) — that is transaction-report only.

### Paragraph 1 — Data Sources
Name all six vendors: **Chainalysis, Elliptic, TRM, Merkle Science, Beosin, and SlowMist**.
Explain cross-verification eliminates individual blind spots. (1–2 sentences)

### Paragraph 2 — Research Basis
Cite at least one figure from: MetaComp Research, "Relative Effectiveness of On-Chain AML/CFT Know-Your-Transaction (KYT) Tools" (July 2025). Attribute to "MetaComp Research (July 2025)".

Key findings (pick the most relevant):
- 1 vendor alone: false-clean rate up to 25%
- 2 vendors: 7–22%
- 3+ vendors: below 0.25% — the standard this report meets
- Tron: ~10× higher sanctions exposure than Ethereum (6.95% vs 0.70%)
- 20%+ of sampled Tron transactions rated medium-high risk or above

Tone guidance:
- Low risk → explain why the clean rating is trustworthy
- Tron → reference the risk ratio
- High risk → reference multi-vendor parallel scanning

---

## Exchange Wallet Identifier (conditional)

> Render as a **native Markdown table**, **after `show_widget #1` (Step ②) and before Step ③ (Wallet Security Report)**. **Never** emit this inside `show_widget` — it is plain Markdown so Claude renders it natively and theme-adaptively. Applies to **both** standalone and counterparty wallet reports.

**Data source:** `walletCheck.data.extra.exchangeName`

**Flag rule (fail-safe):**
- `exchangeName` non-null AND non-empty after trim → **has exchange = true**
- `null`, empty string, missing field, or missing `data.extra` → **has exchange = false**

**Render rule:**
- `has exchange = false` → render **nothing**: no table, no heading, no `—` placeholder.
- `has exchange = true` → render the table below, localized to the report language. The badge is the 🟢 emoji (renders natively, matching the `🟢 Low` risk-level convention in Basic Info).

**English report:**

```markdown
### Exchange Wallet Identifier

| Field | Detail |
|---|---|
| Exchange Wallet | 🟢 Identified |
| Exchange | **{exchangeName}** |
```

**中文报告:**

```markdown
### 钱包交易所标识

| 项目 | 详情 |
|---|---|
| 交易所钱包 | 🟢 已识别 |
| 交易所 | **{交易所名}** |
```

---

## Step ③: Wallet Security Report (5 sub-sections — all required)

⛔ **USD amount formatting (applies to every USD amount in this section — Wallet Balance, Total Incoming, Total Outgoing):** render the **full** number with thousands separators and two decimals, e.g. `$1,550,000.00 USD`. **Never** abbreviate to K / M / B (no `$1.55M`).

### Basic Info

| Field | Detail |
|---|---|
| Address | `walletCheck.data.address` |
| Network | `walletCheck.data.network` |
| Overall Risk Level | 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — from `walletCheck.data.level` |
| Identified Current Wallet Balance | `≈ $walletCheck.data.extra.walletBalance` USD |

> ⚠️ **Disclaimer:** We can help you assess whether the target address involves risky funds, but we cannot guarantee 100% accuracy. We will do our best to detect potential risk information. The results are for reference only and should not be relied upon as factual or legal basis for ensuring the absolute safety of a transaction. Users are obligated to comply not only with the facts but also with the regulatory policies, laws, and regulations of their respective countries or regions.

### Transaction Timeline

| Field | Detail |
|---|---|
| Earliest Transaction | `walletCheck.data.extra.earliestTransactionTime` |
| Latest Transaction | `walletCheck.data.extra.latestTransactionTime` |
| Total Incoming | `≈ $walletCheck.data.extra.totalIncoming` USD |
| Total Outgoing | `≈ $walletCheck.data.extra.totalOutgoing` USD |

Briefly comment on activity span and volume (long-standing vs newly created, notable volume?).

### Risk Exposure Breakdown

| Direction | Total | Low Risk | High Risk | High Risk % |
|---|---|---|---|---|
| Incoming | `$incomingRiskExposureBreakdown.totalAmount` USD | `$...lowRiskAmount` USD | `$...highRiskAmount` USD | `highRisk/total×100`% |
| Outgoing | `$outgoingRiskExposureBreakdown.totalAmount` USD | `$...lowRiskAmount` USD | `$...highRiskAmount` USD | `highRisk/total×100`% |

### High Risk Categories Associated

List all items in `walletCheck.data.extra.highRiskCategories` as plain text, e.g.: `Sanctions · Theft · Malware`
(Styled pill tags are in the widget — plain text only here.)

For each category present, add one sentence:
- **Sanctions**: Funds may be linked to entities under OFAC/EU/UN sanctions.
- **Theft**: Association with stolen funds or hack proceeds.
- **Malware**: Linked to ransomware or malware payment wallets.
- **Darknet**: Connected to darknet marketplace activity.
- **Scams**: Associated with phishing, fraud, or rug-pull operations.
- **High Risk Organisation**: Interaction with high-risk financial counterparties.
- **Coin Mixer**: Funds passed through mixing services to obscure trails.
- **Extortion**: Linked to extortion or blackmail payments.
- **Gambling**: Connected to unlicensed or high-risk gambling platforms.

If list empty: "✅ No high-risk categories detected."

---

## Step ④: Cross-Vendor Risk Comparison

⛔ **Render via a dedicated `show_widget` call — NEVER output as plain text.** HTML outside `show_widget` renders as raw code.

**How to build each table:**
1. Collect all unique `tagTypeVerbose` values across Vendor 1 + Vendor 2 + Vendor 3 for that direction → these become the rows
2. For each row × vendor cell:
   - Entry found AND `isHighRisk == true` → `<span style="color:#E53030;font-weight:bold">✓</span>`
   - Entry found AND `isHighRisk == false` → `<span style="color:#4CAF50">✗</span>`
   - Entry not found (this vendor has no data for this category) → `<span style="color:#999">—</span>`
3. All three vendors have no data for this direction → `<p>— No data from any vendor —</p>`

**Data field mapping (read from ALL THREE vendors for each table):**

| Table | Title | Vendor 1 | Vendor 2 | Vendor 3 |
|---|---|---|---|---|
| 1 | 📥 Direct Incoming | `walletCheck.data.extra.vendor1.directIncoming` | `walletCheck.data.extra.vendor2.directIncoming` | `walletCheck.data.extra.vendor3.directIncoming` |
| 2 | 📤 Direct Outgoing | `walletCheck.data.extra.vendor1.directOutgoing` | `walletCheck.data.extra.vendor2.directOutgoing` | `walletCheck.data.extra.vendor3.directOutgoing` |
| 3 | 📥 Indirect Incoming | `walletCheck.data.extra.vendor1.indirectIncoming` | `walletCheck.data.extra.vendor2.indirectIncoming` | `walletCheck.data.extra.vendor3.indirectIncoming` |
| 4 | 📤 Indirect Outgoing | `walletCheck.data.extra.vendor1.indirectOutgoing` | `walletCheck.data.extra.vendor2.indirectOutgoing` | `walletCheck.data.extra.vendor3.indirectOutgoing` |

⛔ All 4 table headers MUST use **Vendor 1 / Vendor 2 / Vendor 3** — never actual vendor names.

**show_widget payload — wrap all 4 tables:**

```html
<div style="width:100%; font-family:sans-serif">
  <div style="font-size:15px; font-weight:700; margin-bottom:16px">🔍 Cross-Vendor Risk Comparison</div>

  <!-- Table 1: Direct Incoming -->
  <div style="margin-bottom:24px">
    <div style="font-size:13px; font-weight:600; margin-bottom:6px">📥 Direct Incoming — Cross-Vendor Risk Flags</div>
    <table style="width:100%; border-collapse:collapse; font-size:13px">
      <thead>
        <tr style="background:#f0f0f0">
          <th style="padding:7px 10px; text-align:left; border:1px solid #ddd">Category</th>
          <th style="padding:7px 10px; text-align:center; border:1px solid #ddd">Vendor 1</th>
          <th style="padding:7px 10px; text-align:center; border:1px solid #ddd">Vendor 2</th>
          <th style="padding:7px 10px; text-align:center; border:1px solid #ddd">Vendor 3</th>
        </tr>
      </thead>
      <tbody>
        <!-- one <tr> per unique tagTypeVerbose -->
        <tr>
          <td style="padding:7px 10px; border:1px solid #ddd">{tagTypeVerbose}</td>
          <td style="padding:7px 10px; text-align:center; border:1px solid #ddd">{vendor1 cell}</td>
          <td style="padding:7px 10px; text-align:center; border:1px solid #ddd">{vendor2 cell}</td>
          <td style="padding:7px 10px; text-align:center; border:1px solid #ddd">{vendor3 cell}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Table 2: Direct Outgoing — identical <thead> (Category | Vendor 1 | Vendor 2 | Vendor 3), directOutgoing data -->
  <!-- Table 3: Indirect Incoming — identical <thead> (Category | Vendor 1 | Vendor 2 | Vendor 3), indirectIncoming data -->
  <!-- Table 4: Indirect Outgoing — identical <thead> (Category | Vendor 1 | Vendor 2 | Vendor 3), indirectOutgoing data -->
</div>
```

---

## Step ⑤: Comprehensive Summary (4–6 sentences)

⛔ Do NOT name any specific vendor. Replace with: "multiple vendors", "cross-vendor consensus", "all vendors confirmed", etc.

1. Overall risk verdict — is this wallet safe to interact with?
2. What the risk level means practically
3. Key concerns (specific categories, exposure amounts, counterparty patterns)
4. Whether transaction history suggests legitimate or suspicious usage
5. Clear actionable recommendation: freely interact / proceed with caution / avoid / report
