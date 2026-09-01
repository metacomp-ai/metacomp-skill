# Exposure Summary Specification

Exposure data is rendered as **two donut charts** — `D2` Incoming Exposure and `D3` Outgoing Exposure,
each its own `show_widget` call (see `visualization.md`). Everything below feeds those two charts.

---

## Donut charts — pure CSS, no library

⛔ No Chart.js, no SVG library, no CDN — the iframe blocks external requests. Draw donuts with
`conic-gradient` and punch the hole with a `mask`. This costs ~200 bytes per chart.

Add to the widget's `<style>` block:

```css
.pie{width:150px;height:150px;border-radius:50%;flex-shrink:0;
-webkit-mask:radial-gradient(circle,transparent 52%,#000 53%);mask:radial-gradient(circle,transparent 52%,#000 53%)}
.row{display:flex;gap:20px;align-items:center;flex-wrap:wrap}
.lg{flex:1;min-width:250px}.lg td{padding:4px 8px}
```

Then chart + legend side by side:

```html
<div class=h>📥 Incoming — Direct Tainted Composition
  <span class=mu style="font-weight:400"> · {total} USD</span></div>
<div class=row>
  <div class=pie style="background:conic-gradient(#FF3366 0.00% 60.37%,#FF9900 60.37% 81.18%,#FF8899 81.18% 93.11%,#E53030 93.11% 97.51%,#CC1111 97.51% 99.93%,#FF2020 99.93% 100.00%)"></div>
  <table class=lg>
    <tr><td><span class=sw style="background:#FF3366"></span>Theft</td>
        <td class=n>$10,570,340,566.40</td><td class="n b">60.37%</td></tr>
    …one row per category…
  </table>
</div>
```

**What goes into each donut:**

One donut per direction. Take **both** arrays for that direction and keep them distinguishable by
labelling every entry with its hop:

| Chart | Arrays | Entry label |
|---|---|---|
| **D2** Incoming Exposure | `data.extra.directIncoming` + `data.extra.indirectIncoming` | `{tagTypeVerbose} (Direct)` / `{tagTypeVerbose} (Indirect)` |
| **D3** Outgoing Exposure | `data.extra.directOutgoing` + `data.extra.indirectOutgoing` | same |

⛔ **Include low-risk categories.** Exchange, Defi, Others, Service, Mining and Smart Contract Platform
are what make the chart readable: a mostly-olive donut with a few red slivers tells a completely
different story from a mostly-red one. Charting only the high-risk entries throws that away.

Denominator = the sum of `totalValueUsd` across **all** entries of both arrays for that direction.

**Building the `conic-gradient`:**
1. Merge the two arrays into one list of labelled entries, then **sort descending by amount**.
2. Walk them in that order accumulating `pct = amount ÷ total × 100`; each slice is
   `{hex} {start:.2f}% {end:.2f}%`. Skip zero-amount entries — a 0% slice is invalid CSS noise.
3. The **last slice must end at exactly `100.00%`**. If it does not, the denominator is wrong.
4. `mask` is what makes it a donut; where unsupported it degrades to a filled pie, which is fine.

**Legend rules:**
- Legend order **matches the donut** (descending), so the reader can map slice → row.
- Two columns: the label (colour swatch + `{Category} ({Direct|Indirect})`, with `≈ ${amount}` on a
  second muted line) and the share, right-aligned and bold.
- **Language:** the category name uses the display format from `SKILL.md` → Language (localized name
  only) and the `(Direct)`/`(Indirect)` hop label is localized — 中文: `诈骗（直接）`, `交易所（间接）`,
  `赌博（直接）`; English turn: `Scams (Direct)`. Amounts and currency codes stay verbatim.
- List **every** entry that has a nonzero amount. ⛔ Never merge several into an "Other (…)" row — the
  low-risk categories are exactly what the reader needs to see the ratio. Zero-amount entries simply do
  not appear (they are not slices).
- Share: two decimals; nonzero but under 0.01 → `< 0.01%`.

**Fixed row order does not apply to donut legends.** The 9-category fixed order governs the D1 exposure
tables; a chart legend is sorted by size so it lines up with the slices.

---

## Exposure Data Merging Rules

These feed the **Risk Exposure Breakdown** table in Step ③ (Markdown), not the donuts.

**Incoming high-risk total:**
- Sum all `totalValueUsd` from `walletCheck.data.extra.directIncoming` where `isHighRisk=true`
- Plus all `totalValueUsd` from `walletCheck.data.extra.indirectIncoming` where `isHighRisk=true`

**Outgoing high-risk total:**
- Sum all `totalValueUsd` from `walletCheck.data.extra.directOutgoing` where `isHighRisk=true`
- Plus all `totalValueUsd` from `walletCheck.data.extra.indirectOutgoing` where `isHighRisk=true`

**Ratio (`highRiskRatio`) — do NOT sum `totalValueUsdRatio`.**
Those per-entry ratios are shares of total flow and are `0` on high-volume addresses, which would print a
meaningless `0%`. Compute it from the breakdown fields instead, so the summary line and the Risk Exposure
Breakdown table always agree:

- Incoming: `incomingRiskExposureBreakdown.highRiskAmount ÷ ...totalAmount × 100`
- Outgoing: `outgoingRiskExposureBreakdown.highRiskAmount ÷ ...totalAmount × 100`
- Two significant digits, `× 100` mandatory — see `wallet-report.md` → Risk Exposure Breakdown for the
  magnitude check. Never round a nonzero share down to `0.00%`.

**Skip rule:**
- Both `directIncoming` and `indirectIncoming` empty → omit the D2 donut; say so in one muted line.
- Both `directOutgoing` and `indirectOutgoing` empty → omit the D3 donut likewise.

---

## Category Colour Reference — LIVE, use these values

These hexes colour the donut slices and their legend swatches in D2 / D3. High-risk categories take the
red family, low-risk categories the olive family — that contrast is the chart's whole message. Keep a
category's colour identical in both donuts.

### `isHighRisk: true`
| Category | Hex |
|---|---|
| Theft | `#FF3366` |
| Malware | `#FF5050` |
| Sanctions | `#E53030` |
| Scams | `#CC1111` |
| Darknet | `#991111` |
| High Risk Organisation | `#FF2020` |
| Coin Mixer | `#FF8899` |
| Extortion | `#FF6644` |
| Gambling | `#FF9900` |

### `isHighRisk: false`
| Category | Hex |
|---|---|
| Exchange | `#7D8B00` |
| Mining | `#A0A830` |
| Service | `#8A9200` |
| Smart Contract Platform | `#B5C000` |
| Defi | `#5A6200` |
| Others / Unknown low-risk | `#C8D44A` |
