# Account Display Specification

This sub-skill defines how to present account data and available currency pairs to the user in STEP 3.

> **Token Guard applies to every MCP call referenced by this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## Account Overview (from `get_account_summary`)

Present the high-level summary first:

### English

```
**Your Account Overview**

| Account Type         | Available (USD)          | Pending (USD)          | Total (USD)          |
|----------------------|--------------------------|------------------------|----------------------|
| Fiat                 | {fiat.availableAmount}   | {fiat.pendingAmount}   | {fiat.totalAmount}   |
| Crypto               | {crypto.availableAmount} | {crypto.pendingAmount} | {crypto.totalAmount} |
| Investment Fiat      | {investment_fiat.availableAmount}   | {investment_fiat.pendingAmount}   | {investment_fiat.totalAmount}   |
| Quarantine Portfolio | {quarantine_portfolio.availableAmount} | {quarantine_portfolio.pendingAmount} | {quarantine_portfolio.totalAmount} |
| Investment Product   | {investment_product.availableAmount}   | {investment_product.pendingAmount}   | {investment_product.totalAmount}   |
```

### Chinese

```
**您的账户概览**

| 账户类型 | 可用 (USD) | 待处理 (USD) | 总计 (USD) |
|---------|-----------|-------------|-----------|
| 法币账户 | {fiat.availableAmount}   | {fiat.pendingAmount}   | {fiat.totalAmount}   |
| 加密货币 | {crypto.availableAmount} | {crypto.pendingAmount} | {crypto.totalAmount} |
| 投资法币 | {investment_fiat.availableAmount}   | {investment_fiat.pendingAmount}   | {investment_fiat.totalAmount}   |
| 隔离资产 | {quarantine_portfolio.availableAmount} | {quarantine_portfolio.pendingAmount} | {quarantine_portfolio.totalAmount} |
| 投资产品 | {investment_product.availableAmount}   | {investment_product.pendingAmount}   | {investment_product.totalAmount}   |
```

**Rules:**
- **All 5 rows must always appear** — never skip or omit any Account Type, even if all balances are zero
- **All 3 columns must always appear** — Available, Pending, Total
- Zero values display as `0.00`, never as `—` or omitted
- All amounts with thousands separators: `13,887,754,197.50` not `13887754197.5`
- Amounts in the overview table are **aggregated USD equivalents** from `get_account_summary` — add "(USD)" in the header to clarify
- **Swap-eligible accounts:** Only **Fiat** and **Crypto** can be used for swap. Mark them in the overview (e.g. with a note or indicator). Investment Fiat, Investment Product, and Quarantine Portfolio are display-only and cannot participate in currency exchange

---

## Per-Currency Detail (from `get_account_detail`)

Below the overview, show per-currency balances from `data.instrumentInfoMap`.

**Display rules:**
- **Show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`**
- `pendingCreditAmount > 0` means incoming funds awaiting confirmation — display in a separate "Incoming" column
- At the end, add: "Other {N} currencies have zero balance" (where N = total currencies - displayed currencies)
- Sort: non-zero currencies first, by `availableAmount` descending

### English

```
**Fiat Account Detail** (Account: {holderCode})

| Currency | Available          | Pending | Incoming | USD Equivalent     |
|----------|--------------------|---------|----------|--------------------|
| USD      | 13,887,754,187.50  | 10      | —        | 13,887,754,187.50  |

> Other 35 currencies have zero balance.
```

```
**Cryptocurrency Detail** (Account: {holderCode})

| Currency | Available | Pending | Incoming | USD Equivalent |
|----------|-----------|---------|----------|----------------|
| USDT     | 80.00     | —       | 64.00    | 79.99          |
| USDC     | —         | —       | 9.99     | —              |

> Other 22 currencies have zero balance.
```

### Chinese

```
**法币账户明细**（账户：{holderCode}）

| 币种 | 可用余额            | 待处理 | 待入账 | USD 等值            |
|-----|--------------------| ------|-------|---------------------|
| USD | 13,887,754,187.50  | 10    | —     | 13,887,754,187.50   |

> 其他 35 个币种余额为 0。
```

```
**加密货币明细**（账户：{holderCode}）

| 币种  | 可用余额 | 待处理 | 待入账 | USD 等值 |
|------|---------|-------|-------|---------|
| USDT | 80.00   | —     | 64.00 | 79.99   |
| USDC | —       | —     | 9.99  | —       |

