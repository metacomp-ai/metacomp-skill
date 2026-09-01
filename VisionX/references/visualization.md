# Visualization — Dashboard Widget Specification

---

## Scope: this file covers the dashboard ONLY

The **Wallet Security Dashboard (Step ②)** is the report's only widget surface. It is rendered as
**three `show_widget` calls**, back to back, with no text between them:

| Call | Contents | Measured |
|---|---|---|
| **D1** | 6 metric cards (two rows) + the 4 high-risk exposure tables in a 2×2 grid | ≈ 6 KB |
| **D2** | Incoming Exposure donut + legend | ≈ 8.9 KB |
| **D3** | Outgoing Exposure donut + legend | ≈ 8.9 KB |

Sizes measured on a busy wallet (36 legend entries per direction). The same content as one call
measures ~21 KB and would break the 12 KB ceiling — hence the fixed three-way split. Always emit all
three, even for a small wallet that would have fitted in fewer: a fixed split needs no size guessing.

⛔ **Everything else in the report is Markdown** — preface, Wallet Security Report, Cross-Vendor tables,
Comprehensive Summary, Exposure Detail Tables, Risk Verdict card. Do not wrap those in widgets, and do
not hand-write HTML for them in your message text (it would show as escaped source).

⚠ **Language:** every human-readable string inside D1/D2/D3 HTML — card labels (`Overall Risk` →
`综合风险`), table headers, donut titles, badges, the `(Direct)`/`(Indirect)` hop labels（直接/间接）—
follows the turn's dominant language. Category names, the fixed nine rows included, use the display
format from `SKILL.md` → Language: English turn `Gambling`; 中文轮次 `赌博` — localized name only,
no English in parentheses. Only amounts, currency codes, and proper names (entity/exchange names)
stay verbatim.

---

## Shared skeleton — D1 / D2 / D3 all use this shape

```html
<div>                                        <!-- plain, unstyled: the host strips
                                                  border/background/padding/margin from the
                                                  outermost element with !important, so nothing
                                                  visual may live here -->
  <style>…the class block below…</style>
  …cards, tables and charts, all nested inside this outer div…
</div>
```

The iframe already supplies the font stack, `13px`/`1.65`, colour `#161614`, a transparent background
and complete `table` / `th` / `td` styling. **Do not restate any of it.**

**Class block — paste into each of D1 / D2 / D3, then use the classes:**

```html
<style>.n{text-align:right;font-variant-numeric:tabular-nums}
.sw{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:5px}
.g{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
.t{font-size:11px;font-weight:600;margin:0 0 6px}
.x th{font-size:10px;background:#3d3d3a;color:#fff}.x td,.x th{padding:5px 8px}
.hot{color:#CC1111;font-weight:600}
.card{flex:1 1 150px;border:1px solid #e4e2da;border-radius:10px;padding:10px 12px}
.lbl{font-size:10px;text-transform:uppercase;letter-spacing:.04em;color:#75726a;margin-bottom:4px}
.pie{width:160px;height:160px;border-radius:50%;flex-shrink:0;-webkit-mask:radial-gradient(circle,transparent 54%,#000 55%);mask:radial-gradient(circle,transparent 54%,#000 55%)}
.row{display:flex;gap:18px;align-items:center;flex-wrap:wrap;margin:16px 0}
.lg{flex:1;min-width:230px;font-size:11px}.lg td{padding:2px 6px;border:none}</style>
```

⛔ The classes are not optional. Repeating `style="text-align:right;font-variant-numeric:tabular-nums"`
on every numeric cell roughly doubles the byte count and breaks the ceiling. A `<style>` element is
exempt from the outer-element stripping, so it is safe as a direct child.

---

## Section header — Markdown, before D1

Not part of any widget. Emit as ordinary Markdown immediately before the first `show_widget` call:

```markdown
## 🔐 Wallet Security Report
*MetaComp VisionX*
```

Counterparty wallet (VisionX called with `transactionDetails`): `## 🔎 Counterparty Wallet Analysis`.

