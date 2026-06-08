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

⚠ **The final rate is locked at the moment you confirm**, so due to market movement it may differ slightly from the rate shown above. This quote is valid for about **{validity_window}** — please confirm within that time.

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

⚠ **汇率以确认时刻的实际成交价为准。** 因市场波动，最终成交汇率可能与此处显示略有不同。本报价有效期约 **{validity_window}**，请在有效期内完成确认。

**确认执行？（是 / 否）**
```

### Variable mapping

| Variable | Source |
|---|---|
| `holderCode` | `get_account_detail` → `data.holderCode` (e.g. `A0102634`) |
| `productCode_label` | Map by productCode: `fiat` → "Fiat Account" / "法币账户"; `crypto` → "Cryptocurrency" / "加密货币"; `investment_fiat` → "Investment Fiat" / "投资法币"; `investment_product` → "Investment Products" / "投资产品"; `quarantine_portfolio` → "Quarantine" / "隔离资产" |
| `source_amount` / `target_amount` | Parsed from user input + exchange rate calculation |
| `rate` | From `get_otc_quote` → `exchangeRate` (string). This is the locked rate displayed to the user. **If `exchangeRate` is an empty string (`""`), the rate is currently unavailable — do NOT render this confirmation page and do NOT call `confirm_otc_trade`. Tell the user the rate is unavailable and return to currency selection.** |
| `validity_window` | Human-readable validity duration from `get_otc_quote` → `validityPeriod`, **which is in SECONDS**. The `⚠` template already supplies "about / 约", so this value carries **no** leading "约"/"about"/"~". Convert: under 60 → "{validityPeriod} seconds / {validityPeriod} 秒"; otherwise minutes = `validityPeriod / 60` to at most one decimal, trailing `.0` trimmed → "{minutes} minutes / {minutes} 分钟" (e.g. `90` → "1.5 minutes / 1.5 分钟"; `120` → "2 minutes / 2 分钟"; `30` → "30 seconds / 30 秒"). **Never** render `90` as "90 minutes". If `validityPeriod` is missing, use the absolute `expiry` timestamp in the user's local time instead (e.g. "until 16:31 / 截至 16:31"). |

### Rules
- `source_amount` and `target_amount` must include thousands separators
- If `direction=target` (user specified target amount): `source_amount` is estimated with ≈ prefix
- If `direction=source` (user specified source amount): `target_amount` is estimated with ≈ prefix
- The non-estimated amount is displayed without ≈
- If `get_exchange_quote` fails for this pair: show "Rate to be determined at execution" / "汇率将在执行时确定" instead of a rate value
- **MANDATORY — confirmation notice with validity window:** The `⚠` line (rate locked at confirm time + **how long the quote stays valid**, `{validity_window}`) MUST be rendered (in the user's language) immediately below the confirmation table and above the Yes/No prompt, with `{validity_window}` filled from the quote. Never omit it, drop the validity window, or move it into a tooltip/footnote — telling the user how long they have is a user-facing commitment. Do NOT add back any "if the rate drifts beyond tolerance the confirmation will fail" wording; the actual 409/410 timing failure is handled separately by the Rate-timing failure message below.
- **Unit guard — `validityPeriod` is in SECONDS.** When filling `{validity_window}`, never render the raw `validityPeriod` number as minutes; follow the conversion in the variable-mapping row (under 60 → seconds; otherwise `validityPeriod/60` to one decimal). A `validityPeriod` of `90` is 90 seconds = 1.5 minutes, never 90 minutes. The template already says "about / 约", so don't repeat it in the value.

---

## Success Message (STEP 5c — Success)

Display when `confirm_otc_trade()` succeeds (returns flat fields — no `success`/`data` envelope).

The execute response provides:
- `tradeCode` — transaction reference
- `point` — loyalty points earned (decimal string). Display in the success message verbatim (e.g., `🏅 +{point} points`); do not parse as a number.
- `exchangeRate` / `finalAmount` (optional) — actual settled rate and amount; see the priority rule below.

After execution succeeds, call `get_otc_trade_detail({ "tradeCode": "{tradeCode}" })` to get full settled details.

### Deriving Paid / Received — use STEP 5a quote data, NOT trade-detail action/base/quote

**ABSOLUTE RULE — Single source of truth for user-facing amounts:**

The `get_otc_quote` response captured in STEP 5a is the authoritative source for the displayed Paid / Received / Rate fields. It is already expressed in the user's direction — `fromCurrency` is what the user paid, `toCurrency` is what the user received. Do NOT route these through `trade.tradingAction` / `trade.baseCurrency` / `trade.quoteCurrency` / `trade.baseQuantity` / `trade.quoteAmount`, which encode the internal trading-pair direction and often do not match the user's from→to intent.

Derivation (use STEP 5a fields directly):

| Display field | 优先源 | 回退源（confirm 响应字段缺失时） |
|---|---|---|
| `paid_currency` | 5a `fromCurrency` | — |
| `paid_amount`   | 5a `totalValue` | — |
| `received_currency` | 5a `toCurrency` | — |
| `received_amount`   | **5c `confirm_otc_trade.finalAmount`**（实际成交） | `5a totalValue × 5a exchangeRate`，加 ≈ 前缀 |
| `rate_display`  | **5c `confirm_otc_trade.exchangeRate`**，渲染为 `1 {fromCurrency} = {exchangeRate} {toCurrency}` | 5a 同样格式，加"预估"标注 |

`get_otc_trade_detail` is consulted ONLY for metadata the 5a response does not carry:
- `trade.tradeCode` → Reference number
- `trade.tradeStatus` → status label (see mapping below)
- `trade.tradeTime` / `trade.settleTime` → timestamps
- `point` (from `confirm_otc_trade` response) → points earned

Ignore `trade.tradingAction`, `trade.baseCurrency`, `trade.quoteCurrency`, `trade.baseQuantity`, `trade.quoteAmount`, `trade.finalPrice` for user-facing display. They are valid accounting records but are in the trading-pair's native direction and mislead a direction-agnostic renderer.

**Never write a thinking block debating "does tradingAction=1 mean paid = baseQuantity or quoteAmount here" — just use 5a's `fromCurrency` / `toCurrency` / `totalValue` / `exchangeRate`.** If the reasoning chain starts second-guessing intent vs. tradingAction, STOP and re-read this rule. The trade executed at the rate and amount the user saw in STEP 5b; there is nothing to recompute from trade-detail.

**新规则（2026-04-28 起）：** confirm 响应里的 `exchangeRate` / `finalAmount` 是权威成交值，优先级**高于** 5a quote 数据。仅当 confirm 响应缺这些字段时回退到 5a 计算并加 ≈ / "预估" 标注。

Status mapping: `trade.tradeStatus: 1` → "Application successful (pending settlement)" / "申请成功（待结算）"; `trade.tradeStatus: 2` → "Settled" / "已结算"; `trade.tradeStatus: 3` → "Cancelled" / "已取消". Any other value (including a missing or `0` status on a just-placed trade) → "Application successful (processing)" / "申请成功（处理中）" — the trade was just confirmed, so treat an unmapped status as in-progress; never surface the raw numeric code or invent a failed/unknown state.

### With `trade` returned (full info — preferred)

#### English

One-line summary (lead with this, always):

```
✅ Execution successful: your MetaComp account {holderCode}, at {trade.tradeTime},
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
| Status | {status_label derived from trade.tradeStatus} |
| Points earned | {point} |
| Time | {trade.tradeTime} |
| Reference | {trade.tradeCode} |
```

#### Chinese

One-line summary (lead with this, always):

```
✅ 执行成功，您的 MetaComp 账户 {holderCode}，在 {trade.tradeTime}，
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
| 状态 | {status_label 由 trade.tradeStatus 映射} |
| 获得积分 | {point} |
| 时间 | {trade.tradeTime} |
| 参考编号 | {trade.tradeCode} |
```

### Without `trade` (fallback — `get_otc_trade_detail` returned `trade: null` or the call failed)

Paid / Received / Rate still come from STEP 5a (`get_otc_quote`) — those fields are accurate because the trade executed at the locked quote. Only the *status label and server-side timestamps* are unavailable in this fallback; mark the received amount with `≈` and omit the Status / Time rows (keep `Reference` from `tradeCode`).

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
- With `trade` returned: Paid/Received/Rate are always derived from STEP 5a quote data (`fromCurrency`/`toCurrency`/`totalValue`/`exchangeRate`); they are presented as **actual** server values, no ≈ prefix. Trade-detail amounts (`baseQuantity`, `quoteAmount`, `finalPrice`) are supplementary "settled" info only and must NOT drive the displayed Paid/Received/Rate fields.
- Without `trade` returned: use the pre-execution estimate from `get_exchange_quote` (STEP 5) for received amount and rate, prefixed with ≈; do NOT use `point` to calculate received amount
- Timestamp: from `trade.tradeTime` when available; otherwise omit (do not fabricate)
- Format all amounts with thousands separators (e.g. 10,000 not 10000)

---

## Failure Message (STEP 5c — Failure)

Display when `confirm_otc_trade()` returns an error.

### Rate-timing failures (quote expired / used / not found, or price drift) — redirect to web portal

These are the expected failure modes when the locked quote can no longer be settled at confirm time: **HTTP 410** quote expired, **HTTP 409** price drift, or a "quote info not found / quote already used / `quoteInfoNotFound`" signal (the quote was consumed or aged out at the trade core). Treat all of these as quote-no-longer-valid — **NOT** as a server outage, even if the raw status looks like a 4xx/5xx. **Do NOT re-quote, do NOT call `get_otc_quote` again, do NOT auto-retry `confirm_otc_trade`, do NOT return to STEP 3C.** Output the message below verbatim (user's language; keep the URL `https://camp.mce.sg/` byte-for-byte), then ⛔ **STOP**.

