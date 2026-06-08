# Swap History — List past OTC currency exchanges

## When to enter this sub-skill

Entered from `SKILL.md` routing (the lightweight read-only **swap-history** branch) when the user asks about *past* swaps:

- 「查我的换汇记录 / Show my swap history」
- 「我最近换了哪些 / what did I exchange recently」
- 「上次那笔换汇结算了吗 / did my last swap settle?」

This sub-skill is **read-only**. It does NOT initiate any swap — see `swap.md` for the quote → confirm → execute flow. It does NOT render the account overview or fetch currency pairs (lightweight path).

## STEP 1 — Call `get_otc_trade_history`

Default invocation — pass nothing and rely on server defaults:

- `page` — optional, server default `0` (0-based). Omit unless paging.
- `size` — optional, server default `5`. Omit to get the 5 most recent.

So a bare "show my swap history" is simply `get_otc_trade_history()` (no arguments).

→ `success: false` with `authPageUrl` → Token Guard (SKILL.md): show login link, STOP.
→ Success → `{ list: [...], page, size, totalElements, totalPages, first, last }`, newest first.

## STEP 2 — Render each row (direction-ized)

The raw record encodes an internal base/quote pair plus a `tradingAction` direction. Convert each row into a user-facing "from → to" using `tradingAction`:

- `tradingAction === 1` (buy base): **换出** `quoteAmount` `quoteCurrency` → **换入** `baseQuantity` `baseCurrency`
- `tradingAction === 2` (sell base): **换出** `baseQuantity` `baseCurrency` → **换入** `quoteAmount` `quoteCurrency`

For each record, show:

1. **换出 → 换入** — `换出 {fromAmt} {fromCur} → 换入 {toAmt} {toCur} / Sent {fromAmt} {fromCur} → Received {toAmt} {toCur}`
2. **汇率 / Rate** — `1 {baseCurrency} = {finalPrice} {quoteCurrency}` (straight from `finalPrice`)
3. **状态 / Status** — map `tradeStatus`: `1` → 待结算 / Pending, `2` → 已结算 / Settled, `3` → 取消 / Cancelled. Any other value → show the raw code with "状态待映射 / status pending".
4. **时间 / Time** — `tradeTime` as local time. For settled (`2`) you may also show `settleTime`; for cancelled (`3`) you may show `cancelTime`.
5. **流水号 / Reference** — `tradeCode`.

**CRITICAL — amounts are decimal strings, NOT minor units.** `baseQuantity`, `quoteAmount`, and `finalPrice` are already decimal strings — display them as-is. Do **NOT** divide by `10^decimals` (that rule applies to withdrawals, not swaps).

## STEP 3 — Pagination & single-trade detail

- **More** → increment `page` (0, 1, 2, …) and call `get_otc_trade_history({ page })` again. If the user had requested a non-default page size, pass the same `size` on each subsequent page so the page size stays consistent.
- **One specific trade** → if the user wants the full detail of a single swap by its reference, call `get_otc_trade_detail({ tradeCode })` (it returns one trade's metadata).

## Edge cases

- **Empty list** → "您还没有换汇记录 / No swap history."
- **API error / 5xx** → surface a short apology and the request id; do NOT silently retry more than once.

## Pitfalls

- ❌ Do NOT apply minor-unit conversion to `baseQuantity` / `quoteAmount` — they are already decimal strings.
- ❌ Do NOT call `get_otc_quote` / `confirm_otc_trade` here — this sub-skill is read-only and never initiates a swap.
- ❌ Do NOT render the account overview or fetch currency pairs — this is the lightweight path.
- ❌ Do NOT expose internal-only fields (e.g. buyer/seller participant codes) unless they add user value.
