# Wallet Report — Step ⑥: Exposure Detail Tables

> ⚠️ **These are NOT the same as the High-Risk Exposure Tables in the D1 dashboard widget.** Those (in `visualization.md`) show only `isHighRisk=true` entries with 9 fixed rows. These tables show **ALL entries** (both high-risk and low-risk) with a Ratio and a Risk column — a different surface, so rendering both is not a duplicate.

⛔ **Rendering: native Markdown, four tables, after the Comprehensive Summary (Step ⑤).** No widget, no
HTML. Each table is followed by its high-risk notes (see the bottom of this file).

| Order | Heading | Data array |
|---|---|---|
| 1 | `📥 Direct Incoming Exposure` | `walletCheck.data.extra.directIncoming` |
| 2 | `📥 Indirect Incoming Exposure` | `walletCheck.data.extra.indirectIncoming` |
| 3 | `📤 Direct Outgoing Exposure` | `walletCheck.data.extra.directOutgoing` |
| 4 | `📤 Indirect Outgoing Exposure` | `walletCheck.data.extra.indirectOutgoing` |

Render the four tables **after the Comprehensive Summary (Step ⑤)**, in the order above.
Include **every entry** — never skip $0 rows, never merge small categories into an "Other" row.
If an array is empty, still render the table with a placeholder row.

⛔ **Data-source exclusivity:** read only `walletCheck.data.extra.directIncoming` / `indirectIncoming` /
`directOutgoing` / `indirectOutgoing`. ❌ NEVER read `data.extra.chainalysis.*`,
`data.extra.vendor1/2/3.*`, or any other same-named sub-object — those are single-vendor subsets and
will yield both wrong amounts and wrong row counts.

☐ **Row-count self-check — run after rendering each table:** the number of data rows MUST equal the
number of elements in that table's source array. If it does not, find the dropped entry and add it
before ending the response. Dropping a row whose `isHighRisk` is `true` is a severe error: every
high-risk category that appears anywhere in Step ② must also appear here.

> ❌ **CRITICAL: standalone Markdown tables — absolutely NO HTML (`<span>`, `<div>`, `style=`, etc.). Plain text and emoji only.**

⚠ **Language:** in a non-English turn, localize the headers, the Risk badges, the empty-state lines,
AND the `tagTypeVerbose` category values — localized name only, per `SKILL.md` → Language —
中文: `| 类别 | 金额 (USD) | 占比 | 风险 |`, `| 诈骗 | ≈ $32,847,510.01 | 13.12% | ⚠️ 高风险 |`,
`— 无直接流入敞口记录 —`. Only amounts, currency codes, and proper names stay verbatim.

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

**High-risk notes — after each table, not pooled at the end.**

Immediately below a table, add one `⚠️` line per ⚠️ High Risk row in **that** table, naming the category
and its hop, and stating what it means in practice. Quote the amount:

```markdown
⚠️ **Scams (Direct Outgoing):** Over $324,878 was sent directly to scam-flagged wallets — the most
severe signal in this report, indicating the wallet actively routes funds to fraudulent operations.
```

Tables with no high-risk rows get no note. If any indirect exposure exists, add one sentence — once,
after the first indirect table — explaining how indirect differs from direct exposure.
