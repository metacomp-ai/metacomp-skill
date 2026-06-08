# Swap scenario

Entered from SKILL.md after the shared STEP 1 (`../shared/auth-kyc-setup.md`) verified the session via `get_account_summary`. Swap uses its **own** account display (`account-display.md`) rather than the shared `account-overview.md`. This file is STEP 2 onward. **STEP 2 triages the triggering message's intent and branches (A/B/C/D)** — it renders the full overview + all-pairs only in branch D (no-intent); branches that already carry currency/pair intent fetch and show only what they need, then converge into STEP 4C.

> If `get_account_summary` already succeeded in shared STEP 1, do not re-call it; proceed to STEP 2.

---

# STEP 2 — Intent Triage & Branch

Parse the **triggering message** with the STEP 4A rules to extract `source_currency`, `target_currency`, `amount`, `direction`. Classify into exactly ONE branch and dispatch. All branches converge into **STEP 4C → STEP 5**.

> **"Return to 3C" for triage flows:** STEP 4C/STEP 5 error paths say "return to 3C". 3C is branch D's exchange-intent ask. For flows that originated in branch **A / B / C** (no 3C was rendered), "return to 3C" means **re-ask the exchange intent / re-run STEP 2 triage** with what is known — not "render branch D's 3C". The intent is the same: bounce back to asking how to exchange.

> **Token Guard on every call:** any fetch below returning `success: false` with `authPageUrl` → Token Guard (SKILL.md): stop, show login link, HARD STOP. Applies to all branches, before any branch-specific handling.

> **Swap-eligible accounts:** only `fiat` and `crypto` can be swap sources. `get_account_detail` for these two covers BOTH source-productCode resolution and the Funds-First balance check. The other three (`investment_fiat`, `quarantine_portfolio`, `investment_product`) are display-only and fetched ONLY in branch D.

## 2A — Classify

| Branch | Condition |
|---|---|
| **A** | both currencies present AND `direction` + `amount` resolvable |
| **B** | both currencies present but no `amount`, OR `amount` present but `direction` unresolvable |
| **C** | exactly one currency present |
| **D** | no currency (balance curiosity / exploration / abandonment / no valid swap intent) |

Classification is mutually exclusive and exhaustive. Ambiguous direction → **B** (ask), never infer (STEP 4A rule).

## 2B — Branch A (full pair + amount)
Call in **parallel**:
1. `get_swap_range({ fromCurrency: source_currency, toCurrency: target_currency })` — validates the pair AND returns `swap_min` / `swap_max`. `{ success: false }` → pair unsupported → **2F Unsupported-pair degrade**.
2. `get_account_detail` for `fiat` and `crypto` **only**.

