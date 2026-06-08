# Swap scenario

Entered from SKILL.md after the shared STEP 1 (`../shared/auth-kyc-setup.md`) verified the session via `get_account_summary`. Swap uses its **own** account display (`account-display.md`, with currency pairs + all-5-productCode detail) rather than the shared `account-overview.md`. This file is STEP 2 onward.

> If `get_account_summary` already succeeded in shared STEP 1, do not re-call it; proceed to STEP 2.

---

# STEP 2 — Fetch pairs + account detail

Call in **parallel**:
1. `get_available_currency_pairs()`
2. `get_account_detail` for **all** productCodes: `fiat`, `crypto`, `investment_fiat`, `quarantine_portfolio`, `investment_product`

→ Any call returns `success: false` with `authPageUrl` → Token Guard (SKILL.md), show login link, STOP.
→ All succeed → STEP 3.

**IMPORTANT — Swap-eligible accounts:** Only `fiat` and `crypto` can be source accounts for exchange. The other three (`investment_fiat`, `quarantine_portfolio`, `investment_product`) are display-only and MUST NOT be used as swap sources.

Key data from `get_account_detail`:
- `data.holderCode` — account identifier (e.g. `A0102634`), used on the confirmation page.
- `data.instrumentInfoMap` — per-currency breakdown. **Do not hardcode** which currencies belong to which productCode — each user differs.
- Build a unified lookup by merging `instrumentInfoMap` across productCodes. A currency may appear in multiple productCodes; record `availableAmount` / `pendingAmount` / `pendingCreditAmount` per (currency, productCode). **Do NOT sum across productCodes** — they are separate accounts.
- When validating swap balance (STEP 4C), only check `fiat` + `crypto`.
- Display filter: show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`.

---

# STEP 3 — Display Data & Ask User

Present per `account-display.md`, then ask.

## 3A — Account Overview
Display the account summary (from shared STEP 1's `get_account_summary`).

## 3B — Available Currency Pairs
Display available pairs. Every returned pair is bidirectional — see `account-display.md` for the table format. **Do NOT show an exchange-rate column here** — real rates come at STEP 5 (the quote). Showing rates now would mislead since they fluctuate.

## 3C — Ask the user
> How would you like to exchange? For example: "Exchange USD for 10,000 SGD"

⛔ **STOP.** Wait. Do not assume, guess, or pre-fill values.

**Wealth Evaluation Gate (on no-intent reply):** when the user's reply to 3C contains no valid swap intent (no currencies, no amount, no direction — balance curiosity / abandonment / exploration), evaluate `WEALTH_RECOMMENDATION_TRIGGER` (`../shared/wealth-recommendation.md`) BEFORE re-asking 3C. If TRUE, render the recommendation, then re-ask 3C. If the reply IS a valid swap intent → STEP 4, no recommendation. (See SKILL.md → Wealth Evaluation Gate.)

---

# STEP 4 — Parse Intent & Validate

## 4A — Parse
Extract `source_currency`, `target_currency`, `amount`, `direction` (is `amount` the source or target?).
- "I want to exchange 10,000 SGD" → `target_currency=SGD`, `amount=10000`, `direction=target`
- "spend 10,000 USD to buy SGD" → `source_currency=USD`, `amount=10000`, `direction=source`
- Ambiguous (can't determine source/target) or only one currency mentioned → **ASK**. Do not infer.

## 4B — Validate pair available
Each pair is bidirectional. Check if **either** `{source}/{target}` **or** `{target}/{source}` exists in the pairs list. Treat both as available.
→ Not available: tell the user, list available pairs, ⛔ **STOP**, re-validate from 4B after they choose.
→ Available: 4C.

## 4C — Resolve source amount & productCode

**Swap range probe (do this once `source_currency` + `target_currency` are known).** Call `get_swap_range({ fromCurrency: source_currency, toCurrency: target_currency })`:
- `{ success: false }` → the pair is unsupported. Tell the user and return to 3C. (This also serves as pair validation, including for `direction=source`.)
- Otherwise record `swap_min` / `swap_max` (both in `source_currency`, either may be `null`). For `direction=target`, this probe and `get_exchange_quote` can run in parallel.

Show the range to the user when asking for / confirming the amount (in `source_currency`):
- both present: `可兑换 {swap_min}~{swap_max} {source_currency}。/ You can swap between {swap_min} and {swap_max} {source_currency}.`
- only `swap_max`: `最多可兑换 {swap_max} {source_currency}。/ You can swap up to {swap_max} {source_currency}.`
- only `swap_min`: `至少需 {swap_min} {source_currency}。/ At least {swap_min} {source_currency} is required.`
- both `null`: omit the range line.

1. `direction=target` → call `get_exchange_quote({ fromCurrency: source, toCurrency: target })`; compute `totalValue = target_amount / rate`. If quote indicates an unsupported pair, tell the user, return to 3C.
2. `direction=source` → `totalValue` is the stated amount.
3. Resolve `source_productCode`: filter swap-eligible accounts (`fiat`/`crypto` only) holding `source_currency`. Exactly one → use it. Zero → tell the user it's not held on a swap-eligible account, return to 3C. Multiple → ask which account to debit.

### Balance — early check only when the source amount is exact (Funds-First Gate)

The rule depends on `direction`, because the risk a pre-check guards against is comparing balance to an amount derived from an **unlocked** rate:

- **`direction=source`** — `totalValue` IS the user's stated source amount; no rate is involved, so the comparison is exact. Do the early check now (SKILL.md → Funds-First Gate, checkpoint 1): read `available` for `source_currency` in the resolved `source_productCode` from the STEP 2 `get_account_detail` (re-fetch if a Token Guard re-login happened). If `available` is `0` / the currency is absent, or `BigNumber(totalValue).gt(available)`:
  > Your available {source_currency} balance is {available}, which doesn't cover {totalValue} {source_currency}. Enter a smaller amount or a different pair. / 您的 {source_currency} 可用余额为 {available}，不足以兑换 {totalValue} {source_currency}。请输入更小的金额或换一个币对。

  Return to 3C — don't lock a quote that can't settle.
- **`direction=target`** — `totalValue` was back-computed from the **unlocked browse rate** (`get_exchange_quote`), so a balance comparison here can mislead (the real source amount is only known once `get_otc_quote` locks the rate at 5a). Do NOT pre-check; rely on the 5a lock, which validates balance server-side before any confirm/execute.

Either way, `get_otc_quote` (5a) remains the authoritative backstop: it locks the rate and rejects an underfunded swap **before** the 5b confirmation and 5c execute, so the user never confirms or commits a doomed trade.

### Swap-range pre-check (local, before STEP 5a)

Once `totalValue` is resolved (for `direction=target`, this is the rate-derived source amount), compare it against the probed range — in addition to the balance check:
- `swap_min` present and `BigNumber(totalValue).lt(swap_min)` →
  > 金额低于最小可兑换额 {swap_min} {source_currency},请重新输入。/ Amount is below the minimum {swap_min} {source_currency}. Please enter a larger amount.
- `swap_max` present and `BigNumber(totalValue).gt(swap_max)` →
  > 金额超出最大可兑换额 {swap_max} {source_currency},请重新输入。/ Amount exceeds the maximum {swap_max} {source_currency}. Please enter a smaller amount.

Re-ask for the amount in place; do NOT call `get_otc_quote`. If both bounds are `null`, skip this pre-check. STEP 5a server-side validation remains the final authority.

---

# STEP 5 — Lock Quote, Confirm, Execute (5a → 5b → 5c, in order; never skip 5b)

## 5a — Lock
`get_otc_quote({ fromCurrency: source, toCurrency: target, totalValue: <from 4C, STRING> })`
- **Failure `{ success:false, message }`** → show `message` (translated), return to 3C. **Do NOT auto-retry.**
- **Success** → `{ quoteCode, exchangeRate, finalAmount, validityPeriod, expiry, fromCurrency, toCurrency, totalValue }`. Keep `quoteCode` for 5c. `exchangeRate`/`finalAmount` MAY be `""` when pricing is temporarily unavailable — handle per the rate-unavailable rule. **`validityPeriod` is in SECONDS** (e.g. `90` = 90 seconds, not 90 minutes); `expiry` is an absolute ISO-8601 UTC timestamp.

## 5b — Confirmation page
Render per `swap-confirm.md`.
- **Rate unavailable:** if `exchangeRate === ""`, tell the user the rate is currently unavailable for `{from}/{to}`, suggest retry / different pair, **do NOT call `confirm_otc_trade`**, return to 3C.
- **Rate display:** when non-empty, show `exchangeRate` from `get_otc_quote` (the 5a-locked value is authoritative — do NOT reuse the 3B browse-time rate).
- **Rate validity window:** MUST include the `⚠` notice (per `swap-confirm.md`) in the user's language, and it MUST state **how long the quote is valid** (`{validity_window}`). Compute it from `validityPeriod`, which is in **SECONDS** — under 60s say "{validityPeriod} seconds / 秒", otherwise `validityPeriod/60` to one decimal "+ minutes / 分钟" (see `swap-confirm.md` → `validity_window`); never relabel the raw seconds as minutes (`90` = 90 **seconds** = 1.5 min, not 90 minutes). If `validityPeriod` is missing, use the absolute `expiry` timestamp. The notice no longer claims the confirmation will fail on drift — the real 409/410 timing failure is handled at 5c.
- **Explicit confirmation required** — never auto-confirm.

⛔ **STOP.** Wait. Cancel / change → return to 3C (the locked quote expires on its own).

## 5c — Execute after confirmation
`confirm_otc_trade({ quoteCode: <from 5a> })`

**Success** (`{ id, tradeCode, point, exchangeRate, finalAmount }` — flat, no envelope): show success per `swap-confirm.md`, then call `get_otc_trade_detail({ tradeCode })`.

**ABSOLUTE RULE — use STEP 5a quote data for user-facing amounts:**
- `paid_amount` = `totalValue` (5a), `paid_currency` = `fromCurrency` (5a)
- `received_amount` = `totalValue × exchangeRate` (both 5a), `received_currency` = `toCurrency` (5a)
- `rate_display` = `1 {fromCurrency} = {exchangeRate} {toCurrency}`

`get_otc_trade_detail` is consulted ONLY for metadata: `trade.tradeCode`, `trade.tradeStatus`, `trade.tradeTime`, `trade.settleTime`. **Ignore `trade.tradingAction` / `baseCurrency` / `quoteCurrency` / `baseQuantity` / `quoteAmount` / `finalPrice` for display** — they encode internal pair direction and frequently don't match the user's from→to intent. The trade already executed at the price shown in 5b; nothing to rederive. If your reasoning starts debating "does tradingAction=1 mean paid=baseQuantity or quoteAmount" — STOP, discard, use 5a data.

**Failures:** Token Guard first (401/expired → SKILL.md). **Rate-timing failures** (HTTP 410 quote expired / HTTP 409 price drift / quote used / not found / `quoteInfoNotFound` / "Quote Info Not Found" / any "quote expired" / "price drift" message) → do **NOT** re-quote, do **NOT** re-lock, do **NOT** return to 3C, and do **NOT** report it as a server outage. Tell the user the quote could not be settled in time and direct them to complete the exchange on the MetaComp web portal at `https://camp.mce.sg/` (render per `swap-confirm.md` → Failure Message), then ⛔ **STOP**. Any other error → surface `message`, return to 3C.

