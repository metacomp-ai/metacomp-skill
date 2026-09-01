# Wallet Report — Content Specifications

⛔ **Rendering: everything in this file is Markdown.** Only the Step ② dashboard is a widget (see
`visualization.md`); ②.5, ③, ④ and ⑤ are ordinary Markdown tables and prose, emitted after the three
dashboard `show_widget` calls. Do not wrap them in widgets and do not hand-write HTML for them.

⚠ **Table language:** every table template in this file is an English **structural spec**, not a verbatim
string. In a non-English turn, translate all headers, field names, labels, and badges — the 中文报告
example under Exchange Wallet Identifier shows the treatment, and it applies to EVERY table in this file
(Basic Info, Transaction Timeline, Risk Exposure Breakdown, Cross-Vendor Risk Comparison included).
Proper names (entity/exchange names) stay verbatim; category names are localized per the canonical
table — full rule: `SKILL.md` → Language.

---

## Step ①: Analysis Preface Content

**Before writing anything — answer this question:**
Did this response include a transaction screening (i.e. `VisionX` called with `transactionDetails`)?

- **YES** → ⛔ This is a counterparty wallet. Skip Step ① entirely. No preface, no heading, no blockquote. Go directly to Step ②.
- **NO** → This is a standalone wallet check. Proceed to write the preface below.

---

Render as a `>` blockquote opening with 🔬. Write fresh in the user's language.
Two separate paragraphs — do NOT merge them. Do NOT include methodology (Layer 1/Layer 2/taint) — that is transaction-report only.

**Format constraints — all three mandatory:**

1. The whole preface is **one single `>` blockquote**. Separate the two paragraphs with a bare `>` line
   inside it. ❌ Do not emit un-quoted plain paragraphs, and do not split it into two blockquotes.
2. The first line is exactly `> 🔬 **Analysis Preface**`. When writing in another language, translate
   only the words "Analysis Preface" — never rename the label (no "Analysis Basis", no "Research Basis").
3. The preface comes **before** Step ②'s `## 🔐 Wallet Security Report` section header. ❌ Never emit
   the section header first.

### Paragraph 1 — Data Sources
Reference **six independent, industry-leading blockchain-security & compliance vendors** — but ❌ NEVER print any real vendor name. Refer to them only generically ("six leading vendors", "multiple independent vendors") or as **Vendor 1–Vendor 6**.
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

> Render as a **native Markdown table**, after the dashboard widgets (D3) and before Step ③. Applies to **both** standalone and counterparty wallet reports.

**Data source:** `walletCheck.data.extra.exchangeName`

**Flag rule (fail-safe):**
- `exchangeName` non-null AND non-empty after trim → **has exchange = true**
- `null`, empty string, missing field, or missing `data.extra` → **has exchange = false**

**Render rule:**
- `has exchange = false` → render **nothing**: no table, no heading, no `—` placeholder.
- `has exchange = true` → render the table below, localized to the report language.

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

## Step ③: Wallet Security Report — Markdown (4 sub-sections — all required)

Heading `### Wallet Security Report`, then the four sub-sections in order, each with its own `####`
heading and a native Markdown table.

⛔ **USD amount formatting (applies to every USD amount in this section — Wallet Balance, Total Incoming, Total Outgoing):** render the **full** number with thousands separators and two decimals, e.g. `$1,550,000.00 USD`. **Never** abbreviate to K / M / B (no `$1.55M`).

### Basic Info

| Field | Detail |
|---|---|
| Address | `walletCheck.data.address` |
| Network | `walletCheck.data.network` |
| Overall Risk Level | one of the four badges below, mapped from `walletCheck.data.level` |
| Identified Current Wallet Balance | `≈ $walletCheck.data.extra.walletBalance` USD |