---

## D1 — metric cards

Six cards in two flex rows — always all six, a zero value renders as `$0.00 (0%)`, never an omitted card.

**Row 1 — four cards, in this order:**

| Card (中文) | Value |
|---|---|
| Overall Risk（综合风险） | the mapped badge, e.g. `🔴 High` — coloured by level |
| Wallet Balance（钱包余额） | `$walletCheck.data.extra.walletBalance` |
| Total Incoming（总流入） | `$walletCheck.data.extra.totalIncoming` |
| Total Outgoing（总流出） | `$walletCheck.data.extra.totalOutgoing` |

**Row 2 — two high-risk cards:**

| Card (中文) | Value |
|---|---|
| High Risk Incoming（高风险流入） | `$incomingRiskExposureBreakdown.highRiskAmount`, then the share in parentheses: `highRiskAmount ÷ totalAmount × 100` — two decimals when the amount is nonzero; a zero amount (or zero total) renders exactly `$0.00 (0%)` |
| High Risk Outgoing（高风险流出） | same, from `outgoingRiskExposureBreakdown` |

High-risk card amount colour: red `#CC1111` when the amount is > 0; default text colour when it is 0.

```html
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px">
  <div class=card><div class=lbl>Overall Risk</div>
    <div style="font-size:16px;font-weight:600"><span style="color:#E53030">🔴 High</span></div></div>
  <div class=card><div class=lbl>Wallet Balance</div>
    <div class=n style="font-size:16px;font-weight:600;text-align:left">$250.00</div></div>
  …Total Incoming… …Total Outgoing…
</div>
<div style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px">
  <div class=card><div class=lbl>High Risk Incoming</div>
    <div class=n style="font-size:16px;font-weight:600;text-align:left;color:#CC1111">$516,912.01 (24.88%)</div></div>
  <div class=card><div class=lbl>High Risk Outgoing</div>
    <div class=n style="font-size:16px;font-weight:600;text-align:left">$0.00 (0%)</div></div>
</div>
```

⛔ **Copy the two amounts digit by digit from their named fields.** `totalIncoming` and `totalOutgoing`
are distinct fields — if they come out equal you copied one twice. They reappear in the Step ③
Transaction Timeline table and must match there character for character.

Level → badge colour: 🔴 High `#E53030` · 🟠 Medium-High `#FF9900` · 🟡 Medium `#C8A400` ·
🟢 Low `#7D8B00`. Map `walletCheck.data.level` per `wallet-report.md` → Basic Info; never print the raw
level string.

---

## D1 — the four High Risk Exposure tables (2×2 grid)

All four appear, inside `<div class=g>` so they lay out two-up on a wide screen and stack on a narrow
one. Fixed 9-row order in every table.

**Grid order:** Incoming Direct → Incoming Indirect → Outgoing Direct → Outgoing Indirect

**Fixed row order (9 rows, always all nine):**
Sanctions → High Risk Organisation → Theft → Malware → Scams → Extortion → Coin Mixer → Darknet → Gambling
（中文轮次，同一顺序、纯中文：制裁 → 高风险机构 → 盗窃 → 恶意软件 → 诈骗 → 勒索 → 混币器 → 暗网 → 赌博）

**Data source per table:**

| Table | Title | Data array | % header |
|---|---|---|---|
| 1 | `Incoming` Direct Exposure to High Risk Sources | `walletCheck.data.extra.directIncoming` (isHighRisk=true) | High-Risk % of Total Received |
| 2 | `Incoming` Indirect Exposure to High Risk Sources | `walletCheck.data.extra.indirectIncoming` (isHighRisk=true) | High-Risk % of Total Received |
| 3 | `Outgoing` Direct Exposure to High Risk Sources | `walletCheck.data.extra.directOutgoing` (isHighRisk=true) | High-Risk % of Total Sent |
| 4 | `Outgoing` Indirect Exposure to High Risk Sources | `walletCheck.data.extra.indirectOutgoing` (isHighRisk=true) | High-Risk % of Total Sent |

