# Account Overview + Per-Currency Detail (shared display spec)

Shared by the **deposit**, **withdraw**, and **wealth** scenarios. Rendered right after `get_account_summary` succeeds (STEP 1, Case C). This file defines the canonical layout so those scenarios render balances identically.

> **Swap uses a different display** — `../swap/account-display.md` (currency pairs + all-5-productCode detail), not this file. Don't apply this spec to swap.

---

## Part 1 — Account Overview (mandatory on STEP 1 success)

Use the data from `get_account_summary` directly. **All 6 rows must appear even if balances are zero. All 3 columns (Available, Pending, Total) must appear.** Zero values display as `0.00`, never as `—` or omitted. All amounts with thousands separators (e.g. `13,887,754,197.50`).

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
| Same-Name Account    | {named_account.availableAmount}   | {named_account.pendingAmount}   | {named_account.totalAmount}   |
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
| 同名账户 | {named_account.availableAmount}   | {named_account.pendingAmount}   | {named_account.totalAmount}   |
```

---

## Part 2 — Per-Currency Detail (from `get_account_detail`)

After the Account Overview, call `get_account_detail` for **fiat**, **crypto**, and **`named_account`** (in parallel if possible) to show per-currency balances from `data.instrumentInfoMap`.

> **Same-Name Account Detail is conditional.** Render the **Fiat** and **Cryptocurrency** detail sections as usual (always shown). For **`named_account`**, render the "Same-Name Account Detail" section **only if** its `instrumentInfoMap` has at least one currency with `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`. If every currency is zero, **omit the entire section** — no heading and no "Other N currencies have zero balance" line. (Users with no same-name funds see nothing extra.)

**Display rules:**
- **Only show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`** — skip zero-balance currencies
- `pendingCreditAmount > 0` means incoming funds awaiting confirmation — display in a separate "Incoming" column
- At the end, add: "Other {N} currencies have zero balance" (where N = total currencies − displayed currencies)
- Sort: non-zero currencies first, by `availableAmount` descending
- Zero values in the detail table display as `—` (not `0.00`)

### English

```
**Fiat Account Detail** (Account: {holderCode})

| Currency | Available          | Pending | Incoming | USD Equivalent     |
|----------|--------------------|---------|----------|--------------------|
| USD      | 10,000.00          | —       | —        | 10,000.00          |

> Other 35 currencies have zero balance.
```

```
**Cryptocurrency Detail** (Account: {holderCode})

| Currency | Available | Pending | Incoming | USD Equivalent |
|----------|-----------|---------|----------|----------------|
| USDT     | 80.00     | —       | 64.00    | 79.99          |

> Other 22 currencies have zero balance.
```

### Chinese

```
**法币账户明细**（账户：{holderCode}）

| 币种 | 可用余额    | 待处理 | 待入账 | USD 等值    |
|-----|-----------|-------|-------|-----------|
| USD | 10,000.00 | —     | —     | 10,000.00 |

> 其他 35 个币种余额为 0。
```

```
**加密货币明细**（账户：{holderCode}）

| 币种  | 可用余额 | 待处理 | 待入账 | USD 等值 |
|------|---------|-------|-------|---------|
| USDT | 80.00   | —     | 64.00 | 79.99   |

> 其他 22 个币种余额为 0。
```

### Same-Name Account Detail (conditional — see the rule at the top of Part 2)

Same columns, sorting, `—`-for-zero, non-zero-only filter, and "Other {N} currencies have zero balance" line as the Fiat detail above. `{holderCode}` comes from the `named_account` detail response. Render this section ONLY when the same-name account has a non-zero balance.

#### English

```
**Same-Name Account Detail** (Account: {holderCode})

| Currency | Available  | Pending | Incoming | USD Equivalent |
|----------|------------|---------|----------|----------------|
| USD      | 99,800.00  | —       | —        | 99,800.00      |

> Other 35 currencies have zero balance.
```

#### Chinese

```
**同名账户明细**（账户：{holderCode}）

| 币种 | 可用余额   | 待处理 | 待入账 | USD 等值   |
|-----|-----------|-------|-------|-----------|
| USD | 99,800.00 | —     | —     | 99,800.00 |

> 其他 35 个币种余额为 0。
```

### Data mapping

From `get_account_detail` response, for each entry in `instrumentInfoMap`:

| Display field  | Source field                      |
|----------------|-----------------------------------|
| Currency       | map key (currency code)           |
| Available      | `availableAmount` (0 → `—`)       |
| Pending        | `pendingAmount` (0 → `—`)         |
| Incoming       | `pendingCreditAmount` (0 → `—`)   |
| USD Equivalent | `availableAmountDisplay` (0 → `—`)|

---

## After the overview

Once Part 1 + Part 2 are rendered, the caller (SKILL.md money-flow branch) MUST evaluate the **Wealth Evaluation Gate** (`./wealth-recommendation.md` + the Gate in SKILL.md → Absolute Rules) **before** any closing message or scenario hand-off. The evaluation is mandatory; the render is non-blocking.
