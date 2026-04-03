# Chart Specifications

## Exposure Spider Charts — 4 Panels, Every Wallet Response

Four spider chart panels per wallet report — one per exposure direction. Never merged.

1. **Direct Incoming Exposure** — data from `directIncoming`
2. **Indirect Incoming Exposure** — data from `indirectIncoming`
3. **Direct Outgoing Exposure** — data from `directOutgoing`
4. **Indirect Outgoing Exposure** — data from `indirectOutgoing`

---

### ⛔ STEP 1 — Mandatory per-chart count gate BEFORE rendering any spider chart

**This step is required for EACH of the 4 panels individually. Do not batch or skip.**

For each panel, before writing any HTML:

1. List the entries in the array where `totalValueUsd > 0`
2. Count them → `validCount`
3. Branch:

| `validCount` | Action |
|---|---|
| 0, 1, or 2 | ⛔ STOP — skip this panel entirely. Output nothing. |
| 3 or more | ✅ Render spider chart normally |

> ⛔ **A radar chart with 2 axes renders as a straight line — this is a broken visual.** If validCount < 3, skip the panel entirely — no chart, no placeholder, no heading.

> 📌 **Two-stage logic**: `validCount` only decides **whether** to render the chart. If rendering (validCount ≥ 3), the rule in "Absolute Rules" applies: include **all** entries as axes — even those with `totalValueUsd = 0`. Do not re-filter by `totalValueUsd > 0` when building axes.

**Per-panel decision record** — before writing each panel's HTML, confirm the decision for that panel:

- Direct Incoming: validCount = ? → [chart / skip]
- Indirect Incoming: validCount = ? → [chart / skip]
- Direct Outgoing: validCount = ? → [chart / skip]
- Indirect Outgoing: validCount = ? → [chart / skip]

If the decision is "skip", output nothing for that panel and move on.

---

### Absolute Rules (apply only when rendering the chart)

- ❌ Do NOT merge any two arrays into one chart
- ✅ When rendering (validCount ≥ 3): include ALL entries as axes — even entries where `totalValueUsd = 0`

### Layout (single column — 1 panel per row)

Render all 4 panels as a vertical stack, each taking full width. Do NOT use multi-column grid.

Order: Direct Incoming → Indirect Incoming → Direct Outgoing → Indirect Outgoing

```html
<div style="width:100%">
  <!-- Panel 1: Direct Incoming — full width -->
  <!-- Panel 2: Indirect Incoming — full width -->
  <!-- Panel 3: Direct Outgoing — full width -->
  <!-- Panel 4: Indirect Outgoing — full width -->
</div>
```

Each chart panel: spider canvas on left (~60%) + custom legend on right (~40%).
Panel container: `style="display:flex; align-items:flex-start; overflow:visible; min-width:0; margin-bottom:24px"`

> ✅ Full-width panels ensure Chart.js can correctly read canvas dimensions on mount. Multi-column layouts cause canvas sizing failures in show_widget.

### Spider Chart Specs

- Chart.js `type: 'radar'`
- One axis per entry in the data array (keyed by `tagTypeVerbose`)
- Axis value: `totalValueUsdRatio` (0–100 scale, representing percentage of total flow)
- If `totalValueUsdRatio === 0`: use `0.001` as minimum to keep axis visible as a thin sliver
- `pointBackgroundColor`: match `isHighRisk` color (see Color Palette below)
- `fill: true`, fill color: 30% opacity version of dominant color
- Canvas wrapper: `<div style="position:relative; width:100%; height:240px">`

### Data Mapping

Each axis corresponds to one entry in the chart's data array:

| Property | Usage |
|---|---|
| `tagTypeVerbose` | Axis label |
| `totalValueUsdRatio` | Axis value (percentage) |
| `isHighRisk` | Determines color (see palette) |
| `totalValueUsd` | Shown in legend |

Legend ratio display:
- `totalValueUsdRatio > 0` → show `{ratio}%`
- `totalValueUsdRatio === 0` → show `< 0.01%`

Include every entry regardless of value — no filtering.

---

## Color Palette

Color is determined **per entry** by the `isHighRisk` flag.

### `isHighRisk: true` — red/warning family

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
| Unknown high-risk | `#FF4444` |

### `isHighRisk: false` — olive/yellow-green family

| Category | Hex |
|---|---|
| Exchange | `#7D8B00` |
| Mining | `#A0A830` |
| Service | `#8A9200` |
| Smart Contract Platform | `#B5C000` |
| Defi | `#5A6200` |
| Others / Unknown low-risk | `#C8D44A` |

---

## Right-Side Legend Spec

Each chart has its own single-column legend. **Never combine two arrays into one legend.**

Use two-line stacked layout per entry to prevent horizontal overflow:

```html
<div class="exposure-legend" style="min-width:0; padding:4px 0; overflow:visible">
  <!-- one entry per item in the chart's array — include ALL entries, even $0 -->
  <div class="legend-entry" style="display:flex; flex-direction:column; margin-bottom:6px">
    <div style="display:flex; align-items:flex-start; min-width:0">
      <span style="background:#7D8B00; width:10px; height:10px; border-radius:2px; flex-shrink:0; margin-right:5px; margin-top:2px"></span>
      <span style="font-size:11px; white-space:normal; word-break:break-word; line-height:1.3">Exchange</span>
    </div>
    <div style="padding-left:15px; display:flex; justify-content:space-between; gap:4px; flex-wrap:wrap">
      <span style="font-size:10px; color:#888; white-space:nowrap">≈ $570,263,322</span>
      <span style="font-size:10px; font-weight:bold; white-space:nowrap">37.02%</span>
    </div>
  </div>
  <!-- repeat for each entry -->
</div>
```

### Legend Styling Rules

- **Two lines per entry**: line 1 = swatch + name; line 2 = amount + ratio (15px indent)
- Swatch: `10×10px`, `border-radius:2px`, `flex-shrink:0`, `margin-right:5px`, `margin-top:2px`
- Name: `font-size:11px`, `white-space:normal`, `word-break:break-word` — **allow wrapping, never truncate**
- Amount: `font-size:10px`, muted (`#888`), `white-space:nowrap` — omit "USD" suffix
- Ratio: `font-size:10px`, bold, `white-space:nowrap`
- Container: `overflow:visible` (not hidden) so text is never clipped at panel edge
- High-risk rows: name color matches the axis color, not black
- Zero-value rows: render normally — do not dim, hide, or reorder

