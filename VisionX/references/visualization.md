# Visualization — Rendering Specifications

---

## Enforcement Rules

- ❌ Do NOT finish a wallet report response without calling `show_widget` (transaction reports have no widget)
- ✅ Always call `read_me(["chart"])` before the first `show_widget` in each wallet response
- ✅ Every new wallet MCP result requires its own fresh visualization

## Widget Render Reliability — retry the first call, never improvise a text fallback

The chart runtime cold-starts on the **first** chart call of a fresh MCP session: `read_me(["chart"])` or the first `show_widget` sometimes returns an error or an empty/failed result the first time, then succeeds on a second attempt. (This is the "first conversation shows tables, second conversation shows the charts" symptom — the second conversation just hit a warm runtime.) A same-turn retry is how you get that "second time" without making the user re-ask.

So, when a chart call doesn't succeed, **retry before doing anything else** — do not abandon the widget after one hiccup:

- `read_me(["chart"])` errors or returns empty → **retry it once** before the first `show_widget`. Do not call `show_widget` until `read_me(["chart"])` has returned successfully.
- A `show_widget` call returns an error or an empty/failed result → **retry that same `show_widget` call once** before moving on. The first widget call in a session is the usual culprit; a single retry almost always renders.

What you must NOT do, because it produces exactly the broken first-conversation output:

- ❌ Do NOT silently degrade the charts to markdown/plain-text tables after a single failed call. The `show_widget` chart **is** the required deliverable, not an optional enhancement.
- ❌ Do NOT tell the user the visualization tool is "unresponsive" / "unavailable" or emit a "presenting data in table form below" substitute. That sentence is never correct here — retry instead.
- Only if a chart call **fails again after the retry** do you add one brief line ("the chart didn't render this time — here is the data") and continue with the remaining report sections. One retry first, always.

## Chart Fallback Rule

- Empty array → gray placeholder slice/bar labeled "No data" (transaction charts)
- Null field → zero baseline
- Donut panels: skip only when **both** source arrays for that direction are empty (see `chart-spec.md`)

---

## Widget Layout Rules

### ❌ Never do these
- ❌ No `<iframe>` — widget must be inline HTML
- ❌ No fixed height on outer container — no `height:`, `max-height:`, `overflow:scroll/auto`
- ❌ No scroll container on the outer widget container — no `overflow:scroll/auto` with fixed height
- ✅ Inner sections MAY use `display:flex` for side-by-side elements (e.g. chart + legend within one panel)
- ❌ Do NOT use multi-column grid for donut chart panels — full-width single column only (see `chart-spec.md`)
- ❌ Do NOT output High Risk Categories HTML as standalone text — embed in `show_widget` payload

### ✅ Correct outer structure
```html
<div style="width:100%; font-family:sans-serif">
  <!-- metric cards row -->
  <!-- high risk exposure tables (wallet only) -->
  <!-- chart sections -->
</div>
```

### Wallet widget structure

show_widget #1 for wallet reports MUST start with this section header — place it before metric cards:

```html
<!-- Section header — always the first element inside the outer div -->
<div style="border-top:4px solid #1d4ed8; padding-top:16px; margin-bottom:20px">
  <div style="font-size:20px; font-weight:700; color:#1d4ed8; letter-spacing:0.01em">
    🔐 Wallet Security Report
  </div>
  <div style="font-size:12px; color:#888; margin-top:4px">MetaComp VisionX</div>
  <hr style="border:none; border-top:1px solid #e5e7eb; margin-top:12px; margin-bottom:0">
</div>
<!-- metric cards row follows -->
```

If this is a counterparty wallet (VisionX was called with transactionDetails), change the title to:
```html
<div style="font-size:20px; font-weight:700; color:#b45309; letter-spacing:0.01em">
  🔎 Counterparty Wallet Analysis
</div>
```
(use amber/orange `#b45309` to visually distinguish from the transaction report above)

---

## Chart Type Mapping

| Data | Chart type | Content |
|---|---|---|
| `directIncoming[]` + `indirectIncoming[]` (wallet) | Donut | Incoming Exposure (Direct + Indirect) |
| `directOutgoing[]` + `indirectOutgoing[]` (wallet) | Donut | Outgoing Exposure (Direct + Indirect) |

Donut panels skip only when both source arrays for that direction are empty (see `chart-spec.md`).

---

## Chart Styling Rules