#### English

```
❌ **Exchange not completed**

The rate could not be settled in time (the quote expired or the market moved beyond tolerance).

Please complete this exchange on the MetaComp web portal, where the rate is locked at the moment of execution:

**[MetaComp](https://camp.mce.sg/)**
```

#### Chinese

```
❌ **换汇未完成**

报价未能在有效时间内成交（报价已过期或市场波动超出容忍度）。

请前往 MetaComp 网页端完成本次换汇，网页端在成交瞬间锁定汇率：

**[MetaComp](https://camp.mce.sg/)**
```

### Other failures

For non-rate-timing errors, display:

#### English

```
❌ **Exchange Failed**

**Reason:** {error_message}

{suggestion based on error type}
```

#### Chinese

```
❌ **换汇失败**

**原因：** {error_message}

{根据错误类型给出建议}
```

### Error-specific suggestions

| Error type | Suggestion |
|---|---|
| Insufficient balance | "Please top up your {currency} account or choose a different source currency." |
| Rate expired / changed / `quote expired` / `QUOTE_EXPIRED` / quote used / not found / `quoteInfoNotFound` / "Quote Info Not Found" / HTTP 410 / price drift / `PRICE_DRIFT_EXCEEDED` | Use the **Rate-timing failures** block above — redirect to `https://camp.mce.sg/`. Do NOT offer to re-quote or retry, and do NOT report it as a service outage. |
| Pair unavailable | "This currency pair is temporarily unavailable. Please try again later." |
| Session expired | Show authPageUrl login link (same as STEP 1 Case B) |
| Unknown / other | "Please try again. If the issue persists, contact support at metacomp.ai." |

### Rules
- Never expose raw error codes or stack traces to the user
- Map server error codes to user-friendly messages
- For rate-timing failures (quote expired / price drift), redirect to `https://camp.mce.sg/` — never re-quote or auto-retry
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
