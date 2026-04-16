# Wallet Report — Step ⑦: 🚨 Risk Conclusion Card

Render a single prominent card **immediately after the visualization widget** via a dedicated `show_widget` call.

- ❌ Do NOT output the card HTML as standalone text — it will render as raw code
- ❌ Do NOT skip this step or replace it with a markdown blockquote
- ✅ Always call `show_widget` with the card HTML — this is the only valid way to render it
- ✅ The response is **incomplete** until `show_widget` has been called for this card

**Content:**
- Risk level badge: 🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High (bold, large)
- 1–2 sentences: key risk verdict summarizing the most important finding
- One clear action recommendation: freely interact / proceed with caution / avoid / report

**HTML template — pass exactly this structure to `show_widget`:**

```html
<!-- 🔴 High Risk example — swap colors per level -->
<div style="background:#fff0f0; border:1.5px solid #E53030; border-radius:12px; padding:18px 20px; margin-top:8px; font-family:sans-serif">
  <div style="font-size:16px; font-weight:700; color:#A32D2D; margin-bottom:8px">🚨 Risk Verdict — 🔴 High Risk</div>
  <div style="font-size:13px; color:#7a2020; margin-bottom:10px">{1–2 sentence verdict}</div>
  <div style="font-size:13px; font-weight:600; color:#A32D2D">⚡ Recommendation: {action}</div>
</div>
```

**Color mapping by risk level:**

| Level | Background | Border | Text color |
|---|---|---|---|
| 🔴 High | `#fff0f0` | `#E53030` | `#A32D2D` / `#7a2020` |
| 🟠 Medium-High | `#fff4e5` | `#FF8C00` | `#7a3800` / `#5a2a00` |
| 🟡 Medium | `#fffde7` | `#FFC107` | `#6b5000` / `#4a3800` |
| 🟢 Low | `#f0fff4` | `#4CAF50` | `#1a5c2a` / `#134520` |
