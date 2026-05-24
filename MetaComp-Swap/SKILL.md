---
name: MetaComp-Swap
version: 0.5.2
description: >
  Currency exchange (swap) via MetaComp Swap.
  Trigger when the user mentions: currency exchange, swap, convert currency,
  or specific requests like "I want to exchange 10000 SGD", "换汇", "换钱", "我想换钱".
metadata:
  mcpServers:
    - metacomp mcp
---

# STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before calling any MCP tool:

**Step A — Read all sub-skill files:**
1. `subSkills/account-display.md`
2. `subSkills/swap-confirm.md`
3. `subSkills/wealth-recommendation.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read: account-display ✓ / swap-confirm ✓ / wealth-recommendation ✓

Do not proceed until this line appears in the response.

---

# STEP 1 — Probe & Fetch Data

Call both tools **in parallel**:
1. `get_account_summary()`
2. `get_available_currency_pairs()`

## Handle responses:

### Case A — Connection failure / 401
Server not configured. Show Setup Guide (see bottom of this file), **STOP**.

### Case B — `success: false` with `authPageUrl`

Example response:
```json
{
  "success": false,
  "authPageUrl": "https://demo.metacomp.ai/auth/metacomp/login",
  "msg": "Invalid token"
}
```

Output:

> Your session has expired. Please log in to continue:
>
> **[Log in to MetaComp]({authPageUrl})**
>
> Once logged in, come back here and let me know.

⛔ **STOP.** Do not call any tool. Wait for the user to confirm they have logged in.

When the user confirms → go back to STEP 1 (re-call both tools).

> 🔁 **Resume note:** a continuation reply like "go on" / "继续" / "I've logged in" is a flow-control signal — it does NOT replace the **original triggering message**. When later evaluating WEALTH_RECOMMENDATION_TRIGGER (e.g. at STEP 3C when the user's reply has no clear swap intent), anchor condition 5 to the user's original intent, not the continuation.

### Case C — Neither returns `success: false`

`get_account_summary` and `get_available_currency_pairs` do **not** return a `success` field on success — they return the data directly (e.g. `{ "fiat": {...}, "crypto": {...} }` and `{ "pairs": [...] }`). Only error responses contain `success: false`.

Check: if neither response contains `success: false` → proceed to **STEP 2** with the data received.

---

# STEP 2 — Fetch Account Detail & Exchange Rates

Call `get_account_detail` for **all** productCodes in **parallel** (for display purposes), plus exchange quotes:
1. `get_account_detail({ "productCode": "fiat" })`
2. `get_account_detail({ "productCode": "crypto" })`
3. `get_account_detail({ "productCode": "investment_fiat" })`
4. `get_account_detail({ "productCode": "quarantine_portfolio" })`
5. `get_account_detail({ "productCode": "investment_product" })`
6. `get_exchange_quote({ "fromCurrency": X, "toCurrency": Y })` for each available pair

**IMPORTANT — Swap-eligible accounts:** Only `fiat` and `crypto` accounts can be used for currency exchange. The other accounts (`investment_fiat`, `quarantine_portfolio`, `investment_product`) are displayed for informational purposes only and must NOT be used as source accounts for swap operations.

## Handle responses:

→ Any call returns `success: false` with `authPageUrl` → same as STEP 1 Case B (show login link, STOP)
→ All succeed → proceed to STEP 3

## Key data to extract from `get_account_detail`:

- `data.holderCode` — account identifier (e.g. `"A0102634"`), use in confirmation page
- `data.instrumentInfoMap` — per-currency breakdown; **do not hardcode which currencies belong to which productCode** — each user's currency list is different
- Build a unified currency lookup by merging `instrumentInfoMap` from all productCode responses. A currency may appear in **multiple** productCodes (e.g. USD exists in `fiat`, `investment_fiat`, and `investment_product`). For each (currency, productCode) pair, record `availableAmount`, `pendingAmount`, and `pendingCreditAmount`
- **Do NOT sum balances across productCodes** — they are separate accounts
- **Swap-eligible accounts:** Only `fiat` and `crypto` — when validating balance for swap in STEP 4C, only check these two productCodes. Ignore balances in `investment_fiat`, `quarantine_portfolio`, and `investment_product`
- Display filter: show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`

---

