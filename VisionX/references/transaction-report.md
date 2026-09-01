# Transaction Report — Content Specifications

⛔ **Rendering: everything in this file is Markdown** — no widget, no HTML. The wallet report's Step ②
dashboard is the only widget surface in this skill.

When a counterparty wallet report follows (VisionX called with `transactionDetails`), the whole
transaction report comes first, then the wallet report's section header + its three dashboard widgets —
and the wallet report skips its own preface.

---

## Step ①: Analysis Preface Content

Render as a `>` blockquote opening with 🔬. Write fresh each time in the user's language.
Three separate paragraphs — do NOT merge them.

### Paragraph 1 — Data Sources
Reference **six independent, industry-leading blockchain-security & compliance vendors** — but ❌ NEVER print any real vendor name. Refer to them only generically ("six leading vendors", "multiple independent vendors") or as **Vendor 1–Vendor 6**.
Explain that cross-verifying across multiple vendors eliminates individual blind spots. (1–2 sentences)

### Paragraph 2 — Methodology
Write a paragraph modeled on this example — adapt language and risk details to the current case, do NOT copy verbatim:

> "The analysis operates on two distinct layers. Layer 1 checks directly whether this transaction has contact with known flagged addresses — any direct link to a sanctioned entity, mixer, or darknet wallet is flagged immediately. Layer 2 traces all associated fund flows forward and backward through unlimited on-chain hops, identifying indirect taint even when funds pass through many intermediary wallets before reaching a flagged entity. At each hop depth, taint ratios are calculated and aggregated into a cumulative risk score. The final risk rating reflects both layers combined — not just direct exposure."

⛔ Do NOT use the word "threshold" or mention any specific threshold values anywhere in the output.

Adapt the framing to the result:
- High risk / multiple categories → emphasize that both layers triggered
- Low risk → explain why both layers returned clean
- Tron → mention Tron carries ~10× higher sanctions exposure than Ethereum

### Paragraph 3 — Research Basis
Cite at least one figure from: MetaComp Research, "Relative Effectiveness of On-Chain AML/CFT Know-Your-Transaction (KYT) Tools" (July 2025), 7,000 sampled transactions. Always attribute to "MetaComp Research (July 2025)".

Key findings (pick the most relevant):
- 1 vendor alone: false-clean rate up to 25%
- 2 vendors: false-clean rate 7–22%
- 3+ vendors: false-clean rate below 0.25% — the standard this report meets
- Tron: ~10× higher sanctions exposure than Ethereum (6.95% vs 0.70% severe risk)
- 20%+ of sampled Tron transactions rated medium-high risk or above

Connect the figure to this specific case — never cite numbers in isolation.

---

## Step ③: Transaction Security Report — Markdown

⚠ **Table language:** the templates below are English structural specs. In a non-English turn, translate
every field name and label (Date/Direction/Asset… → 日期/方向/资产…), the risk badges, the
Interpretation wording, and risk-category names (canonical table in `SKILL.md` → Language); amounts,
hashes, addresses, and proper names stay verbatim.

**If `transactionCheck.data.extra.selectedTx` is null or empty:**
Show: "Transaction details were not returned. Overall risk level: `transactionCheck.data.level`."

**For each entry in `transactionCheck.data.extra.selectedTx`:**

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
| Risk Level | 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — from `txRiskLevel` |
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

---

## Error Handling

Triage the failure first — see `SKILL.md` → **Screening Call Failure — Triage**. Never default to the
Authorization Guide.

- `transactionCheck.success === false` / `code !== 0`, empty result, or timeout → **Case B**: Data
  Unavailable notice. Do not mention keys or authorization.
- Explicit `401` / `403` / invalid key / expired token → **Case A**: Authorization Guide.
- Unsupported network → only Bitcoin, Ethereum, Tron supported.