Emit a one-line intent echo (user's language) before proceeding — adjust source/target by `direction`:
- 中文:`已理解:将 {amount} {source_currency} 兑换为 {target_currency},正在查汇率…`
- English: `Understood: exchanging {amount} {source_currency} → {target_currency}, checking the rate…`

Do **NOT** display the account overview or any pairs list. Proceed to **STEP 4C** (4A/4B already done in triage; carry the `get_swap_range` result forward — do not re-call it).

## 2C — Branch B (full pair, no amount)
Call in **parallel**:
1. `get_swap_range({ fromCurrency: source_currency, toCurrency: target_currency })` — same validation/bounds as 2B. `{ success: false }` → **2F Unsupported-pair degrade**.
2. `get_account_detail` for `fiat` and `crypto` **only**.

Ask the user for the **amount**, showing the swap range in `source_currency` per the STEP 4C range-display lines (both bounds / only max / only min / omit when both null). Do **NOT** display the account overview or pairs list. ⛔ **STOP.**
→ On the user's amount reply: proceed to **STEP 4C** (currencies + direction known; carry the `get_swap_range` result forward — do not re-call. If direction is still unresolvable, ask).

## 2D — Branch C (single currency)
Call in **parallel**:
1. `get_available_currency_pairs()`
2. `get_account_detail` for `fiat` and `crypto` **only**.

Display ONLY the pairs containing the named currency, per `account-display.md` → **Filtered Currency Pairs**. Do **NOT** display the account overview. Ask the user for the other currency (+ amount / direction). ⛔ **STOP.**
→ On reply: **re-run STEP 2 Intent Triage** with the combined intent (normally now A or B).

## 2E — Branch D (no intent)
Today's full behavior. Call in **parallel**:
1. `get_available_currency_pairs()`
2. `get_account_detail` for **all** productCodes: `fiat`, `crypto`, `investment_fiat`, `quarantine_portfolio`, `investment_product`.

→ Any call `success: false` with `authPageUrl` → Token Guard, STOP. → All succeed → display per `account-display.md` (Account Overview + per-currency details + the full Available Currency Pairs list), then ask **3C**.

### 3C — Ask the user (branch D)
> How would you like to exchange? For example: "Exchange USD for 10,000 SGD"

⛔ **STOP.** Wait. Do not assume, guess, or pre-fill values.

**Wealth Evaluation Gate (on no-intent reply):** when the user's reply to 3C contains no valid swap intent (no currencies, no amount, no direction — balance curiosity / abandonment / exploration), evaluate `WEALTH_RECOMMENDATION_TRIGGER` (`../shared/wealth-recommendation.md`) BEFORE re-asking 3C. If TRUE, render the recommendation, then re-ask 3C. If the reply IS a valid swap intent → **re-run STEP 2 Intent Triage**, no recommendation. (See SKILL.md → Wealth Evaluation Gate.)

## 2F — Unsupported-pair degrade (branches A / B / C)
When `get_swap_range` returns `{ success: false }` (A/B), or the user's single named currency (C) appears in no pair: tell the user that pair / currency can't be exchanged, then display the pairs containing the currency they named (per `account-display.md` → **Filtered Currency Pairs**; use `source_currency` if known, else the named currency). Re-ask. ⛔ **STOP.** Never dead-end.

## Key data from `get_account_detail`
(Branch D fetches all 5 productCodes; A/B/C fetch the `fiat`/`crypto` subset. Same field semantics either way.)
- `data.holderCode` — account identifier (e.g. `A0102634`), used on the confirmation page.
- `data.instrumentInfoMap` — per-currency breakdown. **Do not hardcode** which currencies belong to which productCode — each user differs.
- Build a unified lookup by merging `instrumentInfoMap` across productCodes. A currency may appear in multiple productCodes; record `availableAmount` / `pendingAmount` / `pendingCreditAmount` per (currency, productCode). **Do NOT sum across productCodes** — they are separate accounts.
- When validating swap balance (STEP 4C), only check `fiat` + `crypto`.
- Display filter (branch D only): show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`.

---

# STEP 4 — Parse Intent & Validate

## 4A — Parse
Extract `source_currency`, `target_currency`, `amount`, `direction` (is `amount` the source or target?).
- "I want to exchange 10,000 SGD" → `target_currency=SGD`, `amount=10000`, `direction=target`
- "spend 10,000 USD to buy SGD" → `source_currency=USD`, `amount=10000`, `direction=source`
- Ambiguous (can't determine source/target) or only one currency mentioned → **ASK**. Do not infer.

## 4B — Pair validation (folded into the swap-range probe)
Pair validation is performed by the `get_swap_range` probe in 4C (`{ success:false }` → unsupported), and for branches A/B it was already run in **STEP 2 triage** — carry that result forward, do not re-call. There is no separate pairs-list bidirectional check here. On an unsupported pair, follow **STEP 2 → 2F Unsupported-pair degrade** (tell the user, show pairs containing their currency, re-ask).

## 4C — Resolve source amount & productCode

**Swap range probe (do this once `source_currency` + `target_currency` are known).** If **STEP 2 triage already called `get_swap_range` for this pair (branches A/B)**, reuse that result — do NOT re-call. Otherwise call `get_swap_range({ fromCurrency: source_currency, toCurrency: target_currency })`:
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
☐ STEP 2: triggering message classified into exactly one branch (A/B/C/D)?
☐ STEP 2 A/B: get_swap_range used for validation+bounds (NOT get_available_currency_pairs)? get_account_detail limited to fiat+crypto? NO overview / NO all-pairs rendered? A: intent echo emitted? → entered 4C carrying the swap-range result?
☐ STEP 2 C: get_available_currency_pairs fetched? displayed ONLY pairs containing the named currency (Filtered Currency Pairs), NO overview? asked the other side? STOP? reply re-triaged?
☐ STEP 2 D: pairs + all 5 productCode details fetched? full overview + all pairs displayed? asked 3C? STOP? Wealth Gate evaluated on no-intent reply?
☐ STEP 2 2F: unsupported pair (A/B success:false, or C currency in no pair) → degraded to Filtered Currency Pairs + re-ask, never dead-ended?
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
