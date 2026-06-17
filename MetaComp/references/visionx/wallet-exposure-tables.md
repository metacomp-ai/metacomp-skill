# Wallet Report — Step ⑥: Exposure Detail Tables

> ⚠️ **These are NOT the same as the High-Risk Category Summary Tables inside the widget.** Those (in `visualization.md`) show only `isHighRisk=true` entries with 9 fixed rows. These tables show **ALL entries** (both high-risk and low-risk) with a Risk column, rendered as **standalone markdown — rendered after Comprehensive Summary (Step ⑤)**.

Render four tables **after the Comprehensive Summary (Step ⑤)**. Include **every entry** — never skip $0 rows.
If an array is empty, still render the table with a placeholder row.

> ❌ **CRITICAL: These are standalone markdown tables — absolutely NO HTML (`<span>`, `<div>`, `style=`, etc.). Plain text and emoji only.**

---

**📥 Direct Incoming Exposure** (`walletCheck.data.extra.directIncoming`)

| Category | Amount (USD) | Ratio | Risk |
|---|---|---|---|
| `tagTypeVerbose` | `≈ $totalValueUsd` | `ratio > 0 ? ratio% : "< 0.01%"` | ⚠️ High Risk / ✅ Low Risk |

If empty: `— No direct incoming exposure recorded —`

---

**📥 Indirect Incoming Exposure** (`walletCheck.data.extra.indirectIncoming`)

| Category | Amount (USD) | Ratio | Risk |
|---|---|---|---|
| `tagTypeVerbose` | `≈ $totalValueUsd` | `ratio > 0 ? ratio% : "< 0.01%"` | ⚠️ High Risk / ✅ Low Risk |

If empty: `— No indirect incoming exposure recorded —`

---

**📤 Direct Outgoing Exposure** (`walletCheck.data.extra.directOutgoing`)

| Category | Amount (USD) | Ratio | Risk |
|---|---|---|---|
| `tagTypeVerbose` | `≈ $totalValueUsd` | `ratio > 0 ? ratio% : "< 0.01%"` | ⚠️ High Risk / ✅ Low Risk |

If empty: `— No direct outgoing exposure recorded —`

---

**📤 Indirect Outgoing Exposure** (`walletCheck.data.extra.indirectOutgoing`)

| Category | Amount (USD) | Ratio | Risk |
|---|---|---|---|
| `tagTypeVerbose` | `≈ $totalValueUsd` | `ratio > 0 ? ratio% : "< 0.01%"` | ⚠️ High Risk / ✅ Low Risk |

If empty: `— No indirect outgoing exposure recorded —`

---

For any ⚠️ High Risk row across all four tables, add one sentence explaining that category's implications.
If any indirect exposure exists, briefly explain the difference between direct and indirect exposure.
