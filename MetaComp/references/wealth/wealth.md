# Wealth (FIP) scenario

Entered from SKILL.md after the shared STEP 1 (`../shared/auth-kyc-setup.md`): session verified, Account Overview + Per-Currency Detail rendered. **The wealth scenario does NOT run the Wealth Evaluation Gate** (it IS the wealth flow) — go straight from the overview to STEP 2 below.

## Mandatory flow entry

When routed here, you **MUST** run the step sequence (STEP 2 → 3 → 4 → 5 → 6). You are NOT allowed to:
- Give a freeform response, general commentary, or portfolio analysis instead of entering the flow.
- Summarize the user's asset structure, risk exposure, or allocation (e.g. "资产集中在 BTC，波动风险较大") — that is implicit financial advice and outside this scenario's scope.
- Ask secondary confirmation questions like "需要查看吗？" / "Would you like to see the products?" — the trigger message already expresses intent.
- Reuse data from a previous Swap / Deposit / Withdrawal flow. Call this scenario's own tools fresh (`investor_precheck`, `get_fip_products`, …) — do NOT skip a call because it ran in an earlier flow or the user "seems eligible".

**Advisory question handling:** if the trigger message includes an advisory question (e.g. "我是不是应该买点理财?"), output **one sentence** disclaiming that you cannot provide investment advice, then **immediately** proceed to STEP 2 in the same response. Do not stop, do not wait, do not elaborate.

## Read gate (before rendering)

Read `product-display.md` **before STEP 3** (you cannot render the catalog correctly without it) and `subscription-confirm.md` **before STEP 5** (the agreement/confirmation templates and the verbatim-phrase rules live there). Do not render a product table or a confirmation page from memory — read the file first.

---

# LANGUAGE CONTRACT (wealth)

All display templates here and in the wealth sub-skills are canonical in **Chinese**. Render in the user's conversation language:
- Chinese → output the template verbatim.
- English (or other) → translate the prose, keep structure / layout / field values / bracketed placeholders identical.
- Mixed → default to English.

**❌ HARD RULE:** English conversation → MUST output English. Chinese prose to an English user is a defect.

**Do NOT translate — copy byte-for-byte regardless of language:**
- The STEP 5 confirmation phrase shell `I have read and agree to 「{name}」 & 「{name}」 …` — fixed English; never translate the connectors (`I have read and agree to`, ` & `) or the corner brackets `「」`. Only `{name}` slots are substituted, verbatim from `get_fip_agreement`.
- Server-returned strings: `liquidity` (e.g. `(T + 1 Settlement)`), `mhp` (e.g. `Minimum Holding Period: 14 Days`), `estApr` (e.g. `10.00%`), product / currency names.
- **Exception — `term` is localized:** fixed-term CN `30 天`/`60 天`/`90 天`, EN `30 Days`/`60 Days`/`90 Days`; open-term `Flexible` kept as-is in all languages.
- Structured label mappings (e.g. the `investor_precheck` key → label table in STEP 2) — use the exact label for the user's language.

---

# STEP 2 — Eligibility check

Invoke **investor_precheck** (no parameters). Response is a flat map `{ checkItemName: boolean, ... }`. Known keys → bilingual labels:

| Server key | 中文 label | English label |
|---|---|---|
| `Master Brokerage Agreement & Trading Rules` | 主经纪协议及交易规则 | Master Brokerage Agreement & Trading Rules |
| `investorDeclarationTag` | 投资者声明 | Investor Declaration |

Unknown key → display the raw key as its own label (same string in both languages).

