# Chart Specifications

## Exposure Donut Charts — 2 Panels, Every Wallet Response

Two donut chart panels per wallet report — one for incoming, one for outgoing. Never merged into one chart.

1. **Incoming Exposure** — data merged from `directIncoming` + `indirectIncoming`
2. **Outgoing Exposure** — data merged from `directOutgoing` + `indirectOutgoing`

---

## Fallback Rule

If **both** source arrays for a direction are empty → skip that panel entirely. Output nothing.
If only one array is empty, render using the non-empty array alone.

---

## Slice Construction

Each entry in the arrays becomes one independent slice. Append a direction suffix to the label:

- Entry from `directIncoming` / `directOutgoing` → label: **`"{tagTypeVerbose} (Direct)"`**
- Entry from `indirectIncoming` / `indirectOutgoing` → label: **`"{tagTypeVerbose} (Indirect)"`**

If the same `tagTypeVerbose` appears in both direct and indirect, they remain **separate slices** — do not merge.

**Slice value:** `totalValueUsdRatio` (percentage of total flow).
If `totalValueUsdRatio === 0`: use `0.001` as minimum to keep a visible sliver.

---

## Color Palette

Color is determined per entry by `isHighRisk` and `tagTypeVerbose`.

**Direct slices** → full color opacity.
**Indirect slices** → 70% opacity — append `B3` to the hex (e.g. `#CC1111` → `#CC1111B3`).

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

## Chart.js Config

```js
{
  type: 'doughnut',
  cutout: '52%'
}
```

Canvas wrapper: `<div style="position:relative; width:100%; height:280px">`
Never set height on the canvas element itself.

---

## Pointer Labels (afterDraw hook)

For slices where `totalValueUsdRatio > 5`:
1. Compute midpoint angle → radial line (~20px) → horizontal tick (~12px) → label
2. Short label format: `"{tagTypeVerbose} (D)"` for Direct, `"{tagTypeVerbose} (I)"` for Indirect
3. Font `12px`; bold if `isHighRisk=true`; color matches slice
4. Slices ≤ 5% → legend only, no pointer

---

## Legend Spec

Right-side legend. Two-line stacked layout per entry — never combine two arrays into one legend.

```html
<div class="legend-entry" style="display:flex; flex-direction:column; margin-bottom:6px">
  <div style="display:flex; align-items:flex-start; min-width:0">
    <span style="background:{color}; width:10px; height:10px; border-radius:2px; flex-shrink:0; margin-right:5px; margin-top:2px"></span>
    <span style="font-size:11px; white-space:normal; word-break:break-word; line-height:1.3">{tagTypeVerbose} (Direct)</span>
  </div>
  <div style="padding-left:15px; display:flex; justify-content:space-between; gap:4px; flex-wrap:wrap">
    <span style="font-size:10px; color:#888; white-space:nowrap">≈ ${totalValueUsd}</span>
    <span style="font-size:10px; font-weight:bold; white-space:nowrap">{ratio > 0 ? ratio% : "< 0.01%"}</span>
  </div>
</div>
```

- Indirect entries: label reads `"{tagTypeVerbose} (Indirect)"`, swatch uses 70% opacity color
- High-risk rows: name text color matches the slice color (not black)
- Zero-value rows: render normally — do not dim, hide, or reorder

---

## Layout

Two panels, full-width single column. Order: Incoming → Outgoing.

```html
<div style="width:100%">
  <!-- Panel 1: Incoming — full width -->
  <!-- Panel 2: Outgoing — full width -->
</div>
```

Panel container: `style="display:flex; align-items:flex-start; overflow:visible; min-width:0; margin-bottom:24px"`

Chart side: ~60% width. Legend side: ~40% width.