Canonical 中文 strings (Chinese turns use these exact words — table titles: `流入 — 直接高风险来源敞口` /
`流入 — 间接高风险来源敞口` / `流出 — 直接高风险来源敞口` / `流出 — 间接高风险来源敞口`; headers:
`高风险来源` / `金额 (USD)` / `高风险占总流入 %` / `高风险占总流出 %`; D2/D3 donut titles: `流入敞口` /
`流出敞口`).

In each title, the direction word is coloured — `Incoming` green `#3f7d3f`, `Outgoing` red `#CC1111` —
and the rest of the title stays default.

⛔ **Data-source exclusivity — the four arrays above are the ONLY permitted source.**
`walletCheck.data.extra` also carries same-named sub-objects that are **single-vendor subsets**, not
the aggregate result. Reading one of those silently understates risk by one to two orders of magnitude
while the verdict still reads "High", so the error is invisible unless the amounts are checked.

- ❌ NEVER read `data.extra.chainalysis.*`, `data.extra.vendor1/2/3.*`,
  `data.extra.incomingDirectExposure`, `data.extra.outgoingDirectExposure`, or anything whose path is
  not exactly one of the four above.
- ✅ Read only `data.extra.directIncoming` / `indirectIncoming` / `directOutgoing` / `indirectOutgoing`.
- **Self-check:** if the Incoming-Direct and Outgoing-Direct tables came out with identical amounts on
  every row, you read a single-vendor sub-object. Go back and rebuild both.

**Row rendering:**
- Category absent from the array, or `totalValueUsd` is 0 → amount `0`, percent `0`, default colour.
- Category present with a nonzero amount → **the whole row is red** (`class=hot`): it is the finding the
  reader is looking for. Amount `≈ {totalValueUsd}` with comma separators and two decimals; percent
  `{totalValueUsdRatio} %`, or `0` when the ratio itself is 0.

```html
<div class=g>
  <div>
    <div class=t><span style="color:#3f7d3f">Incoming</span> Direct Exposure to High Risk Sources</div>
    <table class=x>
      <tr><th>High Risk Sources</th><th class=n>Amount (USD)</th><th class=n>High-Risk % of Total Received</th></tr>
      <tr><td>Sanctions</td><td class=n>0</td><td class=n>0</td></tr>
      <tr class=hot><td>Scams</td><td class=n>≈ 115.05</td><td class=n>0.01 %</td></tr>
      …all nine rows, fixed order…
    </table>
  </div>
  …three more table blocks…
</div>
```

⛔ Never re-sort these rows by amount, never drop a zero row, and never merge categories into an
"Other (…)" row. The fixed nine-row shape is what lets a reader compare the four tables side by side.

---

## D2 / D3 — the two exposure donuts

One donut per direction: **D2 = Incoming Exposure, D3 = Outgoing Exposure.** Each merges that
direction's direct and indirect arrays, keeps them distinguishable by labelling every entry with its
hop, and **includes low-risk categories** — the olive-vs-red contrast is the point of the chart.

Construction, colours and legend rules: `chart-spec.md` → Donut charts.

```html
<div class=t style="font-size:12px">Incoming Exposure</div>
<div class=row>
  <div class=pie style="background:conic-gradient(#7D8B00 0.00% 28.19%,#5A6200 28.19% 49.17%,…)"></div>
  <table class=lg>
    <tr><td><span class=sw style="background:#7D8B00"></span>Exchange (Direct)<br>
            <span style="color:#75726a">≈ $436,285.00</span></td>
        <td class=n style="font-weight:600">28.19%</td></tr>
    …one row per entry…
  </table>
</div>
```

⛔ D2 and D3 are separate `show_widget` calls. Putting both donuts in one call reaches ~16.7 KB on a
busy wallet and breaks the ceiling.

⛔ Do **not** add a tainted-vs-clean proportion bar, and do **not** write a "composition: top1 x% ·
top2 y%…" sentence — the donuts already carry the composition, and repeating it duplicates a surface.