> 其他 22 个币种余额为 0。
```

### Data mapping

From `get_account_detail` response, for each entry in `instrumentInfoMap`:
| Display field | Source field |
|---|---|
| Currency | map key (currency code) |
| Available | `availableAmount` (0 → `—`) |
| Pending | `pendingAmount` (0 → `—`) |
| Incoming | `pendingCreditAmount` (0 → `—`) |
| USD Equivalent | `availableAmountDisplay` (0 → `—`) |

---

## Investment Fiat Detail (from `get_account_detail`, productCode=investment_fiat)

Same display rules as Fiat Account Detail. Show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`.

### English

```
**Investment Fiat Detail** (Account: {holderCode})

| Currency | Available          | Pending  | Incoming | USD Equivalent     |
|----------|--------------------|----------|----------|--------------------|
| USD      | 41,666,036,019.88  | 200,000  | —        | 41,666,036,019.88  |

> Other 72 currencies have zero balance.
```

### Chinese

```
**投资法币明细**（账户：{holderCode}）

| 币种 | 可用余额             | 待处理   | 待入账 | USD 等值             |
|-----|---------------------|---------|-------|---------------------|
| USD | 41,666,036,019.88   | 200,000 | —     | 41,666,036,019.88   |

> 其他 72 个币种余额为 0。
```

---

## Quarantine Detail (from `get_account_detail`, productCode=quarantine_portfolio)

Same display rules. If all currencies have zero balance, show a simplified message:

### English

```
**Quarantine Detail** (Account: {holderCode})

> No quarantined assets.
```

### Chinese

```
**隔离资产明细**（账户：{holderCode}）

> 无隔离资产。
```

If any currency has a non-zero balance, display the full table as with other account types.

---

## Investment Products Detail (from `get_account_detail`, productCode=investment_product)

Same display rules. Note: some instruments may have `productCode: null` (e.g. `DFRAIS001`, `Primo_Link`) — display them like any other currency.

### English

```
**Investment Products Detail** (Account: {holderCode})

| Currency    | Available    | Pending | Incoming | USD Equivalent |
|-------------|------------- |---------|----------|----------------|
| USD         | 1,165,544.00 | 11      | —        | 1,165,544.00   |
| Primo_Link  | 998,000.00   | —       | —        | 998,000.00     |
| DFRAIS001   | 136.00       | 114     | —        | 136.00         |

> Other 70 currencies have zero balance.
```

### Chinese

```
**投资产品明细**（账户：{holderCode}）

| 币种        | 可用余额      | 待处理 | 待入账 | USD 等值      |
|------------|-------------|-------|-------|--------------|
| USD        | 1,165,544.00| 11    | —     | 1,165,544.00 |
| Primo_Link | 998,000.00  | —     | —     | 998,000.00   |
| DFRAIS001  | 136.00      | 114   | —     | 136.00       |

> 其他 70 个币种余额为 0。
```

---

## Available Currency Pairs (from `get_available_currency_pairs`)

### Filtering & Grouping

All pairs are displayed, including internal currencies (`Primo_Link`, `PX-First`).
Every pair returned by `get_available_currency_pairs` is bidirectional — both BASE→QUOTE and QUOTE→BASE swaps are supported. Render each returned entry with Direction = "Bidirectional" / "双向" without checking for the reverse string in the list:

### English

```
**Available Currency Pairs**

| Pair       | Direction     |
|------------|---------------|
| USD / USDC | Bidirectional |
| USD / FDUSD| Bidirectional |
| SGD / HKD  | Bidirectional |
| GBP / USDT | Bidirectional |
| JPY / EUR  | Bidirectional |
| HKD / EUR  | Bidirectional |
```

### Chinese

```
**可用币对**

| 币对        | 方向 |
|------------|------|
| USD / USDC | 双向 |
| USD / FDUSD| 双向 |
| SGD / HKD  | 双向 |
| GBP / USDT | 双向 |
| JPY / EUR  | 双向 |
| HKD / EUR  | 双向 |
```

---

## Output Order

1. Account Overview table (from `get_account_summary`)
2. Fiat Account Detail (from `get_account_detail`, productCode=fiat)
3. Cryptocurrency Detail (from `get_account_detail`, productCode=crypto)
4. Investment Fiat Detail (from `get_account_detail`, productCode=investment_fiat)
5. Quarantine Detail (from `get_account_detail`, productCode=quarantine_portfolio)
6. Investment Products Detail (from `get_account_detail`, productCode=investment_product)
7. Available Currency Pairs (from `get_available_currency_pairs`)
8. Ask the user