**`level` → badge mapping** (the server's vocabulary is wider than the four badges, so always map):

| `walletCheck.data.level` | Render as |
|---|---|
| `Low` | 🟢 Low |
| `Medium` | 🟡 Medium |
| `Medium-High` / `MediumHigh` | 🟠 Medium-High |
| `High` / `Severe` / `Critical` | 🔴 High |

⛔ Output the mapped badge only. ❌ Never print the raw `level` string (e.g. `Severe`) and never
concatenate the two (no `🔴 High (Severe)`). This holds everywhere the level appears — Metric Summary,
Basic Info, Comprehensive Summary prose, and the Step ⑦ Risk Verdict card.

Render the disclaimer directly under the Basic Info table as a Markdown blockquote. Its meaning is
fixed — never soften, shorten, or extend it — but it is rendered **in the turn's language**. English
turns use exactly:

> ⚠️ **Disclaimer:** We can help you assess whether the target address involves risky funds, but we cannot guarantee 100% accuracy. We will do our best to detect potential risk information. The results are for reference only and should not be relied upon as factual or legal basis for ensuring the absolute safety of a transaction. Users are obligated to comply not only with the facts but also with the regulatory policies, laws, and regulations of their respective countries or regions.

Chinese turns use exactly:

> ⚠️ **免责声明：** 我们可以帮助您评估目标地址是否涉及风险资金，但无法保证 100% 准确。我们将尽最大努力检测潜在的风险信息。检测结果仅供参考，不应作为确保交易绝对安全的事实依据或法律依据。用户不仅有义务遵循事实，还应遵守其所在国家或地区的监管政策与法律法规。

Other languages: translate the English text faithfully.

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

⛔ **High Risk % — compute it, then sanity-check the magnitude.** This column is the single most
error-prone number in the report: the ratio is typically far below 1%, and writing it 100× or 1000× too
large turns a negligible share into an alarming one.

- Formula: `highRiskAmount ÷ totalAmount × 100`. The `× 100` is **required** — a bare ratio of
  `0.0000082` must render as `0.00082%`, never as `0.82%`.
- Precision: keep **two significant digits**, not two decimal places — e.g. `0.00082%`, `0.0000000026%`,
  `1.3%`. Rounding a nonzero share to `0.00%` hides it; do not do that.
- **Magnitude check before you write it:** the rendered percent, divided by 100 and multiplied back by
  `totalAmount`, must land within a few percent of `highRiskAmount`. If it lands 100× or 1000× off, you
  dropped or duplicated the `× 100` — recompute.
- Whatever percent you write here must be the **same** percent used anywhere else in the response
  (exposure summary lines, Comprehensive Summary prose, Risk Verdict card). Never restate it with a
  different magnitude.

### High Risk Categories Associated

List all items in `walletCheck.data.extra.highRiskCategories` as plain text on one line, localized —
English: `Sanctions · Theft · Malware`; 中文: `制裁 · 盗窃 · 恶意软件`

Then a Markdown bullet per category — bold category name, colon, then the sentence:

```markdown
- **Sanctions**: Funds may be linked to entities under OFAC/EU/UN sanctions.
```

For each category present, use exactly this sentence — in a non-English turn translate it faithfully,
with the bold **localized** category name only (⛔ no English original in parentheses), e.g.
`**诈骗**：与钓鱼、欺诈或卷款跑路（rug-pull）操作相关。`:
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

## Step ④: Cross-Vendor Risk Comparison — Markdown

✅ **Render as native Markdown tables — 4 tables, no widget, no HTML.** Heading
`### 🔍 Cross-Vendor Risk Comparison`, then the four sub-tables.

**How to build each table:**
1. Collect all unique `tagTypeVerbose` values across Vendor 1 + Vendor 2 + Vendor 3 for that direction → these become the rows
2. For each row × vendor cell:
   - Entry found AND `isHighRisk == true` → `✓` (high risk confirmed)
   - Entry found AND `isHighRisk == false` → `✗` (low risk)
   - Entry not found (this vendor has no data for this category) → `—`
3. All three vendors have no data for this direction → write: *— No data from any vendor —*
4. **A vendor whose array for this direction is empty (length 0) → that vendor's ENTIRE column is `—`,
   on every row.** ⛔ An empty array is not low risk, and it is certainly not high risk. Never infer a
   cell from what the other vendors reported: a `✓` in a column backed by no data invents a confirmed
   finding out of nothing.

**Data field mapping (read from ALL THREE vendors for each table):**

| Table | Title | Vendor 1 | Vendor 2 | Vendor 3 |
|---|---|---|---|---|
| 1 | 📥 Direct Incoming | `walletCheck.data.extra.vendor1.directIncoming` | `walletCheck.data.extra.vendor2.directIncoming` | `walletCheck.data.extra.vendor3.directIncoming` |
| 2 | 📤 Direct Outgoing | `walletCheck.data.extra.vendor1.directOutgoing` | `walletCheck.data.extra.vendor2.directOutgoing` | `walletCheck.data.extra.vendor3.directOutgoing` |
| 3 | 📥 Indirect Incoming | `walletCheck.data.extra.vendor1.indirectIncoming` | `walletCheck.data.extra.vendor2.indirectIncoming` | `walletCheck.data.extra.vendor3.indirectIncoming` |
| 4 | 📤 Indirect Outgoing | `walletCheck.data.extra.vendor1.indirectOutgoing` | `walletCheck.data.extra.vendor2.indirectOutgoing` | `walletCheck.data.extra.vendor3.indirectOutgoing` |

⛔ All 4 table headers MUST use **Vendor 1 / Vendor 2 / Vendor 3** — never actual vendor names.

**Markdown template (repeat for each of the 4 directions):**

```markdown
#### 📥 Direct Incoming — Cross-Vendor Risk Flags

| Category | Vendor 1 | Vendor 2 | Vendor 3 |
|---|:---:|:---:|:---:|
| {tagTypeVerbose} | ✓ / ✗ / — | ✓ / ✗ / — | ✓ / ✗ / — |
```

Direction headings: `📥 Direct Incoming` → `📤 Direct Outgoing` → `📥 Indirect Incoming` →
`📤 Indirect Outgoing`, each suffixed `— Cross-Vendor Risk Flags`.

When all three vendors have no data for a direction, replace that table with the italic line
*— No data from any vendor —*.

---

## Step ④.5: Vendor Alert Flags — Markdown (1 table, immediately after Step ④)

The overall `level` can be **alert-driven** rather than amount-driven: vendors raise wallet-level alert
flags even when every exposure row is low-risk. This table is what backs the rating in that case —
without it a High verdict over all-zero exposure tables reads as a contradiction.

**Source — one `platformWalletAlert` object per screening source, fixed anonymous numbering:**

| Column | Source object |
|---|---|
| Vendor 1 | `walletCheck.data.extra.vendor1.platformWalletAlert` |
| Vendor 2 | `walletCheck.data.extra.vendor2.platformWalletAlert` |
| Vendor 3 | `walletCheck.data.extra.vendor3.platformWalletAlert` |
| Vendor 4 | `walletCheck.data.extra.chainalysis.platformWalletAlert` |

Vendor 4 is the fourth screening source — it carries alert flags only and has no column in the Step ④
exposure tables; the numbering above is fixed so the anonymous labels stay stable within the response.
⛔ The `platform` string inside these objects is a REAL vendor name — never print it (Vendor
confidentiality rule).

Heading `#### 🚨 Vendor Alert Flags`（中文 `#### 🚨 厂商告警标记`）, then one table:

```markdown
| Alert | Vendor 1 | Vendor 2 | Vendor 3 | Vendor 4 |
|---|:---:|:---:|:---:|:---:|
| Wallet alert | — | — | ⚠️ Yes | ⚠️ Yes |
| Direct-exposure alert | — | — | — | ⚠️ Yes |
| Severe direct alert | — | — | — | — |
| Cumulative/prohibited exposure over threshold | — | ⚠️ Yes | — | — |
```

Row → field mapping (all four rows always rendered, in this order): Wallet alert = `hasAlert` ·
Direct-exposure alert = `hasDirectAlert` · Severe direct alert = `hasSevereDirectAlert` ·
Cumulative/prohibited exposure over threshold = `cumulativeOrProhibitedMoreThanThreshold`.
中文行名：`钱包告警` · `直接暴露告警` · `严重直接告警` · `累计/禁止交易对手超阈值`。

Cell mapping: `true` → `⚠️ Yes`（中文 `⚠️ 有`）· `false` → `✗ No`（`✗ 无`）· `null` or missing → `—`
(no data — ⛔ never infer a cell from the other vendors). A missing `platformWalletAlert` object → that
entire column is `—`. If EVERY cell of the table would be `—`, replace the whole table with the italic
line *— No alert data from any vendor —*（`*— 无厂商告警数据 —*`）.

---

## Step ⑤: Comprehensive Summary (4–6 sentences) — Markdown prose

Heading `### Comprehensive Summary`, then continuous prose. ⛔ Do not restate the dashboard's tables or
donut legends here.

⛔ Do NOT name any specific vendor. Replace with: "multiple vendors", "cross-vendor consensus", "all vendors confirmed", etc.

**Format:** continuous prose, **4–6 sentences, hard limit**. ❌ No numbered list, no bullets, no
sub-headings. ⛔ The word "Recommendation" must NOT appear in this section — the action recommendation
is rendered exactly once, in the Step ⑦ Risk Verdict card.

The points below are the **content to weave into those sentences**, not a list to render:

- Overall risk verdict — is this wallet safe to interact with?
- What the risk level means practically
- **If the rating is alert-driven** — level High/Medium while `highRiskAmount` is 0 and no exposure row
  is high-risk — say so explicitly, citing the Step ④.5 flags ("the rating is driven by wallet alerts
  raised by multiple vendors, not by exposure amounts"). Never leave a high rating over all-zero
  exposure unexplained.
- Key concerns (specific categories, exposure amounts, counterparty patterns)
- Whether transaction history suggests legitimate or suspicious usage
- Where the verdict leaves the user (state it as part of the prose — the actionable
  freely interact / proceed with caution / avoid / report line belongs to Step ⑦, not here)
