# Wealth Product Display Specification

This sub-skill defines how to render the list returned by `get_fip_products` in STEP 3A.

> **Token Guard applies to every MCP call referenced by this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## Data model (real schema)

`get_fip_products` returns:

```json
{
  "success": true,
  "code": 0,
  "msg": null,
  "data": [ /* products */ ],
  "currencyConvertInfoList": null
}
```

**Products live at top-level `data` (an array).** Do NOT look for `data.products` — the key does not exist.

Each product:
- `productCode` — e.g. `"FIP_30Days"`, `"FIP_OpenTerm_T+1"`
- `productName` — display name (e.g. `"Fixed Income Products - 30 Days"`)
- `productType` — e.g. `"FIP"`
- `term` — display string (e.g. `"Flexible"`, `"30 Days"`)
- `termType` — `1` = open-term / flexible, `2` = fixed-term
- `estApr` — product-level rate, possibly a range (e.g. `"10.00%"` or `"10.00%-11.11%"`)
- `sort` — display order (ascending)
- `currencyItemList[]` — per-currency variants

Each variant inside `currencyItemList`:
- `id` (used later in `fip_subscribe`)
- `currency` — `USD` / `USDT` / `USDC` / `BTC` / `ETH`
- `estApr` — e.g. `"10.00%"` (already contains `%`, display as-is)
- `term` — e.g. `"Flexible"`, `"30 Days"`, `"60 Days"`, `"90 Days"`
- `termType` — `1` or `2`
- `termDays` — **number, may be negative as a settlement sentinel**: `-2` = T+1 flexible, `-1` = T+3 flexible, otherwise real days (30 / 60 / 90)
- `liquidity` — human-readable settlement note (e.g. `"(T + 1 Settlement)"`)
- `mhp` — minimum holding period note (e.g. `"Minimum Holding Period: 14 Days"`), may be `""`
- `issuer` — e.g. `"MVGX"`, `"MetaComp"` — **not displayed to users; kept here for completeness only**

---

## Display rules

- **Group by product** (iterate over `data[]`, ordered by `sort` ascending). For each product, list its `currencyItemList` variants as rows.
- For the **Term column**, ALWAYS use the variant's `term` string — never `termDays`. `termDays = -1` / `-2` are sentinels, not displayable days.
- For the **APY column**, use the variant's `estApr` as-is (it already contains `%`).
- Always include the `liquidity` column.
- Include the `mhp` column **only for open-term products** (`termType === 1`); omit it entirely for fixed-term products — see "Column selection per product" below.
- Do NOT include an `issuer` column — the server returns it, but it is not shown to users.
- Amount limits come from the variant's `currencyItemList[j].minAmount` / `maxAmount` (strings, or `null` = no limit on that side). Render the **限额/Amount** column as: both present → `{minAmount}–{maxAmount}`; only min → `≥ {minAmount}`; only max → `≤ {maxAmount}`; both `null` → `不限 / No limit`. Display amounts with thousands separators (e.g. `100,000–200,000`). Never hard-code per-currency defaults.
- Do NOT invent, sort, or filter variants by `rate` — display them in the order returned.
- If `data` is empty or every product has an empty/null `currencyItemList`: output "No wealth products are currently available." / "当前暂无可认购的理财产品。" and stop.

---

## Column selection per product

Column set is decided **per product table** (not per variant — never mix schemas within a single table):

- **Fixed-term product** (`product.termType === 2`, e.g. `FIP_30Days`, `FIP_60Days`, `FIP_90Days`): render **6 columns, no MHP**:
  `# | Currency | Term | APY | 限额 | Liquidity`
  Rationale: minimum holding period equals the term for these products, which is already shown in the Term column. Duplicating it adds noise.
- **Open-term product** (`product.termType === 1`, e.g. `FIP_OpenTerm_T+1`, `FIP_OpenTerm_T+3`): render **7 columns, MHP included**:
  `# | Currency | Term | APY | 限额 | Liquidity | MHP`
  Rationale: open-term variants may carry meaningful `mhp` values (e.g. `"Minimum Holding Period: 14 Days"`) that must be shown.

---

## Canonical layout (Chinese)

Templates below are the **canonical source**. Render in the user's conversation language per wealth.md LANGUAGE CONTRACT: for English users, translate headers/labels/prose (`币种` → `Currency`, `期限` → `Term`, `年化` → `APY`, `限额` → `Amount`, `结算` → `Settlement`, `最短持有` → `MHP`, `产品综合年化` → `Product-level APY`, `30 天` → `30 Days`, `60 天` → `60 Days`, `90 天` → `90 Days`, etc.); keep structure, cell values, and server-returned strings (`Flexible`, `10.00%`, `(T + 3 Settlement)`, `Minimum Holding Period: 14 Days`, product names) byte-for-byte.

