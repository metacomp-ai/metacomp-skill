# Swap Confirmation & Result Specification

This sub-skill defines how to present the confirmation page, success message, and failure message.

> **Token Guard applies to every MCP call referenced by this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## Confirmation Page (STEP 5)

Display when all validations pass, before execution.

### English

```
**Exchange Confirmation**

| | |
|---|---|
| Account | {holderCode} |
| Source | {productCode_label} ({source_currency}) |
| You pay | {source_amount} {source_currency} |
| You receive | ≈ {target_amount} {target_currency} |
| Exchange rate | 1 {source_currency} = {rate} {target_currency} |
| Fee | None |

⚠ **Rate valid for 60 seconds.** Please confirm whether to proceed within **60 seconds** — if you do not confirm in time, the quoted rate will expire and the final rate will be re-quoted at execution.

**Confirm execution? (Yes / No)**
```

### Chinese

```
**换汇确认**

| | |
|---|---|
| 账户 | {holderCode} |
| 源账户 | {productCode_label}（{source_currency}） |
| 支出 | {source_amount} {source_currency} |
| 获得 | ≈ {target_amount} {target_currency} |
| 汇率 | 1 {source_currency} = {rate} {target_currency} |
| 手续费 | 无 |

⚠ **汇率有效期 60 秒。** 请在 **60 秒内** 确认是否交易，超时后此报价将失效，最终汇率以执行时重新报价为准。

**确认执行？（是 / 否）**
```

### Variable mapping

| Variable | Source |
|---|---|
| `holderCode` | `get_account_detail` → `data.holderCode` (e.g. `A0102634`) |
| `productCode_label` | Map by productCode: `fiat` → "Fiat Account" / "法币账户"; `crypto` → "Cryptocurrency" / "加密货币"; `investment_fiat` → "Investment Fiat" / "投资法币"; `investment_product` → "Investment Products" / "投资产品"; `quarantine_portfolio` → "Quarantine" / "隔离资产" |
| `source_amount` / `target_amount` | Parsed from user input + exchange rate calculation |
| `rate` | From `get_otc_quote` → `exchangeRate` (string). NEVER use `finalPrice` — that is internal. This is the locked rate displayed to the user. |

