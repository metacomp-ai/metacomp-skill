# Wallet Report — Step ⑦: 🚨 Risk Conclusion Card

Render a prominent risk verdict **immediately after the Exposure Detail Tables (Step ⑥)** as a native
Markdown blockquote — the last thing in the response.

- ✅ Output as plain Markdown — no widget, no HTML
- ❌ Do NOT skip this step or omit the recommendation line
- The response is **incomplete** until this blockquote appears

**Content:**
- Risk level badge: 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — use the badge mapped in
  `wallet-report.md` → Basic Info; never print the raw `level` string (e.g. `Severe`)
- 1–2 sentences: key risk verdict summarizing the most important finding. **Alert-driven case:** when
  the level is High/Medium while `highRiskAmount` is 0 and no exposure row is high-risk, the verdict
  sentence MUST attribute the rating to the vendor alert flags (Step ④.5) — e.g. "多家厂商对该钱包
  触发告警，评级由告警驱动，敞口金额均为低风险" — never a high verdict over all-zero exposure with
  no stated basis
- One clear action recommendation: freely interact / proceed with caution / avoid / report
  — this is the **only** place the recommendation appears in the whole report (Step ⑤ must not carry one)

---

⚠ **Language:** in a non-English turn, localize the ENTIRE card — the `Risk Verdict` heading, the badge
word, the verdict sentences, the `Recommendation` label, and the recommended action itself
(中文: `> ### 🚨 风险结论 — 🔴 高风险` … `⚡ **操作建议：** 避免交易 — …`). The English examples below are
models to translate, never verbatim strings (see `SKILL.md` → Language).

## Markdown Template

```markdown
---

> ### 🚨 Risk Verdict — {risk emoji} {Risk Level}
> {1–2 sentence verdict summarizing the key finding.}
>
> ⚡ **Recommendation:** {freely interact / proceed with caution / avoid / report to compliance}
```

**Examples by risk level:**

🔴 High:
```markdown
---

> ### 🚨 Risk Verdict — 🔴 High Risk
> Multiple vendors flagged direct exposure to sanctioned entities and theft-linked funds, representing a significant portion of total incoming flows.
>
> ⚡ **Recommendation:** Avoid — do not transact with this address and report to your compliance team.
```

🟡 Medium:
```markdown
---

> ### 🚨 Risk Verdict — 🟡 Medium Risk
> Indirect exposure to high-risk counterparties was detected, though no direct sanctions or theft links were confirmed.
>
> ⚡ **Recommendation:** Proceed with caution — apply enhanced due diligence before transacting.
```

🟢 Low:
```markdown
---

> ### 🚨 Risk Verdict — 🟢 Low Risk
> Cross-vendor consensus confirms no material risk exposure for this address across both direct and indirect fund flows.
>
> ⚡ **Recommendation:** Freely interact — no restrictions identified at this time.
```
