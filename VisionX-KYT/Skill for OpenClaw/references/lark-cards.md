# Lark Card JSON v2 — Output Format Override

This file overrides the Markdown output format in SKILL.md when the conversation channel is **Lark (飞书)**. All shared logic from SKILL.md still applies:
- PRE-ANALYSIS CHECKLIST
- Tool calls and data extraction
- Absolute Rules (vendor confidentiality, branding, language, high risk categories)
- Setup Guide

**Only the rendering format changes.** Output a **single Lark Card JSON v2 object** per analysis. Output ONLY the raw JSON — no markdown text, no explanation before or after.

---

## Risk → Card Header Color

| Risk Level | `template` value |
|---|---|
| High / Severe | `"red"` |
| Medium-High | `"orange"` |
| Medium | `"yellow"` |
| Low | `"green"` |

## Output Sequences

| Scenario | Card Count | Contents |
|---|---|---|
| Transaction Report | 1 card | Preface (collapsed) · Transaction Info · Risk Sources · Summary |
| Wallet — Standalone | 1 card | Preface (collapsed) · Basic Info · Timeline · Risk Breakdown · Categories · Cross-Vendor · Summary · Exposure Details (collapsed) · Risk Verdict |
| Wallet — Counterparty | 1 card | ⛔ No preface · Basic Info · Timeline · Risk Breakdown · Categories · Cross-Vendor · Summary · Exposure Details (collapsed) · Risk Verdict |

---

# Transaction Report Card

Fill all `[PLACEHOLDER]` values with real data before outputting. Never output placeholder text literally.

