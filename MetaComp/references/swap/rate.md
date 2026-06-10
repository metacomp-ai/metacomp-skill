# Rate — Read-only indicative currency exchange rate

## When to enter this sub-skill

Entered from `SKILL.md` routing (the lightweight read-only **rate** branch) when the user asks for a *price / rate / valuation* of one currency in another, with **no** transactional verb:

- 「price xaut to sgd / 汇率 XAUT 到 SGD / XAUT to SGD rate」
- 「how much is 100 XAUT in SGD / 100 XAUT 值多少 SGD」
- 「报价 USDT/SGD / 查一下 USD 兑 SGD」

This sub-skill is **read-only**. It does NOT lock a quote, confirm, or execute a swap — see `swap.md` for the quote → confirm → execute flow. It does NOT render the account overview, fetch the pairs list, evaluate the Wealth Gate, or run auth/KYC setup (lightweight path). The rate shown is **indicative** (a browse rate); the actual executable rate is locked only at swap time via `get_otc_quote`.

## STEP 1 — Parse the pair (+ optional amount)

From the user's message extract:
- `fromCurrency` — the currency being valued (the left side, "X" in "X to Y")
- `toCurrency` — the currency to express it in (the right side, "Y")
- `amount` — OPTIONAL, a number on the `fromCurrency` side (e.g. `100` in "100 XAUT to SGD"). Absent for a bare "price X to Y".

Direction: `get_exchange_quote` returns `1 fromCurrency = rate toCurrency`. Map the user's "X to Y" so `fromCurrency = X`, `toCurrency = Y`.

**Only one currency named** (e.g. "price of XAUT") → ask for the other side in the user's language ("兑换成哪个币种？/ Priced in which currency?"), ⛔ STOP. Do NOT guess a default quote currency. Do NOT dead-end.

## STEP 2 — Call `get_exchange_quote`

`get_exchange_quote({ fromCurrency, toCurrency }) → { rate }` (string; `1 fromCurrency = rate toCurrency`).

- `success: false` **with** `authPageUrl` → Token Guard (SKILL.md): show the login link, ⛔ STOP. (Highest priority — `get_exchange_quote` is a logged-in call.)
- `success: false` **without** `authPageUrl`, or any "unsupported pair" signal → **Unsupported-pair degrade**: tell the user that pair isn't available for an exchange rate and suggest naming a supported currency (user's language), ⛔ STOP. Do NOT call `get_swap_range`, do NOT fetch or render the pairs list — that bidirectional reverse-lookup belongs to `swap.md`, not this lightweight path.
- Success → `rate` is a decimal string; use it as-is (no minor-unit division).

## STEP 3 — Render the rate

Plain prose or a short line (NEVER echo tool JSON):

- Always: `1 {fromCurrency} = {rate} {toCurrency}（参考汇率）/ (indicative rate)`
- If `amount` was given: also `{amount} {fromCurrency} ≈ {amount × rate} {toCurrency}` — compute by multiplying the decimal strings at full precision; do NOT round to an integer.
- Make clear it is **indicative**: e.g. add "实际成交汇率以换汇下单时锁定的为准 / the actual rate is locked when you place the swap."

## STEP 4 — Bridge to swap

End with an invitation (do NOT auto-start a swap):

- 中文：`需要兑换具体金额吗？说"换 {amount 或 X} {fromCurrency} 到 {toCurrency}"，我帮你锁价。`
- English: `Want to exchange a specific amount? Say "swap {amount or X} {fromCurrency} to {toCurrency}" and I'll lock a quote.`

If the user accepts (uses a transactional verb or states an amount to move), the **Scenario Re-Route Guard** (SKILL.md) re-routes to **swap** — emit a fresh `Routing → swap` line and run `swap.md` from STEP 2. Do NOT continue inside this file.

## Edge cases

- **Empty / missing `rate`** (success but `rate` is `""` or absent) → tell the user the rate is temporarily unavailable for `{from}/{to}`, suggest retry or a different pair; do NOT fabricate a number. ⛔ STOP.
- **Same currency** ("USD to USD") → `1 USD = 1 USD`; nothing to swap.

## Pitfalls

- ❌ Do NOT call `get_otc_quote` / `confirm_otc_trade` / `get_swap_range` here — read-only, never locks or validates a transaction.
- ❌ Do NOT render the account overview, fetch the pairs list, run auth/KYC setup, or evaluate the Wealth Gate — lightweight path.
- ❌ Do NOT provide rate predictions or financial advice (SKILL.md global rule).
- ❌ Do NOT present the indicative rate as a guaranteed / locked execution price.
- ❌ Do NOT divide `rate` by `10^decimals` — it is already a decimal string.