---

# Final Response Gate (swap)

```
☐ STEP 2: pairs + all 5 productCode details fetched? errors handled?
☐ STEP 3: account overview + available pairs displayed? asked 3C? STOP?
☐ STEP 4: source/target/amount/direction parsed? ambiguous → asked? pair validated? direction=target → get_exchange_quote? source productCode resolved? balance handled per direction (direction=source → early exact check; direction=target → deferred to 5a lock, no pre-check on the unlocked rate)?
☐ STEP 5a: get_otc_quote with totalValue as STRING (fromCurrency amount)? on failure showed message + returned to 3C, no auto-retry? preserved quoteCode/exchangeRate/fromCurrency/toCurrency/totalValue?
☐ STEP 5b: confirmation per swap-confirm.md? rate = exchangeRate string? ⚠ validity notice in user's language? STOP, waited for explicit confirm, no auto-confirm?
☐ STEP 5c: only after explicit confirm? confirm_otc_trade with quoteCode? get_otc_trade_detail for metadata? Paid/Received/Rate from 5a data NOT trade.tradingAction/baseQuantity/quoteAmount/finalPrice? rate-timing failures (409/410) redirect to https://camp.mce.sg/ with NO re-quote/re-lock? other failures handled?
☐ Repeat-swap: a subsequent swap in this conversation runs the full flow from STEP 2, NOT refused as "one swap per conversation"?
```
Any unchecked → complete before ending.