- `success: false` with `authPageUrl` → Token Guard (SKILL.md).
- **Every** value `true` → **immediately continue to STEP 3**. Output nothing between STEP 2 and STEP 3; do not summarize the precheck.
- **Any** value `false` → **HARD STOP**. The entire wealth flow is blocked:
  - Do NOT invoke `get_fip_products`, `get_fip_agreement`, or `fip_subscribe` in this or any later turn until the user re-runs the flow and STEP 2 passes.
  - Do NOT mention, hint at, list, or describe ANY specific product (no names, currencies, APYs, terms, tables — nothing about the catalog).
  - Do NOT offer to "preview". Eligibility must be granted first.
  - Output ONLY the failure message below. List ONLY the items whose value is `false`.
  - If the user later pushes back ("just show me", "我就看看"), refuse politely and re-output the failure message.

  **Canonical template — render VERBATIM (translate prose per LANGUAGE CONTRACT; keep structure, bullets, emoji, and the URL `https://camp.mce.sg` byte-for-byte; substitute `{label}` from the bilingual table):**

  > 您当前还不能认购理财产品，以下项目尚未完成：
  >
  > - ❌ **{label}**
  > - ...
  >
  > 请前往 [MetaComp 官网](https://camp.mce.sg) 完成签署，完成后告诉我，我会为您重新检查。

  Hard rules for this template (every language):
  - ❌ NOT a table. Bullet list, one `- ❌ **{label}**` per failed item. No status column.
  - ❌ Do NOT fabricate per-item status strings (`未签署`, `Not signed`, etc.). Server returns only booleans.
  - ❌ Do NOT substitute the URL — it is `https://camp.mce.sg` in every language. Never render any `metacomp.ai` host here.
  - ❌ Do NOT paraphrase the opening / closing sentence. Translate, don't rewrite.
  - ❌ Do NOT mix languages in `{label}` — pick the 中文 or English column consistently.
  - ✅ English example: "You are not yet eligible to subscribe to wealth products. The following items are incomplete: … Please visit [MetaComp](https://camp.mce.sg) to complete the signing. Let me know once done and I will re-check for you."

# STEP 3 — List products

**Precondition gate** — before `get_fip_products`, verify in THIS conversation that STEP 2 returned every value `true`. If you can't point to such a result, you may NOT invoke `get_fip_products` — go back to STEP 2. This holds even if the user insists, even if products were shown in an earlier conversation, even if the user claims they "completed signing" (re-run `investor_precheck` — never trust the claim alone).

Invoke **get_fip_products** (no parameters).
- `success: false` with `authPageUrl` → Token Guard.
- Success → render the table per `product-display.md`, then ask:
  > Which product would you like to subscribe to? Please specify product name and currency.

  ⛔ **STOP.** Wait. (Response shape for your reasoning only — do NOT output: products in `data:[]`; each has `productCode`, `productName`, `productType`, `term`, `estApr`, `currencyItemList[]`; each variant has `id`, `currency`, `term`, `termDays`, `estApr`, `liquidity`, `mhp`. `termDays` may be negative for flexible — never show it; display the `term` string.)

# STEP 4 — Parse choice & validate amount

Locate the chosen `currencyItemList[j]`: remember `id`, `currency`, `termDays` (pass as-is, may be negative); `productType`, `productCode` (from the product object).

The user provides only **two** things: `productCode` (or `productName`) and `currency`. Everything else is derived — never ask for it:

| Param for `fip_subscribe` | How to obtain |
|---|---|
| `currency` | **Ask** (3–5 variants per product). |
| `subscriptionAmount` | **Ask** (not in any server response). |
| `id` | **Derive** — `data[i].currencyItemList[j]` where product matches AND `currency` matches. |
| `termDays` | **Derive** from the matched variant (all variants in a product share it). Pass raw (may be `-1`/`-2`). |
| `productType`, `productCode` | **Derive** from `data[i]`. Used in `get_fip_agreement` only. |

Do NOT ask for `termDays`, `term`, `id`, or any "期限"/"term" choice — fixed once `productCode` is known.

Disambiguation (ask one question, don't infer): only `productCode` → ask currency; only `currency` → ask which product; "Open Term" w/o T+1/T+3 → ask which; currency not in the product's `currencyItemList` → tell the user, list available.

Ask amount (CN canonical; render per LANGUAGE CONTRACT). The bound hint comes from the chosen variant's `minAmount` / `maxAmount`: both present → `（{minAmount}–{maxAmount} {currency}）`; only min → `（最低 {minAmount} {currency}）`; only max → `（最高 {maxAmount} {currency}）`; both `null` → omit the bound hint entirely:
> 请问您想认购多少 {currency}？（{minAmount}–{maxAmount} {currency}）

Validate against the chosen variant's `minAmount` / `maxAmount` (skip a bound that is `null`; equal-to-bound is allowed): reject `amount < minAmount` or `amount > maxAmount`. Also enforce decimal precision: USDC/USDT/USD ≤ 2dp; BTC/ETH ≤ 8dp. Fail → explain which rule failed, re-ask. Pass → continue.

**Funds-First balance gate (SKILL.md → Funds-First Gate).** A subscription debits the user's spendable balance, so confirm it covers `subscriptionAmount` BEFORE building the agreement / confirmation — don't let the user agree to terms and authorize a subscription the account can't fund. The funding account follows the currency: **USD → `investment_fiat`; USDT / USDC / BTC / ETH (and any crypto) → `crypto`** (the spendable source accounts for a subscription; `investment_product` holds post-subscription holdings, never the source). Call `get_account_detail({ productCode })` for that account (fetch fresh if not cached this turn or if a Token Guard re-login happened), read `available = instrumentInfoMap[{currency}].availableAmount` (missing/nullish → treat as `0`), and compare with `BigNumber`:

- `BigNumber(subscriptionAmount).gt(available)` → stop and state the shortfall; do NOT call `get_fip_agreement` or render the STEP 5 confirmation:
  > Your available {currency} balance is {available}, which doesn't cover a {subscriptionAmount} {currency} subscription. Please enter a smaller amount, or type "cancel". / 您的 {currency} 可用余额为 {available}，不足以认购 {subscriptionAmount} {currency}。请输入更小的金额，或输入"取消"。

  Re-ask the amount (stay on STEP 4). 
- Otherwise → continue.

Invoke **get_fip_agreement** with `{ productType, productCode, currency, subscriptionAmount }` (pass the user's amount as a plain number, e.g. `10000`). The backend re-validates the amount **server-side** (per-currency min/max + available balance) and only returns agreements when both pass.
- `success: false` with `authPageUrl` → Token Guard.
- `400` (amount out of the allowed range, or insufficient balance) → tell the user what failed **and the allowed range**, then **re-ask the amount; do NOT proceed to STEP 5**.
- Success → STEP 5.

# STEP 5 — Confirmation

**Hard precondition:** before rendering the confirmation phrase, you MUST have called `get_fip_agreement` **fresh in this same subscription attempt** with the user's current `subscriptionAmount`, and it MUST have returned success. The `show_name` values in the phrase come ONLY from that fresh response — never reconstruct the phrase from memory, an earlier turn, or a prior subscription. No fresh `get_fip_agreement` this attempt → you are not at STEP 5; go back to STEP 4.

Render the agreement + subscription summary per `subscription-confirm.md`.

**Build the confirmation phrase:** take `agreements[]` (or `data.agreements[]`), sort ascending by `sort`, map each to its `show_name` (verbatim — do NOT translate/shorten/normalize case), join with ` & `, wrap each in `「」`:
- 1 → `I have read and agree to 「{show_name}」`
- 2 → `I have read and agree to 「{n1}」 & 「{n2}」`
- 3+ → `… & 「{n3}」 …`

The phrase is **fixed English VERBATIM** regardless of conversation language; `「」` are fixed (not `""`/`【】`/`()`). If `agreements` is empty/missing → abort STEP 5, output "无法获取协议信息，请稍后重试" (or translation), STOP — never build an empty-name phrase.

**STEP 5 rendering contract — the ask message MUST contain, together:**
1. The `认购摘要` summary table (per `subscription-confirm.md`).
2. The agreement link list from `agreements[]` — one clickable Markdown link per entry, sorted by `sort` ascending.
3. The VERBATIM phrase `I have read and agree to 「…」` with real `show_name` values substituted.

If any of the three is missing → not STEP 5; regenerate from the template. ❌ Do NOT render a simplified "Do you confirm? / 确认认购?" yes-no prompt — discard and re-render if you catch yourself.

⛔ **STOP.** Wait.

**Match the reply:** exact match (whitespace/punctuation normalized; full/half-width brackets tolerated; name order must match the ask) → STEP 6. Anything else → cancellation message (`subscription-confirm.md`), STOP.

**Never-accepted replies — hard list** (regardless of casing/punctuation/language, route to cancellation): `yes`, `y`, `ok`, `okay`, `confirm`, `confirmed`, `go ahead`, `proceed`, `sure`, `是`, `是的`, `好`, `好的`, `确认`, `同意`, `继续`, `可以`, `subscribe`, `buy`, `认购`, `认购吧`, 👍, or any reply lacking the literal substring `I have read and agree to 「`. Do NOT reason about intent — absence of that substring = cancellation.

# STEP 6 — Execute

**Pre-execution gate (before any tool call):** the user's most recent message MUST contain the literal substring `I have read and agree to 「` AND the substituted `{show_name}` slots MUST match — in order — the names built in STEP 5 from the current `get_fip_agreement`. If either fails (incl. "yes", 👍, "好的", paraphrase) → do NOT invoke `fip_subscribe`; output the cancellation message, STOP. This gate overrides any perceived "intent".

Invoke **fip_subscribe** with: `id` (string), `currency`, `termDays` (number, raw, may be negative), `subscriptionAmount` (plain number string, no separators/symbol, e.g. `"10000"`).
- `success: false` with `authPageUrl` → Token Guard.
- Success → success message per `subscription-confirm.md`.
- Failure → failure message per `subscription-confirm.md`.

Call `fip_subscribe` ONCE per confirmed flow. No auto-retry — surface the error.

---

# Repeat subscription — re-validate fresh every time

Each subscription is its OWN attempt. After a `fip_subscribe` returns `success: true`, the **Post-Mutation Freshness Guard (SKILL.md)** stales all prior server state — balances changed (funds were debited). A second subscription in the same session (even same product / currency / amount) MUST re-run STEP 4 with the new amount: re-call `get_fip_agreement` (which re-checks live min/max + balance) and never reuse the previous attempt's agreements or validation result.

---

# Final Response Gate (wealth)

Before ending any response, verify:
- No tool definition / schema / raw JSON envelope output.
- Every ⛔ STOP genuinely waits for input.
- Tool results transformed into sub-skill Markdown, not pasted as JSON.
- **STEP 5 check:** if this is the STEP 5 ask, it contains (a) the `认购摘要` table, (b) the agreement link list, (c) the literal VERBATIM phrase with real `show_name` values. Missing any → regenerate.
- **STEP 6 check:** if this invokes `fip_subscribe`, the preceding user message contained `I have read and agree to 「` AND the `{show_name}` slots match STEP 5 in order. If not → forbidden; output cancellation instead.
- **Amount-validated-first:** if this response renders the STEP 5 confirmation (or the phrase), `get_fip_agreement` was called fresh in THIS subscription attempt with the user's `subscriptionAmount` and returned success. If it returned `400` (limit / balance), this response is the re-ask-amount message stating the allowed range, not a confirmation.
- **Eligibility gate held:** if any `investor_precheck` item is `false`, this response contains NO product names/currencies/APYs/terms/tables — only the failure message.
- **Eligibility-failure integrity:** the STEP 2 failure output keeps the opening sentence, bullet structure (no table/status column), and URL `https://camp.mce.sg` byte-for-byte.
- **Flow entry enforced:** if this is the first response after the scenario was routed, it entered the step sequence — no freeform commentary, portfolio analysis, or secondary confirmation question (an advisory question got at most one disclaimer sentence, then proceeded).
- **No cached data:** every tool call in this response was made fresh by this scenario — no data was carried over from a previous Swap / Deposit / Withdrawal flow.
- **Funds-First gate held:** if this response calls `get_fip_agreement` or renders the STEP 5 confirmation, the funding-account balance (investment_fiat for USD, crypto otherwise) was checked fresh and covers `subscriptionAmount`. If it didn't cover, this response is the shortfall message, not an agreement/confirmation.

---

# Tool Reference (wealth)

- `investor_precheck()` → flat `{ checkItemName: boolean }`. All must be `true` before viewing/subscribing.
- `get_fip_products()` → `{ data: [product] }`; product has `productCode`/`productName`/`productType`/`term`/`estApr`/`sort`/`currencyItemList[]`; variant has `id`/`currency`/`term`/`termDays`/`estApr`/`liquidity`/`mhp`. See `product-display.md`.
- `get_fip_agreement({ productType, productCode, currency, subscriptionAmount })` → `{ agreements: [{ show_name, url, sort, product_type, product_code, currency, term_days }] }` on success. Validates the amount server-side (min/max + balance); a `400` (amount out of allowed range / insufficient balance) → re-ask amount, do NOT enter STEP 5.
- `fip_subscribe({ id, currency, termDays, subscriptionAmount })` → success `{ data: { tradeCode, subscriptionAmount, currency, createAt } }` (display fields only when returned); failure `{ success:false, code, msg }`.

---

# Scenario Absolute Rules (wealth)

- ❌ Never output tool definitions, schemas, or raw JSON envelopes.
- ❌ Never call `get_fip_products` / `get_fip_agreement` / `fip_subscribe` if any `investor_precheck` value is `false` — and never describe/list/hint/preview any product detail in that case. The catalog is gated.
- ❌ Never bypass the precheck gate on user request ("just show me", "我就看看"). Refuse and re-state the failed checks.
- ❌ Never trust a verbal "I completed signing" — always re-run `investor_precheck`.
- ❌ Never execute `fip_subscribe` without an exact match of the dynamic confirmation phrase. "Yes"/"是"/"confirm"/shortened variants are NOT accepted.
- ❌ Never render a STEP 5 confirmation lacking the agreement link list or the VERBATIM phrase. A "yes/no" / thumbs-up prompt is a defect — regenerate.
- ❌ Never fetch, summarize, paraphrase, or inline agreement PDF contents — render them as clickable Markdown links only.
- ❌ Never auto-correct or clip a user-supplied amount — re-ask on min/decimals violation.
- ❌ Never execute the same subscription twice.
- ❌ Never provide financial advice, portfolio/risk commentary, or return predictions. Subscription mechanics only.
- ❌ Never reuse data from other scenarios — call `investor_precheck` / `get_fip_products` fresh.
- ✅ Amount limits come from the chosen variant's `minAmount` / `maxAmount` (config-driven, `null` = no limit on that side) — never hard-code per-currency min/max. Decimal precision stays fixed: USDC/USDT/USD ≤ 2dp; BTC/ETH ≤ 8dp.
- ✅ Display the `term` string; never show `termDays` directly.
- ✅ Follow the LANGUAGE CONTRACT above.