### Rules
- `source_amount` and `target_amount` must include thousands separators
- If `direction=target` (user specified target amount): `source_amount` is estimated with ≈ prefix
- If `direction=source` (user specified source amount): `target_amount` is estimated with ≈ prefix
- The non-estimated amount is displayed without ≈
- If `get_exchange_quote` fails for this pair: show "Rate to be determined at execution" / "汇率将在执行时确定" instead of a rate value
- **MANDATORY — 60-second confirmation notice:** The `⚠` line about the 60-second rate validity window MUST be rendered verbatim (in the user's language) immediately below the confirmation table and above the Yes/No prompt. Never omit, shorten, paraphrase away, or move it into a tooltip/footnote. This notice is a user-facing commitment — skipping it is a bug.

---

## Success Message (STEP 5c — Success)

Display when `confirm_otc_trade()` returns `success: true`.

The execute response provides:
- `data.tradeCode` — transaction reference
- `data.point` — expected points earned (for waiving withdrawal fees and other benefits; NOT the exchange rate)

After execution succeeds, call `get_otc_trade_detail({ "tradeCode": "{data.tradeCode}" })` to get full settled details.

### Deriving Paid / Received — use STEP 5a quote data, NOT trade-detail action/base/quote

**ABSOLUTE RULE — Single source of truth for user-facing amounts:**

The `get_otc_quote` response captured in STEP 5a is the authoritative source for the displayed Paid / Received / Rate fields. It is already expressed in the user's direction — `fromCurrency` is what the user paid, `toCurrency` is what the user received. Do NOT route these through `trade.action` / `trade.tradingPair` / `trade.baseQuantity` / `trade.quoteAmount`, which encode the internal trading-pair direction and often do not match the user's from→to intent.

Derivation (use STEP 5a fields directly):

| Display field | Source | Value |
|---|---|---|
| `paid_currency` | 5a | `fromCurrency` |
| `paid_amount`   | 5a | `totalValue` |
| `received_currency` | 5a | `toCurrency` |
| `received_amount`   | compute | `totalValue × exchangeRate` (both from 5a), rounded to the target currency's display precision |
| `rate_display`  | 5a | `1 {fromCurrency} = {exchangeRate} {toCurrency}` |

`get_otc_trade_detail` is consulted ONLY for metadata the 5a response does not carry:
- `trade.tradeCode` → Reference number
- `trade.status` → status label (see mapping below)
- `trade.createAt` / `trade.settleAt` → timestamps
- `data.point` (from `confirm_otc_trade` response) → points earned

Ignore `trade.action`, `trade.tradingPair`, `trade.baseQuantity`, `trade.quoteAmount`, `trade.finalQuote` for user-facing display. They are valid accounting records but are in the trading-pair's native direction and mislead a direction-agnostic renderer.

**Never write a thinking block debating "does action=1 mean paid = baseQuantity or quoteAmount here" — just use 5a's `fromCurrency` / `toCurrency` / `totalValue` / `exchangeRate`.** If the reasoning chain starts second-guessing intent vs. action, STOP and re-read this rule. The trade executed at the rate and amount the user saw in STEP 5b; there is nothing to recompute from trade-detail.

Status mapping: `trade.status: 1` → "Application successful (pending settlement)" / "申请成功（待结算）"; `trade.status: 4` → "Settled" / "已完成".

### With `trade` returned (full info — preferred)

#### English

One-line summary (lead with this, always):

```
✅ Execution successful: your MetaComp account {holderCode}, at {trade.createAt},
spent {paid_amount} {paid_currency} to exchange for {received_amount} {received_currency} — application successful.
```

Then a detail table:

```
| | |
|---|---|
| Account | {holderCode} |
| Paid | {paid_amount} {paid_currency} |
| Received | {received_amount} {received_currency} |
| Final rate | {rate_display} |
| Status | {status_label derived from trade.status} |
| Points earned | {point} |
| Time | {trade.createAt} |
| Reference | {trade.tradeCode} |
```

#### Chinese

One-line summary (lead with this, always):

```
✅ 执行成功，您的 MetaComp 账户 {holderCode}，在 {trade.createAt}，
花费 {paid_amount} {paid_currency} 兑换 {received_amount} {received_currency} 申请成功。
```

Then a detail table:

```
| | |
|---|---|
| 账户 | {holderCode} |
| 支出 | {paid_amount} {paid_currency} |
| 获得 | {received_amount} {received_currency} |
| 成交汇率 | {rate_display} |
| 状态 | {status_label 由 trade.status 映射} |
| 获得积分 | {point} |
| 时间 | {trade.createAt} |
| 参考编号 | {trade.tradeCode} |
```

### Without `trade` (fallback — `get_otc_trade_detail` returned `trade: null` or the call failed)

Paid / Received / Rate still come from STEP 5a (`get_otc_quote`) — those fields are accurate because the trade executed at the locked quote. Only the *status label and server-side timestamps* are unavailable in this fallback; mark the received amount with `≈` and omit the Status / Time rows (keep `Reference` from `data.tradeCode`).

#### English

```
✅ Execution successful: your MetaComp account {holderCode} — reference {tradeCode}.
Full settlement details will be available shortly.
```

```
| | |
|---|---|
| Account | {holderCode} |
| Paid | {totalValue} {fromCurrency} |
| Received | ≈ {estimated target amount from STEP 5 quote} {toCurrency} |
| Estimated rate | 1 {fromCurrency} = {rate from STEP 5 quote} {toCurrency} |
| Points earned | {point} |
| Reference | {tradeCode} |

ℹ For complete transaction details, check your account at metacomp.ai.
```

#### Chinese

```
✅ 执行成功，您的 MetaComp 账户 {holderCode} — 参考编号 {tradeCode}。完整结算详情稍后可查询。
```

```
| | |
|---|---|
| 账户 | {holderCode} |
| 支出 | {totalValue} {fromCurrency} |
| 获得 | ≈ {STEP 5 预估目标金额} {toCurrency} |
| 预估汇率 | 1 {fromCurrency} = {STEP 5 汇率} {toCurrency} |
| 获得积分 | {point} |
| 参考编号 | {tradeCode} |

ℹ 完整交易详情请登录 metacomp.ai 查看。
```

### Rules
- Always lead with the one-line summary (用户想看一眼就懂). Then show the table for details.
- `tradeCode` always displayed — this is the user's receipt
- `point` is **expected points earned** (not exchange rate) — always display as "Points earned" / "获得积分"
- With `trade` returned: all amounts and rates are **actual** server values, no ≈ prefix. Paid/Received derived from `action` + `tradingPair` + `baseQuantity` + `quoteAmount` per the mapping table above.
- Without `trade` returned: use the pre-execution estimate from `get_exchange_quote` (STEP 5) for received amount and rate, prefixed with ≈; do NOT use `point` to calculate received amount
- Timestamp: from `trade.createAt` when available; otherwise omit (do not fabricate)
- Format all amounts with thousands separators (e.g. 10,000 not 10000)

---

## Failure Message (STEP 5c — Failure)

Display when `confirm_otc_trade()` returns an error.

### English

```
❌ **Exchange Failed**

**Reason:** {error_message}

{suggestion based on error type}
```

### Chinese

```
❌ **换汇失败**

**原因：** {error_message}

{根据错误类型给出建议}
```

### Error-specific suggestions

| Error type | Suggestion |
|---|---|
| Insufficient balance | "Please top up your {currency} account or choose a different source currency." |
| Rate expired / changed | "The exchange rate has changed. Would you like to retry with the current rate?" |
| Pair unavailable | "This currency pair is temporarily unavailable. Please try again later." |
| Session expired | Show authPageUrl login link (same as STEP 1 Case B) |
| Unknown / other | "Please try again. If the issue persists, contact support at metacomp.ai." |

### Rules
- Never expose raw error codes or stack traces to the user
- Map server error codes to user-friendly messages
- For retryable errors, offer to retry
- For session errors, link back to the login flow

---

## Cancellation Message

Display when user declines at the confirmation step.

### English
```
Exchange cancelled. No changes have been made to your account.
```

### Chinese
```
换汇已取消，账户未发生任何变动。
```