---

# Tool Reference (swap)

- `get_available_currency_pairs()` → `{ pairs: ["USD/USDC", ...] }` (BASE/QUOTE, bidirectional).
- `get_account_detail({ productCode })` → `data.holderCode`, `data.instrumentInfoMap` (per-currency: `availableAmount`, `pendingAmount`, `pendingCreditAmount`, `availableAmountDisplay` — all strings).
- `get_exchange_quote({ fromCurrency, toCurrency })` → `{ rate }` (string; 1 from = `rate` to).
- `get_otc_quote({ fromCurrency, toCurrency, totalValue })` → `{ quoteCode, exchangeRate, finalAmount, validityPeriod, expiry, fromCurrency, toCurrency, totalValue }`. `exchangeRate` may be `""`. `validityPeriod` is in **seconds**; `expiry` is an absolute ISO-8601 UTC timestamp.
- `confirm_otc_trade({ quoteCode })` → `{ id, tradeCode, point, exchangeRate, finalAmount }`. Failures are MCP tool errors (409 = price drift, 410 = expired), not `success:false`.
- `get_otc_trade_detail({ tradeCode })` → `{ trade: {...} | null }`. Metadata only.

---

# Scenario Absolute Rules (swap)

## Repeat Swaps — Always Allowed
Each swap is an independent transaction. NO per-conversation limit. A second swap → run the full flow from STEP 2 with fresh data (balances/pairs/rates move). Never refuse with "already executed" / "duplicate" / "open a new conversation" — no such rule exists; that refusal is a hallucination. (The only one-per-conversation rule is the wealth recommendation, which does NOT apply to swaps.)

## Submit Gate
`confirm_otc_trade` is the write step — it runs only after an explicit user confirmation on the 5b page (never auto-confirm, never on pre-authorization). See SKILL.md → Token Guard for session handling.

---

# Scenario don'ts (swap)

- ❌ Do NOT execute a swap without explicit user confirmation (STEP 5b).
- ❌ Do NOT infer or guess currency, amount, or direction — ask if ambiguous.
- ❌ Do NOT provide financial advice or rate predictions.
- ✅ `Primo_Link` and `PX-First` are internal currencies — display them like any other currency.
- ✅ Every STOP waits for user input.