# STEP 3 — Display Data & Ask User

Present the information following `subSkills/account-display.md`, then ask the user.

## 3A — Account Overview

Display the account summary from STEP 1.

## 3B — Available Currency Pairs

Display available pairs from STEP 1.

**Rules:**
- Group pairs by direction (show as bidirectional where both directions exist)
- Show exchange rates from `get_exchange_quote` alongside each pair

**Display note below the pair/rate table** (respond in the user's language):
- EN: `ℹ Rates update continuously. You'll have 60 seconds to confirm once you select a pair.`
- ZH: `ℹ 汇率实时波动，选定币对后将有 60 秒确认窗口。`

## 3C — Ask the user

> How would you like to exchange? For example: "Exchange USD for 10,000 SGD"

⛔ **STOP.** Wait for the user's answer. Do not assume, guess, or pre-fill any values.

#### Wealth Product Recommendation (non-blocking, on user's reply)

When the user replies to STEP 3C and the reply does NOT contain a valid swap intent (no currencies, no amounts, no exchange direction — instead expressing balance curiosity, flow abandonment, or open-ended exploration), evaluate the WEALTH_RECOMMENDATION_TRIGGER (defined in `subSkills/wealth-recommendation.md`). If TRUE, follow the recommendation flow in that file, then re-ask the STEP 3C question.

If the user's reply IS a valid swap intent → proceed to STEP 4 with no recommendation.

---

# STEP 4 — Parse Intent & Validate

## 4A — Parse the user's request

Extract these fields from the user's message:
| Field | Description | Example |
|---|---|---|
| `source_currency` | Currency to sell | USD |
| `target_currency` | Currency to buy | SGD |
| `amount` | Numeric amount | 10,000 |
| `direction` | Is `amount` the source or target amount? | target |

**Rules:**
- "I want to exchange 10,000 SGD" → `target_currency=SGD`, `amount=10000`, `direction=target`
- "I want to spend 10,000 USD to buy SGD" → `source_currency=USD`, `amount=10000`, `direction=source`
- If ambiguous (cannot determine source or target), **ASK**. Do not infer.
- If only one currency is mentioned, **ASK** for the other. Do not infer.

## 4B — Validate: pair available?

Check if `{source_currency}/{target_currency}` exists in the pairs list from STEP 1.

→ **Not available:**

> This pair ({source_currency}/{target_currency}) is not currently supported.
>
> Available pairs:
> {list available pairs}
>
> Please choose from the above.

⛔ **STOP.** Wait for user to choose a different pair. Then re-validate from 4B.

→ **Available:** proceed to 4C.

## 4C — Resolve source amount & productCode

Purpose: determine the exact `totalValue` (in source currency) that STEP 5 will lock, and pick the correct `source_productCode`.

1. If `direction=target` (user said "I want to receive N of target"):
   - Call `get_exchange_quote({ "fromCurrency": source_currency, "toCurrency": target_currency })`.
   - Compute `totalValue = target_amount / rate` (keep enough precision for the source currency).
   - If `get_exchange_quote` returns a failure indicating an unsupported pair, tell the user and return to STEP 3C. Do not proceed.

2. If `direction=source`: `totalValue` is the amount the user stated.

3. Resolve `source_productCode`:
   - Filter the available accounts from STEP 1/2 down to the ones that hold `source_currency` and are swap-eligible (`fiat` / `crypto` only).
   - Exactly one match → use it.
   - Zero matches → tell the user the source currency is not held on any swap-eligible account; return to STEP 3C.
   - Multiple matches → ask the user which account to debit before proceeding.

⚠ **Do NOT pre-check balance here.** Balance adequacy is verified at STEP 5 when `get_otc_quote` locks the quote. A pre-check would use an approximate (unlocked) rate and can mislead the user if the rate moves between now and lock.

---

# STEP 5 — Lock Quote, Confirm with User, then Execute

This step replaces the former one-shot `execute_currency_exchange`. It is three sub-steps: **5a lock**, **5b confirm**, **5c execute**. Do them in order. Never skip 5b.

## 5a — Lock the quote

Call:

    {
      "tool": "get_otc_quote",
      "args": {
        "fromCurrency": "{source_currency}",
        "toCurrency":   "{target_currency}",
        "totalValue":   "{totalValue resolved in STEP 4C}"
      }
    }

Handle the response:

- **Failure — `{ "success": false, "message": "..." }`:**
  Show the `message` verbatim to the user (translated to their language if needed). Typical causes are insufficient balance or unsupported pair. Return to STEP 3C. **Do NOT auto-retry.**

- **Success** — receive `{ quoteId, exchangeRate, finalPrice, symbolCode, action, baseCurrency, quoteCurrency, fromCurrency, toCurrency, totalValue }`. Keep every field for STEP 5c.

## 5b — Confirmation page

Render the confirmation page following `subSkills/swap-confirm.md`.

**ABSOLUTE RULE — Rate display:** The confirmation page MUST show `exchangeRate` from `get_otc_quote` (a string). **Never show `finalPrice` to the user** — it is an internal trading-pair price used only by `confirm_otc_trade`. **The 5a-locked `exchangeRate` is authoritative** — do NOT reuse the browse-time rate shown on STEP 3B; rates drift between 3B and 5a and only the locked value is correct for the trade the user is about to confirm.

**ABSOLUTE RULE — 60-second rate window:** The confirmation page MUST include the `⚠` 60-second rate-validity notice from `subSkills/swap-confirm.md` in the user's language. Non-negotiable.

**ABSOLUTE RULE — Explicit confirmation:** Wait for the user to explicitly confirm. Never auto-confirm. Never proceed without an explicit yes.

⛔ **STOP.** Wait for the user.

If the user cancels or asks to change amounts/currencies → return to STEP 3C. The locked quote is abandoned (it expires on its own).

## 5c — Execute after confirmation

After explicit user confirmation, call:

    {
      "tool": "confirm_otc_trade",
      "args": {
        "quoteId":    "{quoteId from 5a}",
        "symbolCode": "{symbolCode from 5a}",
        "totalValue": "{totalValue from 5a}",
        "finalPrice": "{finalPrice from 5a}",
        "action":     "{action from 5a}",
        "toCurrency": "{toCurrency from 5a}"
      }
    }

Handle the response:

### Success (success: true, with trade data)

Show the success message per `subSkills/swap-confirm.md`. Then call:

    {
      "tool": "get_otc_trade_detail",
      "args": { "tradeCode": "{data.tradeCode}" }
    }

**ABSOLUTE RULE — Use STEP 5a quote data for user-facing amounts:**

The `get_otc_quote` response from STEP 5a is the **only** source for Paid / Received / Rate fields in the success message:

- `paid_amount` = `totalValue` (from 5a), `paid_currency` = `fromCurrency` (from 5a)
- `received_amount` = `totalValue × exchangeRate` (both from 5a), `received_currency` = `toCurrency` (from 5a)
- `rate_display` = `1 {fromCurrency} = {exchangeRate} {toCurrency}`

`get_otc_trade_detail` is consulted ONLY for metadata: `trade.tradeCode`, `trade.status`, `trade.createAt`, `trade.settleAt`.

**Ignore `trade.action`, `trade.tradingPair`, `trade.baseQuantity`, `trade.quoteAmount`, `trade.finalQuote` for display.** They encode the internal trading-pair direction and frequently do not match the user's from→to intent — reasoning about them introduces bugs and visible agent confusion. The trade already executed at the price the user saw in STEP 5b; there is nothing to rederive from trade-detail.

If the reasoning chain starts debating "does action=1 mean paid = baseQuantity or quoteAmount here" — STOP. Discard that reasoning and use 5a data directly.

### Failure — Token Guard (check FIRST)

If response indicates 401 / session expired → follow the Token Guard procedure in the Absolute Rules section.

### Failure — Quote expired

If backend returns a quote-expired-style error: show "Quote expired. Please start again." and return to STEP 3C. Do NOT auto-re-lock.

### Failure — Any other error

Surface the backend `message` to the user and return to STEP 3C.

---

# Final Response Gate — Check Before Ending Any Response

At each step, verify:

```
STEP 1:
☐ Both tools called in parallel?
☐ Error handling: 401 → Setup Guide? success:false → authPageUrl?

STEP 2:
☐ get_account_detail called for all 5 productCodes (fiat, crypto, investment_fiat, quarantine_portfolio, investment_product)?
☐ Per-currency balances extracted from instrumentInfoMap?
☐ Only non-zero currencies retained for display?

STEP 3:
☐ Account overview displayed (summary + per-currency detail)?
☐ Available pairs displayed?
☐ Asked user how they want to exchange?
☐ STOP — waiting for user input?

STEP 4:
☐ All four fields parsed (source, target, amount, direction)?
☐ Ambiguous → asked for clarification?
☐ Pair validated against available list?
☐ direction=target: `get_exchange_quote` called to compute required source amount?
☐ Source productCode resolved (exactly one match, or asked user if multiple)?
☐ Did NOT pre-check balance here (deferred to STEP 5a)?

STEP 5a — Lock:
☐ `get_otc_quote` called with `totalValue` as STRING (fromCurrency amount, not toCurrency)?
☐ On `{success:false, message}`: showed message and returned to STEP 3C, no auto-retry?
☐ On success: preserved `quoteId`, `exchangeRate`, `finalPrice`, `symbolCode`, `action`, `toCurrency`?

STEP 5b — Confirm:
☐ Confirmation page rendered per `subSkills/swap-confirm.md`?
☐ Rate displayed as `exchangeRate` (string) — NEVER `finalPrice`?
☐ ⚠ 60-second rate-validity notice included in the user's language?
☐ STOP — waited for explicit user confirmation?
☐ Did NOT auto-confirm?

STEP 5c — Execute:
☐ Only executed AFTER explicit user confirmation?
☐ `confirm_otc_trade` called with `quoteId`, `symbolCode`, `totalValue`, `finalPrice`, `action`, `toCurrency` passed through from 5a unchanged?
☐ On success: `get_otc_trade_detail` called with `tradeCode` to enrich the result?
☐ Paid/Received/Rate derived from STEP 5a quote data (`fromCurrency`/`toCurrency`/`totalValue`/`exchangeRate`), NOT from `trade.action`/`baseQuantity`/`quoteAmount`/`finalQuote`?
☐ Quote-expired / token / other failures handled per 5c guidance (return to STEP 3C)?
☐ Success/failure message displayed per `subSkills/swap-confirm.md`?

Repeat-swap sanity check:
☐ If the user is asking for a subsequent swap in this conversation, did I run the full flow from STEP 1 instead of refusing with a "one swap per conversation" message?
```

Any unchecked item → complete it before ending the response.

---

# MetaComp Swap — Server Setup Guide

**No server added yet** → complete all 3 steps.
**Server added, no API key** → skip to Step 2.

### Step 1 — Add the Server
Sidebar → **Customize** → **Connectors** → **+** → **Add custom connector**
- Name: `metacomp mcp`
- URL: `https://demo.metacomp.ai/mcp`

### Step 2 — Connect and Authorize
Customize → Connectors → find **metacomp mcp** → **Connect**
Enter your `sk-...` API key → **Allow**

> No API key? Apply at [metacomp.ai](https://demo.metacomp.ai)

### Step 3 — Re-send your request
**401 after connecting?** Re-authorize or apply for a new key at metacomp.ai.

---

# Tool Reference

### `get_account_summary`
```json
{}
```
Returns account balances across 5 categories: `fiat`, `crypto`, `investment_fiat`, `quarantine_portfolio`, `investment_product`. Each with `availableAmount`, `pendingAmount`, `totalAmount`.

### `get_available_currency_pairs`
```json
{}
```
Returns `pairs` array in `BASE/QUOTE` format, e.g. `["USD/USDC", "GBP/USDT", ...]`.

### `get_account_detail`
```json
{ "productCode": "fiat" }
```
`productCode` values: `"fiat"`, `"crypto"`, `"investment_fiat"`, `"quarantine_portfolio"`, `"investment_product"`

Returns:
- `data.holderCode` — account identifier (e.g. `"A0102634"`)
- `data.productCode` — echoes input
- `data.totalAmount` / `availableAmount` / `pendingAmount` — aggregated totals
- `data.instrumentInfoMap` — per-currency breakdown, keyed by currency code:
  ```json
  {
    "USD": {
      "unitCode": "USD",
      "availableAmount": 13887754197.5,
      "pendingAmount": 0,
      "totalAmount": 13887754197.5,
      "lockedAmount": null,
      "availableAmountUSD": 13887754197.5
    }
  }
  ```
  Key fields per currency: `unitCode`, `availableAmount`, `pendingAmount`, `totalAmount`, `availableAmountUSD` (USD equivalent).

### `get_exchange_quote`
```json
{
  "fromCurrency": "GBP",
  "toCurrency": "USDT"
}
```
Returns the current exchange rate for the specified currency pair.

Returns:
```json
{
  "rate": "0.09085953116481918953"
}
```
- `rate` — exchange rate as a **string** (high precision). Meaning: 1 unit of `fromCurrency` = `rate` units of `toCurrency`.

### `get_otc_quote`
```json
{
  "fromCurrency": "USD",
  "toCurrency": "USDC",
  "totalValue": "10"
}
```
- `fromCurrency` — source currency code
- `toCurrency` — target currency code
- `totalValue` — amount of `fromCurrency` to lock

Returns on success:
```json
{
  "quoteId": "q_abc123",
  "exchangeRate": "0.95",
  "finalPrice": "9.5",
  "symbolCode": "S0000052",
  "action": 1,
  "baseCurrency": "USD",
  "quoteCurrency": "USDC",
  "fromCurrency": "USD",
  "toCurrency": "USDC",
  "totalValue": "10"
}
```
- `quoteId` — locked quote identifier
- `exchangeRate` — displayed exchange rate (string, shown to user)
- `finalPrice` — internal trading-pair price (never shown to user, passed to confirm_otc_trade)
- `symbolCode` — trading symbol identifier
- `action` — `1` = buy base, `2` = sell base

### `confirm_otc_trade`
```json
{
  "quoteId": "q_abc123",
  "symbolCode": "S0000052",
  "totalValue": "10",
  "finalPrice": "9.5",
  "action": 1,
  "toCurrency": "USDC"
}
```
Confirms the locked quote and executes the trade.

Returns on success:
```json
{
  "success": true,
  "data": {
    "tradeCode": "OT2026040917520001"
  }
}
```
- `data.tradeCode` — transaction reference ID

### `get_otc_trade_detail`
```json
{ "tradeCode": "OT2026040917520001" }
```
Call after `confirm_otc_trade` succeeds to fetch the final settled transaction details.

Returns:
```json
{
  "trade": {
    "tradeCode": "OT2026041310070002",
    "status": 1,
    "action": 1,
    "symbolCode": "S0000052",
    "tradingPair": "GBP/USDT",
    "baseQuantity": 5000,
    "quoteAmount": 454.50413599,
    "finalQuote": 0.0909008272,
    "settleAt": "2026-04-13T16:00:00.000+00:00",
    "createAt": "2026-04-13T02:07:41.000+00:00",
    "updateAt": "2026-04-13T02:07:41.000+00:00"
  }
}
```

- `trade` is `null` if no matching trade is found.
- `tradingPair` is always `BASE/QUOTE`. `baseQuantity` is in the base currency, `quoteAmount` in the quote.
- `action`: `1` = buy base (user paid quote), `2` = sell base (user paid base).
- `status`: `1` = pending, `4` = settled/completed.
- `finalQuote`: locked-in rate where 1 base = `finalQuote` quote.

---

# Absolute Rules

## Repeat Swaps — Always Allowed

Each swap request is an **independent transaction**. There is NO per-conversation limit on swaps.

- If the user asks for another swap after a successful one (same or different currency pair, same or different amount), **treat it as a fresh request and run the full flow from STEP 1**.
- Never refuse a second swap citing "already executed in this conversation", "duplicate", "open a new conversation", or similar. **No such rule exists in this skill.** That refusal is a hallucination and must not be emitted.
- The only one-per-conversation rule in this skill is the wealth-product recommendation (see `subSkills/wealth-recommendation.md`) — that rule does NOT apply to swaps.
- On a repeat swap, re-fetch fresh data (account balances, pairs, rates) — do not reuse values from the previous swap. Balances and rates have moved.

## Token Guard — Universal Session Check

**After EVERY MCP tool call**, before processing the response data, check:

1. If the response contains `success: false` AND `authPageUrl` → **TOKEN EXPIRED**
2. Immediately stop the current flow
3. Output:

> Your session has expired. Please log in to continue:
>
> **[Log in to MetaComp]({authPageUrl})**
>
> Once logged in, come back here and let me know — I'll pick up where we left off.

4. ⛔ **HARD STOP.** Do not call any MCP tool. Do not use previously fetched data to continue. Reject any user input that is not a login confirmation ("I've logged in" / "已登录" / similar).
5. When the user confirms login → call `get_account_summary()` to re-verify session:
   - Still `success: false` with `authPageUrl` → repeat step 3 (show login link again)
   - Success → resume from the **exact step** where the token expired (re-call the failed tool with the same parameters)

**This rule takes priority over all step-specific error handling.** Token expiration is always detected and handled before any other error logic.

---

## Wealth Evaluation Gate — Mandatory Pre-Reask Check (STEP 3C)

**This rule has the same priority as Token Guard.** It applies whenever the user replies to STEP 3C and the reply does NOT contain a valid swap intent (no explicit currencies, no explicit amount, no explicit exchange direction).

1. **Before you re-ask the STEP 3C question** ("How would you like to exchange?") on a no-intent reply, you MUST have completed the following **sequential** evaluation:

   **Step A — Evaluate ALL 5 conditions of WEALTH_RECOMMENDATION_TRIGGER** (defined in `subSkills/wealth-recommendation.md`). This evaluation is mandatory and must happen BEFORE any tool call. There is NO path that skips this evaluation.

   **Step B — Branch on result:**
   - **All 5 conditions TRUE** → call `investor_precheck`, then follow the recommendation flow in `subSkills/wealth-recommendation.md`.
   - **Any condition FALSE** → record which specific condition (1–5, including sub-clause 5a/5b/5c) evaluated FALSE and why. Do NOT call `investor_precheck`. Proceed directly to re-asking the STEP 3C question.

   ⛔ **There is no legitimate path where `investor_precheck` is called without first confirming all 5 conditions are TRUE.** Calling `investor_precheck` "just in case" or "to be safe" when condition 5 is FALSE is a rule violation — it wastes an API call and may render an unwanted recommendation to a user with clear swap intent.

2. **Evaluation is mandatory, render is non-blocking.** "Non-blocking" in `wealth-recommendation.md` refers ONLY to the rendered output (the recommendation block never halts the primary flow). The evaluation itself is **not skippable** under any circumstance where the trigger context applies. Treating the evaluation as optional is a rule violation.

3. **Self-check (mandatory before sending response):** Re-read your draft:
   - If it contains a recommendation block (product catalog) BUT the user's reply to STEP 3C contained a valid swap intent (currencies, amounts, or exchange direction) → your draft is INVALID. Condition 5 should have been FALSE. Remove the recommendation, do NOT call `investor_precheck`, and proceed to STEP 4.
   - If it re-asks the STEP 3C question after a no-intent reply BUT you did NOT evaluate the 5 conditions at all → your draft is INVALID. Go back to Step A.

4. A response that calls `investor_precheck` when condition 5 is FALSE, or that re-asks STEP 3C without evaluating the 5 conditions, is treated the same as skipping Token Guard — a rule violation.

**This rule takes priority over the phrasing of the "Wealth Product Recommendation (non-blocking, on user's reply)" section in STEP 3C** — that heading describes the *render* as non-blocking; the *evaluation* is mandatory per this Gate.

---

- ❌ Do NOT execute swap without explicit user confirmation (STEP 5)
- ❌ Do NOT infer or guess currency, amount, or direction — always ask if ambiguous
- ✅ `Primo_Link` and `PX-First` are internal currencies — display them like any other currency
- ❌ Do NOT execute the same swap twice in a single conversation
- ❌ Do NOT provide financial advice or rate predictions
- ✅ All amounts displayed with thousands separators (e.g. 10,000 not 10000)
- ✅ Every STOP point must wait for user input before proceeding
- ✅ **Account Overview**: the account overview table in STEP 3 MUST include all 5 Account Type rows and all 3 columns (Available, Pending, Total). Never skip zero-balance rows. Never omit any column. Zero values display as `0.00`.
- ✅ **Language**: detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning/thinking, tool-call preambles, tool-parameter descriptions (e.g., TaskCreate subjects), and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English.
- ✅ **Branding**: always say **MetaComp Swap** — never "MCP server" or "the server" alone