- Custom HTML legend beside each chart — never use Chart.js default legend
- Doughnut cutout: `52%`
- Bar border radius: `6px`, no border
- Axes: hide border line, show subtle grid (`rgba(0,0,0,0.07)`)
- Font ticks: `11–12px`
- Canvas wrapper: `<div style="position:relative;width:100%;height:Xpx">` — never set height on canvas element

### Doughnut — Pointer Labels
For slices `> 5%`: draw pointer label outside using `afterDraw` hook:
1. Compute midpoint angle → radial line (~20px) → horizontal tick (~12px) → label
2. Font `12px`; bold if `isHighRisk=true`; color matches slice
3. Slices ≤ 5% → legend only, no pointer

### Metric Cards
`background: var(--color-background-secondary)`, `border-radius: var(--border-radius-md)`, `padding: 1rem`, centered text

---

## High-Risk Category Summary Tables — Inside show_widget #1 (Wallet Only)

> ⚠️ These are NOT the Exposure Detail Tables in `wallet-exposure-tables.md` (Step ⑥).
> These go **inside show_widget #1 payload** and show only `isHighRisk=true` entries with 9 fixed rows.

Render 4 HTML tables in 2×2 layout inside the show_widget #1 payload. Never as standalone text.

**Layout:**
```
Row A: [ Incoming Direct ]   [ Incoming Indirect ]
Row B: [ Outgoing Direct ]   [ Outgoing Indirect ]
```

**Rules:**
- Fixed 9-row list in every table — show `0` for missing categories
- Row order: Sanctions → High Risk Organisation → Theft → Malware → Scams → Extortion → Coin Mixer → Darknet → Gambling

**Data source per table:**

| Table | Data array | % column header | % field |
|---|---|---|---|
| Incoming Direct | `walletCheck.data.extra.directIncoming` (isHighRisk=true) | High-Risk % of Total Received | `totalValueUsdRatio` |
| Incoming Indirect | `walletCheck.data.extra.indirectIncoming` (isHighRisk=true) | High-Risk % of Total Received | `totalValueUsdRatio` |
| Outgoing Direct | `walletCheck.data.extra.directOutgoing` (isHighRisk=true) | High-Risk % of Total Sent | `totalValueUsdRatio` |
| Outgoing Indirect | `walletCheck.data.extra.indirectOutgoing` (isHighRisk=true) | High-Risk % of Total Sent | `totalValueUsdRatio` |

**Value formatting:**
- Amount (`totalValueUsd`) > 0: `≈ 19,653,080.62` (comma separator, no USD suffix)
- Amount = 0 or missing: `0`
- `totalValueUsdRatio` > 0: `1.28 %` (space before %)
- `totalValueUsdRatio` = 0 or missing: `0`

**HTML template:**
```html
<!-- Pair A: side by side -->
<div style="display:flex; gap:16px; margin-bottom:24px">

  <!-- Incoming Direct -->
  <div style="flex:1; min-width:0">
    <div style="margin-bottom:8px; font-size:14px; font-weight:600">
      <span style="color:#4CAF50">Incoming</span>
      <span style="color:#333"> Direct Exposure to High Risk Sources</span>
    </div>
    <table style="width:100%; border-collapse:collapse; font-size:13px">
      <thead>
        <tr style="background:#555; color:#fff">
          <th style="padding:8px 10px; text-align:left">High Risk Sources</th>
          <th style="padding:8px 10px; text-align:right">Amount (USD)</th>
          <th style="padding:8px 10px; text-align:right">High-Risk % of Total Received</th>
        </tr>
      </thead>
      <tbody>
        <!-- 9 rows, alternating #fff / #f5f5f5 -->
        <!-- col 1: tagTypeVerbose | col 2: totalValueUsd | col 3: totalValueUsdRatio -->
        <tr style="background:#fff">
          <td style="padding:7px 10px">Sanctions</td>
          <td style="padding:7px 10px; text-align:right">{totalValueUsd}</td>
          <td style="padding:7px 10px; text-align:right">{totalValueUsdRatio}</td>
        </tr>
        <!-- repeat for: High Risk Organisation, Theft, Malware, Scams, Extortion, Coin Mixer, Darknet, Gambling -->
      </tbody>
    </table>
  </div>

  <!-- Incoming Indirect — same structure, indirectIncoming data -->
  <div style="flex:1; min-width:0">...</div>

</div>

<!-- Pair B: Outgoing Direct + Outgoing Indirect — same structure -->
<div style="display:flex; gap:16px; margin-bottom:24px">...</div>
```