```json
{
  "schema": "2.0",
  "config": { "update_multi": true },
  "header": {
    "title": { "tag": "plain_text", "content": "🔬 Transaction Security Report" },
    "subtitle": { "tag": "plain_text", "content": "MetaComp VisionX · [TXHASH: first 10 chars]...[TXHASH: last 4 chars]" },
    "template": "[COLOR: red|orange|yellow|green based on txRiskLevel]",
    "icon": { "tag": "standard_icon", "token": "search-outlined" }
  },
  "body": {
    "direction": "vertical",
    "padding": "12px 12px 12px 12px",
    "elements": [

      {
        "tag": "collapsible_panel",
        "expanded": false,
        "header": { "title": { "tag": "plain_text", "content": "📊 Analysis Methodology" } },
        "elements": [
          {
            "tag": "markdown",
            "content": "[P1: Name all 6 vendors — Chainalysis, Elliptic, TRM, Merkle Science, Beosin, SlowMist — and explain cross-verification eliminates blind spots. 1–2 sentences.]\n\n[P2: Layer 1 checks direct contact with flagged addresses. Layer 2 traces all fund flows forward and backward through unlimited on-chain hops, calculating taint ratios at each hop depth. Adapt framing to risk level. Do NOT use the word threshold.]\n\n[P3: Cite one figure from MetaComp Research July 2025 (7,000 sampled transactions). Key stats: 1 vendor alone: false-clean rate up to 25%; 3+ vendors: below 0.25%. Pick the most relevant stat.]"
          }
        ]
      },

      { "tag": "hr" },

      {
        "tag": "markdown",
        "content": "**Transaction:** `[TXHASH: first 10 chars]...[TXHASH: last 4 chars]`"
      },

      {
        "tag": "table",
        "page_size": 10,
        "row_height": "low",
        "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
        "columns": [
          { "name": "f", "display_name": "Field",  "width": "150px", "horizontal_align": "left", "data_type": "text" },
          { "name": "v", "display_name": "Detail", "width": "auto",  "horizontal_align": "left", "data_type": "text" }
        ],
        "rows": [
          { "f": { "tag": "lark_md", "content": "Date" },            "v": { "tag": "lark_md", "content": "[date]" } },
          { "f": { "tag": "lark_md", "content": "Direction" },       "v": { "tag": "lark_md", "content": "[received / sent]" } },
          { "f": { "tag": "lark_md", "content": "Asset" },           "v": { "tag": "lark_md", "content": "[asset.asset]" } },
          { "f": { "tag": "lark_md", "content": "Amount" },          "v": { "tag": "lark_md", "content": "[asset.amount]" } },
          { "f": { "tag": "lark_md", "content": "USD Value" },       "v": { "tag": "lark_md", "content": "$[asset.usdValue] USD" } },
          { "f": { "tag": "lark_md", "content": "From" },            "v": { "tag": "lark_md", "content": "`[fromAddress]`" } },
          { "f": { "tag": "lark_md", "content": "To" },              "v": { "tag": "lark_md", "content": "`[toAddress]`" } },
          { "f": { "tag": "lark_md", "content": "Risk Level" },      "v": { "tag": "lark_md", "content": "[🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — map Severe→🔴 High]" } },
          { "f": { "tag": "lark_md", "content": "Direct Exposure" }, "v": { "tag": "lark_md", "content": "[Yes / No]" } }
        ]
      },

      { "tag": "hr" },

      { "tag": "markdown", "content": "**⚠️ Risk Sources**" },

      {
        "tag": "table",
        "page_size": 20,
        "row_height": "low",
        "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
        "columns": [
          { "name": "src",  "display_name": "Risk Type",   "width": "auto", "horizontal_align": "left",  "data_type": "text" },
          { "name": "rat",  "display_name": "Ratio",       "width": "80px", "horizontal_align": "right", "data_type": "text" },
          { "name": "impl", "display_name": "Implication", "width": "auto", "horizontal_align": "left",  "data_type": "text" }
        ],
        "rows": [
          "INSTRUCTION: One row per riskSource entry. Implication = level label (< 5%: low/residual · 5–20%: moderate · > 20%: significant) followed by a dash and 1 sentence of practical meaning. If riskSources is empty, output a single row: src=✅ No risk sources identified., rat=, impl=",
          { "src": { "tag": "lark_md", "content": "[source]" }, "rat": { "tag": "lark_md", "content": "[ratio]%" }, "impl": { "tag": "lark_md", "content": "[level label] — [1 sentence on practical implications]" } }
        ]
      },

      { "tag": "hr" },

      {
        "tag": "markdown",
        "content": "**📋 Comprehensive Summary**\n\n[4–5 sentences covering: 1) overall safety verdict 2) what the risk level means practically 3) explanation of each risk source 4) how direction (sent/received) affects risk 5) actionable recommendation: safe / caution / flag / avoid. ⛔ Do NOT name any vendor — use 'multiple vendors', 'cross-vendor consensus', etc.]"
      }

    ]
  }
}
```

**Error handling (output as plain markdown, not as a card):**
- `data.success === false` or `code !== 0` → check failed; suggest retry or metacomp.ai support
- 401 → API key invalid/expired; re-authenticate
- `data.extra.selectedTx` is null or empty → "Transaction details were not returned. Overall risk level: `[data.level]`."

---

# Wallet Report Card

## Card Header Rules

| Type | `title` content | Include Preface? |
|---|---|---|
| Standalone | `🔐 Wallet Security Report` | Yes — collapsed |
| Counterparty | `🔎 Counterparty Wallet Analysis` | **No** — remove element entirely |

**[ADDRESS_SHORT]** = first 6 characters + `...` + last 4 characters of `data.address`

## Card Template