**固定期产品（无 最短持有 列，`termType === 2`）：**

```
### Fixed Income Products - 30 Days（FIP / FIP_30Days）

产品综合年化：10.00%

| # | 币种 | 期限 | 年化 | 限额 | 结算 |
|---|------|------|------|------|------|
| 1 | USD  | 30 天 | 10.00% | 100,000–200,000 | (T + 1 Settlement) |
| 2 | USDT | 30 天 | 10.00% | 100,000–200,000 | (T + 1 Settlement) |
| 3 | USDC | 30 天 | 10.00% | 100,000–200,000 | (T + 1 Settlement) |
| 4 | BTC  | 30 天 | 10.00% | 1–2 | (T + 1 Settlement) |
| 5 | ETH  | 30 天 | 10.00% | 10–20 | (T + 1 Settlement) |
```

**开放式产品（保留 最短持有 列，`termType === 1`）：**

```
### Fixed Income Products - Open Term T+3（FIP / FIP_OpenTerm_T+3）

产品综合年化：10.00%-11.11%

| # | 币种 | 期限 | 年化 | 限额 | 结算 | 最短持有 |
|---|------|------|------|------|------|----------|
| 1 | USD  | Flexible | 10.00% | 100,000–200,000 | (T + 3 Settlement) | Minimum Holding Period: 14 Days |
| 2 | USDT | Flexible | 10.00% | 100,000–200,000 | (T + 3 Settlement) | — |
| 3 | USDC | Flexible | 10.00% | 100,000–200,000 | (T + 3 Settlement) | — |
| 4 | BTC  | Flexible | 10.00% | 1–2 | (T + 3 Settlement) | — |
| 5 | ETH  | Flexible | 11.11% | 10–20 | (T + 3 Settlement) | — |
```

每个产品一段（按 `sort` 升序），最后询问（英文用户翻译为 "Which product would you like to subscribe to? Please specify product name and currency."）：

> 请问您想认购哪一款？请告诉我**产品名称**和**币种**。（期限由产品决定，无需指定）

---

## Variable mapping

| Variable | Source | Notes |
|---|---|---|
| `productName` | `data[i].productName` | |
| `productType` / `productCode` | `data[i].productType` / `data[i].productCode` | used later in `get_fip_agreement` |
| Product-level APY | `data[i].estApr` | may be a range, e.g. `"10.00%-11.11%"` |
| Currency | `currencyItemList[j].currency` | |
| Term (display) | `currencyItemList[j].term` | **never** format `termDays` as "N days". Fixed-term: localize per LANGUAGE CONTRACT (`30 天` / `60 天` / `90 天` for CN, `30 Days` / `60 Days` / `90 Days` for EN). Open-term: keep `"Flexible"` as-is in all languages |
| APY | `currencyItemList[j].estApr` | already contains `%`, render as-is |
| 限额/Amount | `currencyItemList[j].minAmount` / `maxAmount` | both → `{minAmount}–{maxAmount}`; only min → `≥ {minAmount}`; only max → `≤ {maxAmount}`; both `null` → `不限 / No limit`; thousands separators |
| Liquidity | `currencyItemList[j].liquidity` | empty → `—` |
| MHP | `currencyItemList[j].mhp` | **only present for `termType === 1` products**; see "MHP display rules" below |

---

## MHP display rules

> These rules apply **only to open-term products** (`product.termType === 1`). Fixed-term products (`product.termType === 2`) omit the MHP column entirely, per "Column selection per product" above — do not apply any of the rules below to them.

For open-term product tables, render each cell in the MHP column as:

1. **`mhp` is a non-empty string** → display it verbatim (e.g. `"Minimum Holding Period: 14 Days"`).
2. **`mhp` is empty** → display `—`. Open-term products have no minimum holding period by default.

Never display the raw `termDays` number — for open-term variants it is `-1` or `-2` (settlement sentinels, not day counts).

---

## Rules

- Row numbering (`#`) is local to each product, not global.
- Do NOT pre-select or highlight a "recommended" variant — the user chooses.
- Do NOT collapse variants of the same product into a single row.
- Do NOT show `termDays` directly to the user under any circumstance — it can be negative. The `term` string is the user-facing field.
- Do NOT filter out variants based on `termType` or `mhp` — display everything the server returned.
- Do NOT add an MHP column to fixed-term product tables. If `product.termType === 2`, the MHP column must be absent from that product's table — not shown as `—`, not shown as the term value, not shown at all.