```json
{
  "schema": "2.0",
  "config": { "update_multi": true },
  "header": {
    "title": { "tag": "plain_text", "content": "[🔐 Wallet Security Report OR 🔎 Counterparty Wallet Analysis]" },
    "subtitle": { "tag": "plain_text", "content": "MetaComp VisionX · [data.network] · [ADDRESS_SHORT]" },
    "template": "[COLOR: red|orange|yellow|green based on data.level]",
    "icon": { "tag": "standard_icon", "token": "lock-outlined" }
  },
  "body": {
    "direction": "vertical",
    "padding": "12px 12px 12px 12px",
    "elements": [

      "INSTRUCTION: STANDALONE ONLY — include the collapsible_panel below. COUNTERPARTY — remove it entirely.",
      {
        "tag": "collapsible_panel",
        "expanded": false,
        "header": { "title": { "tag": "plain_text", "content": "📊 Analysis Methodology" } },
        "elements": [
          {
            "tag": "markdown",
            "content": "[P1: Name all 6 vendors — Chainalysis, Elliptic, TRM, Merkle Science, Beosin, SlowMist — and explain cross-verification eliminates blind spots. 1–2 sentences.]\n\n[P2: Cite one figure from MetaComp Research July 2025. Low risk → explain why clean rating is trustworthy. Tron → reference higher risk ratio. High risk → reference multi-vendor scanning. 1–2 sentences.]"
          }
        ]
      },

      { "tag": "hr" },

      { "tag": "markdown", "content": "**📋 Basic Info**" },
      {
        "tag": "table",
        "page_size": 5,
        "row_height": "low",
        "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
        "columns": [
          { "name": "f", "display_name": "Field",  "width": "180px", "horizontal_align": "left", "data_type": "text" },
          { "name": "v", "display_name": "Detail", "width": "auto",  "horizontal_align": "left", "data_type": "text" }
        ],
        "rows": [
          { "f": { "tag": "lark_md", "content": "Address" },           "v": { "tag": "lark_md", "content": "`[data.address]`" } },
          { "f": { "tag": "lark_md", "content": "Network" },           "v": { "tag": "lark_md", "content": "[data.network]" } },
          { "f": { "tag": "lark_md", "content": "Overall Risk Level" },"v": { "tag": "lark_md", "content": "[🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High — map Severe→🔴 High; unrecognized→raw value with 🔴]" } }
        ]
      },

      { "tag": "hr" },

      { "tag": "markdown", "content": "**📅 Transaction Timeline**" },
      {
        "tag": "table",
        "page_size": 5,
        "row_height": "low",
        "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
        "columns": [
          { "name": "f", "display_name": "Field",  "width": "200px", "horizontal_align": "left", "data_type": "text" },
          { "name": "v", "display_name": "Detail", "width": "auto",  "horizontal_align": "left", "data_type": "text" }
        ],
        "rows": [
          { "f": { "tag": "lark_md", "content": "Earliest Transaction" }, "v": { "tag": "lark_md", "content": "[data.extra.earliestTransactionTime]" } },
          { "f": { "tag": "lark_md", "content": "Latest Transaction" },   "v": { "tag": "lark_md", "content": "[data.extra.latestTransactionTime]" } },
          { "f": { "tag": "lark_md", "content": "Total Incoming" },       "v": { "tag": "lark_md", "content": "$[data.extra.totalIncoming] USD" } },
          { "f": { "tag": "lark_md", "content": "Total Outgoing" },       "v": { "tag": "lark_md", "content": "$[data.extra.totalOutgoing] USD" } }
        ]
      },
      { "tag": "markdown", "content": "[1 sentence commenting on activity span and volume — long-standing vs newly created, notable volume?]" },

      { "tag": "hr" },

      { "tag": "markdown", "content": "**💰 Risk Exposure Breakdown**" },
      {
        "tag": "table",
        "page_size": 3,
        "row_height": "low",
        "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
        "columns": [
          { "name": "dir",  "display_name": "Direction",   "width": "110px", "horizontal_align": "left",  "data_type": "text" },
          { "name": "tot",  "display_name": "Total",       "width": "auto",  "horizontal_align": "right", "data_type": "text" },
          { "name": "low",  "display_name": "Low Risk",    "width": "auto",  "horizontal_align": "right", "data_type": "text" },
          { "name": "high", "display_name": "High Risk",   "width": "auto",  "horizontal_align": "right", "data_type": "text" },
          { "name": "pct",  "display_name": "High Risk %", "width": "110px", "horizontal_align": "right", "data_type": "text" }
        ],
        "rows": [
          {
            "dir":  { "tag": "lark_md", "content": "📥 Incoming" },
            "tot":  { "tag": "lark_md", "content": "$[incomingRiskExposureBreakdown.totalAmount]" },
            "low":  { "tag": "lark_md", "content": "$[incomingRiskExposureBreakdown.lowRiskAmount]" },
            "high": { "tag": "lark_md", "content": "$[incomingRiskExposureBreakdown.highRiskAmount]" },
            "pct":  { "tag": "lark_md", "content": "[highRisk÷total×100]%" }
          },
          {
            "dir":  { "tag": "lark_md", "content": "📤 Outgoing" },
            "tot":  { "tag": "lark_md", "content": "$[outgoingRiskExposureBreakdown.totalAmount]" },
            "low":  { "tag": "lark_md", "content": "$[outgoingRiskExposureBreakdown.lowRiskAmount]" },
            "high": { "tag": "lark_md", "content": "$[outgoingRiskExposureBreakdown.highRiskAmount]" },
            "pct":  { "tag": "lark_md", "content": "[highRisk÷total×100]%" }
          }
        ]
      },

      { "tag": "hr" },

      {
        "tag": "markdown",
        "content": "**🚨 High Risk Categories**\n\n[List all data.extra.highRiskCategories separated by ` · ` — or '✅ No high-risk categories detected.' if empty]\n\n[One sentence per category. Use the descriptions from SKILL.md Absolute Rules section. For unknown categories, describe based on name.]"
      },

      { "tag": "hr" },

      {
        "tag": "collapsible_panel",
        "expanded": true,
        "header": { "title": { "tag": "plain_text", "content": "🔍 Cross-Vendor Risk Comparison" } },
        "elements": [
          { "tag": "markdown", "content": "**📥 Direct Incoming — Cross-Vendor Risk Flags**" },
          {
            "tag": "table",
            "page_size": 30,
            "row_height": "low",
            "header_style": { "text_align": "center", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat", "display_name": "Category", "width": "auto",  "horizontal_align": "left",   "data_type": "text" },
              { "name": "v1",  "display_name": "Vendor 1", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v2",  "display_name": "Vendor 2", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v3",  "display_name": "Vendor 3", "width": "110px", "horizontal_align": "center", "data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: One row per unique tagTypeVerbose across vendor1.directIncoming / vendor2.directIncoming / vendor3.directIncoming. Cell rule: found + isHighRisk=true → ⚠️ High · found + isHighRisk=false → ✅ Low · not found OR vendor array is empty → —. If ALL vendors empty: single row cat='— No data from any vendor —'.",
              {
                "cat": { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "v1":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v2":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v3":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📤 Direct Outgoing — Cross-Vendor Risk Flags**" },
          {
            "tag": "table",
            "page_size": 30,
            "row_height": "low",
            "header_style": { "text_align": "center", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat", "display_name": "Category", "width": "auto",  "horizontal_align": "left",   "data_type": "text" },
              { "name": "v1",  "display_name": "Vendor 1", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v2",  "display_name": "Vendor 2", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v3",  "display_name": "Vendor 3", "width": "110px", "horizontal_align": "center", "data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same rules as above, using vendor1.directOutgoing / vendor2.directOutgoing / vendor3.directOutgoing.",
              {
                "cat": { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "v1":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v2":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v3":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📥 Indirect Incoming — Cross-Vendor Risk Flags**" },
          {
            "tag": "table",
            "page_size": 30,
            "row_height": "low",
            "header_style": { "text_align": "center", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat", "display_name": "Category", "width": "auto",  "horizontal_align": "left",   "data_type": "text" },
              { "name": "v1",  "display_name": "Vendor 1", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v2",  "display_name": "Vendor 2", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v3",  "display_name": "Vendor 3", "width": "110px", "horizontal_align": "center", "data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same rules, using vendor1.indirectIncoming / vendor2.indirectIncoming / vendor3.indirectIncoming.",
              {
                "cat": { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "v1":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v2":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v3":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📤 Indirect Outgoing — Cross-Vendor Risk Flags**" },
          {
            "tag": "table",
            "page_size": 30,
            "row_height": "low",
            "header_style": { "text_align": "center", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat", "display_name": "Category", "width": "auto",  "horizontal_align": "left",   "data_type": "text" },
              { "name": "v1",  "display_name": "Vendor 1", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v2",  "display_name": "Vendor 2", "width": "110px", "horizontal_align": "center", "data_type": "text" },
              { "name": "v3",  "display_name": "Vendor 3", "width": "110px", "horizontal_align": "center", "data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same rules, using vendor1.indirectOutgoing / vendor2.indirectOutgoing / vendor3.indirectOutgoing.",
              {
                "cat": { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "v1":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v2":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" },
                "v3":  { "tag": "lark_md", "content": "[⚠️ High / ✅ Low / —]" }
              }
            ]
          }
        ]
      },

      { "tag": "hr" },

      {
        "tag": "markdown",
        "content": "**📝 Comprehensive Summary**\n\n[4–6 sentences: 1) overall risk verdict 2) what the risk level means practically 3) key concerns (categories, exposure amounts, counterparty patterns) 4) whether history suggests legitimate or suspicious usage 5) clear actionable recommendation: freely interact / proceed with caution / avoid / report. ⛔ Do NOT name any vendor — use 'multiple vendors', 'cross-vendor consensus', etc.]"
      },

      { "tag": "hr" },

      {
        "tag": "collapsible_panel",
        "expanded": false,
        "header": { "title": { "tag": "plain_text", "content": "📊 Full Exposure Details" } },
        "elements": [
          { "tag": "markdown", "content": "**📥 Direct Incoming Exposure**" },
          {
            "tag": "table",
            "page_size": 50,
            "row_height": "low",
            "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat",  "display_name": "Category",    "width": "auto",  "horizontal_align": "left",  "data_type": "text" },
              { "name": "amt",  "display_name": "Amount (USD)", "width": "140px", "horizontal_align": "right", "data_type": "text" },
              { "name": "rat",  "display_name": "Ratio",        "width": "80px",  "horizontal_align": "right", "data_type": "text" },
              { "name": "risk", "display_name": "Risk",         "width": "110px", "horizontal_align": "center","data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: One row per data.extra.directIncoming entry — never skip $0 rows. ratio>0 → show ratio%; ratio=0 → show '<0.01%'. If empty: single row cat='— No direct incoming exposure recorded —'.",
              {
                "cat":  { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "amt":  { "tag": "lark_md", "content": "≈ $[totalValueUsd]" },
                "rat":  { "tag": "lark_md", "content": "[ratio]%" },
                "risk": { "tag": "lark_md", "content": "[⚠️ High Risk / ✅ Low Risk]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📥 Indirect Incoming Exposure**" },
          {
            "tag": "table",
            "page_size": 50,
            "row_height": "low",
            "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat",  "display_name": "Category",    "width": "auto",  "horizontal_align": "left",  "data_type": "text" },
              { "name": "amt",  "display_name": "Amount (USD)", "width": "140px", "horizontal_align": "right", "data_type": "text" },
              { "name": "rat",  "display_name": "Ratio",        "width": "80px",  "horizontal_align": "right", "data_type": "text" },
              { "name": "risk", "display_name": "Risk",         "width": "110px", "horizontal_align": "center","data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same as above, using data.extra.indirectIncoming. If empty: '— No indirect incoming exposure recorded —'.",
              {
                "cat":  { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "amt":  { "tag": "lark_md", "content": "≈ $[totalValueUsd]" },
                "rat":  { "tag": "lark_md", "content": "[ratio]%" },
                "risk": { "tag": "lark_md", "content": "[⚠️ High Risk / ✅ Low Risk]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📤 Direct Outgoing Exposure**" },
          {
            "tag": "table",
            "page_size": 50,
            "row_height": "low",
            "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat",  "display_name": "Category",    "width": "auto",  "horizontal_align": "left",  "data_type": "text" },
              { "name": "amt",  "display_name": "Amount (USD)", "width": "140px", "horizontal_align": "right", "data_type": "text" },
              { "name": "rat",  "display_name": "Ratio",        "width": "80px",  "horizontal_align": "right", "data_type": "text" },
              { "name": "risk", "display_name": "Risk",         "width": "110px", "horizontal_align": "center","data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same as above, using data.extra.directOutgoing. If empty: '— No direct outgoing exposure recorded —'.",
              {
                "cat":  { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "amt":  { "tag": "lark_md", "content": "≈ $[totalValueUsd]" },
                "rat":  { "tag": "lark_md", "content": "[ratio]%" },
                "risk": { "tag": "lark_md", "content": "[⚠️ High Risk / ✅ Low Risk]" }
              }
            ]
          },
          { "tag": "markdown", "content": "**📤 Indirect Outgoing Exposure**" },
          {
            "tag": "table",
            "page_size": 50,
            "row_height": "low",
            "header_style": { "text_align": "left", "bold": true, "background_style": "grey" },
            "columns": [
              { "name": "cat",  "display_name": "Category",    "width": "auto",  "horizontal_align": "left",  "data_type": "text" },
              { "name": "amt",  "display_name": "Amount (USD)", "width": "140px", "horizontal_align": "right", "data_type": "text" },
              { "name": "rat",  "display_name": "Ratio",        "width": "80px",  "horizontal_align": "right", "data_type": "text" },
              { "name": "risk", "display_name": "Risk",         "width": "110px", "horizontal_align": "center","data_type": "text" }
            ],
            "rows": [
              "INSTRUCTION: Same as above, using data.extra.indirectOutgoing. If empty: '— No indirect outgoing exposure recorded —'.",
              {
                "cat":  { "tag": "lark_md", "content": "[tagTypeVerbose]" },
                "amt":  { "tag": "lark_md", "content": "≈ $[totalValueUsd]" },
                "rat":  { "tag": "lark_md", "content": "[ratio]%" },
                "risk": { "tag": "lark_md", "content": "[⚠️ High Risk / ✅ Low Risk]" }
              }
            ]
          },
          { "tag": "markdown", "content": "[If any indirect exposure exists: 1 sentence explaining direct vs indirect difference. For each ⚠️ High Risk row: 1 sentence on that category's implications.]" }
        ]
      },

      { "tag": "hr" },

      {
        "tag": "markdown",
        "content": "**[VERDICT_EMOJI] Risk Verdict — [RISK_LABEL]**\n\n[1–2 sentence verdict with the most important finding]\n\n⚡ **Recommendation:** [freely interact / proceed with caution / avoid / report]"
      }

    ]
  }
}
```

**Verdict emoji and label mapping:**

| `data.level` | `[VERDICT_EMOJI]` | `[RISK_LABEL]` |
|---|---|---|
| High / Severe | 🚨 | High Risk |
| Medium-High | ⚠️ | Medium-High Risk |
| Medium | ⚠️ | Medium Risk |
| Low | ✅ | Low Risk |

---

# Final Response Gate — Lark Card Version

**Transaction:**
```
☐ Output is a single valid Lark Card JSON v2 object?
☐ Header template color matches txRiskLevel?
☐ Preface in collapsed collapsible_panel?
☐ Transaction info table: all 9 rows present?
☐ Risk sources table: at least one row (or ✅ no sources row)?
☐ Comprehensive Summary: 4–5 sentences, no vendor names?
```

**Wallet:**
```
☐ Output is a single valid Lark Card JSON v2 object?
☐ Header template color matches data.level?
☐ Preface: included if standalone, omitted if counterparty?
☐ Basic Info table: 3 rows?
☐ Transaction Timeline table: 4 rows + activity comment?
☐ Risk Exposure Breakdown table: 2 rows (Incoming + Outgoing)?
☐ High Risk Categories: listed + 1 sentence each (or ✅ none)?
☐ Cross-Vendor Comparison: 4 tables inside collapsible_panel?
☐ Comprehensive Summary: 4–6 sentences, no vendor names?
☐ Exposure Details: 4 tables inside collapsed collapsible_panel?
☐ Risk Verdict: last element, emoji + label + 1–2 sentences + recommendation?
```

Any unchecked item → fix the JSON now before outputting.
