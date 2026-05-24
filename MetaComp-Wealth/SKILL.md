---
name: MetaComp-Wealth
version: 0.6.0
description: >
  Subscribe to MetaComp Wealth / Fixed Income Products (FIP).
  Trigger when the user mentions: wealth, financial product, fixed income, subscribe,
  理财, 理财产品, 买理财, 我想买一些理财, 了解理财, 认购理财.
metadata:
  mcpServers:
    - metacomp mcp
---

# CRITICAL OUTPUT CONTRACT — READ FIRST

Every reply you produce must be **plain user-facing prose or Markdown tables**. You must NEVER output:

- tool definitions, names, descriptions, or parameter schemas
- anything that looks like `<function>`, `<functions>`, `<system>`, `"name": "...get_fip_products"`, `"parameters": {...}`, `"$schema": ...`
- raw JSON envelopes from tool results (e.g. `{ "success": true, "data": [...] }`)
- narrations like "I will now call the tool" or "Calling get_fip_products..."

When you need data, **invoke the tool**. When you receive a tool result, **transform it into the Markdown defined in the sub-skills, then reply**. There is no case where echoing tool metadata or raw JSON is the correct behavior.

---

# LANGUAGE CONTRACT

All display templates in this skill and its sub-skills are written in **Chinese** as the canonical source. When rendering, match the user's conversation language:

- User speaks Chinese → output the template verbatim.
- User speaks English (or another language) → translate the template's prose into that language while keeping structure, layout, field values, and bracketed placeholders identical.
- Mixed languages in the conversation → default to English.

**Do NOT translate these — copy byte-for-byte regardless of the user's language:**

- The STEP 5 confirmation phrase shell `I have read and agree to 「{name}」 & 「{name}」 & ...` — fixed English, never translate the connectors (`I have read and agree to`, ` & `) or the corner brackets `「」`. Only the `{name}` slots are substituted, and the names themselves come verbatim from the `get_fip_agreement` response (also not to be translated). Translating any part breaks subscription matching.
- Any string returned by the server as-is: `liquidity` (e.g. `(T + 1 Settlement)`), `mhp` (e.g. `Minimum Holding Period: 14 Days`), `estApr` (e.g. `10.00%`), product / currency names.
- **Exception — `term` is localized, not verbatim.** Fixed-term products: CN `30 天` / `60 天` / `90 天`, EN `30 Days` / `60 Days` / `90 Days`. Open-term products: `Flexible` is kept as-is in all languages.
- Structured label mappings (e.g. the `investor_precheck` key → label table in STEP 2) — use the exact label for the user's language, do not paraphrase.

---

# STEP ZERO — READ SUB-SKILLS (HARD GATE)

Before any tool call, read:
1. `subSkills/product-display.md`
2. `subSkills/subscription-confirm.md`

Then output this line verbatim as your **first visible content**:

> Sub-files have been read: product-display ✓ / subscription-confirm ✓

**This line is a hard gate.** If it is not the first line of your response (excluding a one-sentence advisory disclaimer — see below), you have left the defined flow. Stop, discard your draft, and restart from this step.

---

# Flow

## Mandatory flow entry

When this skill is triggered, you **MUST** enter the defined step sequence (STEP ZERO → 1 → 2 → 3 → ...). You are NOT allowed to:

- Give a freeform response, general commentary, or portfolio analysis instead of entering the flow.
- Summarize the user's asset structure, risk exposure, or allocation (e.g. "资产集中在 BTC，波动风险较大") — this constitutes implicit financial advice and is outside this skill's scope.
- Ask secondary confirmation questions like "需要查看吗？", "Would you like to see the products?", or any equivalent. The user's trigger message already expresses intent.
- Reuse data from previous flows (Swap, Deposit, Withdrawal, or any earlier tool calls). Every step in this skill must call its own tools fresh — do NOT skip `get_account_summary` because it was called in a Swap flow, do NOT skip `investor_precheck` because the user "seems eligible."

**Advisory question handling:** If the user's trigger message includes an advisory question (e.g. "我是不是应该买点理财?"), output **one sentence** disclaiming that you cannot provide investment advice, then **immediately** proceed to STEP ZERO / STEP 1 in the same response. Do not stop, do not wait, do not elaborate.

Run the steps in order. Between steps, do NOT narrate "now calling X" — just invoke the tool. Do NOT print its parameters or description.

## STEP 1 — Session check

Invoke **get_account_summary** (no parameters).

- Connection failure / 401 → show Setup Guide at the bottom of this file, STOP.
- `success: false` with `authPageUrl` → show the login link (template below), STOP, wait for user to reconfirm, then restart STEP 1.
- Otherwise → **mandatory: render the Account Overview table**, then continue to STEP 2.

**Account Overview** (mandatory on success — all 5 rows must appear even if zero; all 3 columns must appear; zero values display as `0.00`, never as `—` or omitted; amounts with thousands separators):

> **您的账户概览**
>
> | 账户类型 | 可用 (USD) | 待处理 (USD) | 总计 (USD) |
> |---------|-----------|-------------|-----------|
> | 法币账户 | {fiat.availableAmount}   | {fiat.pendingAmount}   | {fiat.totalAmount}   |
> | 加密货币 | {crypto.availableAmount} | {crypto.pendingAmount} | {crypto.totalAmount} |
> | 投资法币 | {investment_fiat.availableAmount}   | {investment_fiat.pendingAmount}   | {investment_fiat.totalAmount}   |
> | 隔离资产 | {quarantine_portfolio.availableAmount} | {quarantine_portfolio.pendingAmount} | {quarantine_portfolio.totalAmount} |
> | 投资产品 | {investment_product.availableAmount}   | {investment_product.pendingAmount}   | {investment_product.totalAmount}   |

English version: translate headers (`账户类型` → `Account Type`, `可用` → `Available`, `待处理` → `Pending`, `总计` → `Total`, row labels per LANGUAGE CONTRACT).

#### Per-Currency Detail (from `get_account_detail`)

After the Account Overview, call `get_account_detail` for **fiat** and **crypto** (in parallel if possible) to show per-currency balances from `data.instrumentInfoMap`.

**Display rules:**
- **Only show currencies where `availableAmount > 0` OR `pendingAmount > 0` OR `pendingCreditAmount > 0`** — skip zero-balance currencies
- `pendingCreditAmount > 0` means incoming funds awaiting confirmation — display in a separate "Incoming" column
- At the end, add: "Other {N} currencies have zero balance" (where N = total currencies - displayed currencies)
- Sort: non-zero currencies first, by `availableAmount` descending
- Zero values in the detail table display as `—` (not `0.00`)

##### English

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

##### Chinese

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

##### Data mapping

From `get_account_detail` response, for each entry in `instrumentInfoMap`:

| Display field  | Source field                      |
|----------------|-----------------------------------|
| Currency       | `unitCode`                        |
| Available      | `availableAmount` (0 → `—`)       |
| Pending        | `pendingAmount` (0 → `—`)         |
| Incoming       | `pendingCreditAmount` (0 → `—`)   |
| USD Equivalent | `availableAmountUSD` (0 → `—`)    |

**Login link template** (canonical in Chinese; render in user's language per LANGUAGE CONTRACT):

> 您的会话已过期，请先登录：
>
> **[登录 MetaComp]({authPageUrl})**
>
> 登录完成后回来告诉我即可。

## STEP 2 — Eligibility check

Invoke **investor_precheck** (no parameters).

Response is a flat map of `{ checkItemName: boolean, ... }`. Current known keys and their bilingual labels (structured mapping — use the correct column for the user's language, do not paraphrase):

| Server key | 中文 label | English label |
|---|---|---|
| `Master Brokerage Agreement & Trading Rules` | 主经纪协议及交易规则 | Master Brokerage Agreement & Trading Rules |
| `investorDeclarationTag` | 投资者声明 | Investor Declaration |

Any unknown key → display the raw key as its own label (fallback, same string in both languages).

- `success: false` with `authPageUrl` → same as STEP 1.
- **Every** value is `true` → **immediately continue to STEP 3**. Do not output anything between STEP 2 and STEP 3; do not summarize the precheck result.
- **Any** value is `false` → **HARD STOP**. The entire wealth flow is blocked. You must:
  - NOT invoke `get_fip_products`, `get_fip_agreement`, or `fip_subscribe` in this turn or any later turn until the user re-runs the flow and STEP 2 passes.
  - NOT mention, hint at, list, or describe ANY specific product (no product names like "FIP_30Days", no currencies, no APYs, no terms, no tables — nothing about the catalog at all).
  - NOT offer to "preview" or "show what's available" — there is no preview path. Eligibility must be granted first.
  - Output ONLY the failure message below, then end the response.

  List ONLY the items whose value is `false`. Items with value `true` must not appear in the list.

  If the user later asks to see products, retry, or pushes back ("just show me", "我就看看", "let me preview"), refuse politely and re-output the failure message. Do not bypass.

  **Canonical template — render VERBATIM. Translate prose to the user's conversation language per LANGUAGE CONTRACT, but keep structure, bullet layout, emoji, and the URL `https://camp.mce.sg` byte-for-byte identical. Substitute `{label}` with the correct column (中文 / English) from the bilingual mapping table above.**

  > 您当前还不能认购理财产品，以下项目尚未完成：
  >
  > - ❌ **{label}**
  > - ...
  >
  > 请前往 [MetaComp 官网](https://camp.mce.sg) 完成签署，完成后告诉我，我会为您重新检查。

  **Hard rules for this template (apply in every language):**

  - ❌ Do NOT render the failed items as a table. The list is a Markdown bullet list, one `- ❌ **{label}**` per failed item. No table, no extra columns, no `状态` / status column.
  - ❌ Do NOT fabricate per-item status strings (e.g. `未签署`, `未完成`, `Not signed`, `Pending`). The server returns only booleans — there is no status text to display.
  - ❌ Do NOT substitute the URL. It is `https://camp.mce.sg` in every language. Never render `metacomp.ai`, `www.metacomp.ai`, `demo.metacomp.ai`, or any other domain in this template — those appear elsewhere in the skill for unrelated purposes (Setup Guide, customer service) and must not leak into this message.
  - ❌ Do NOT paraphrase or expand the opening sentence ("您当前还不能认购理财产品，以下项目尚未完成：") or the closing sentence ("请前往 [MetaComp 官网](https://camp.mce.sg) 完成签署，完成后告诉我，我会为您重新检查。"). Translate per LANGUAGE CONTRACT, do not rewrite.
  - ❌ Do NOT mix languages in the `{label}` column — pick the 中文 column for Chinese conversations, the English column for English conversations (per LANGUAGE CONTRACT), and apply it consistently to every row.
  - ✅ English rendering (for English conversations) is the direct translation of the Chinese template, structure-identical — for example:

    > You are not yet eligible to subscribe to wealth products. The following items are incomplete:
    >
    > - ❌ **{label}**
    > - ...
    >
    > Please visit [MetaComp](https://camp.mce.sg) to complete the signing. Let me know once done and I will re-check for you.

## STEP 3 — List products

**Precondition gate** — before invoking `get_fip_products`, verify in the current conversation that STEP 2 (`investor_precheck`) returned with **every** value equal to `true`. If you cannot point to such a result in the current conversation, you are NOT allowed to invoke `get_fip_products`. Go back to STEP 2 first.

This applies even if:
- The user explicitly asks to see products, asks to "just preview", or insists.
- You previously displayed products in an earlier conversation (they don't carry over).
- The user said they "completed signing" but a fresh `investor_precheck` has NOT been run since.

Re-running `investor_precheck` is mandatory after the user claims they completed the signing — never trust the claim alone.

Invoke **get_fip_products** (no parameters).

- `success: false` with `authPageUrl` → same as STEP 1.
- Success → render the table following `subSkills/product-display.md`, then ask:

  > Which product would you like to subscribe to? Please specify product name and currency.

  STOP. Wait for user reply.

Response shape summary (for your own reasoning — do NOT output this): products are in top-level `data: []`. Each product has `productCode`, `productName`, `productType`, `term`, `estApr`, `currencyItemList[]`. Each variant has `id`, `currency`, `term`, `termDays`, `estApr`, `liquidity`, `mhp`. `termDays` may be negative (`-1`, `-2`) for flexible products — never show this number directly; display the `term` string.

## STEP 4 — Parse user choice & validate amount

Locate the one `currencyItemList[j]` variant the user picked. Remember:
- `id`, `currency`, `termDays` (pass as-is, may be negative)
- `productType`, `productCode` (from the product object, not the variant)

### What to ask vs. what to derive

The user only needs to provide **two things**: `productCode` (or `productName`) and `currency`. Everything else is derivable — never ask the user for it.

| Param needed by `fip_subscribe` | How to obtain |
|---|---|
| `currency` | **Ask the user** (each product has 3-5 currency variants; can't infer). |
| `subscriptionAmount` | **Ask the user** (not in any server response). |
| `id` | **Derive** by looking up `data[i].currencyItemList[j]` where `data[i].productCode` matches the user's choice AND `currencyItemList[j].currency` matches the user's currency. Unique per (product, currency). |
| `termDays` | **Derive** from `currencyItemList[j].termDays` of the matched variant. Within a single product, all variants share the same `termDays`, so once `productCode` is known, `termDays` is determined. Pass the raw number (may be `-1` / `-2`). |
| `productType`, `productCode` | **Derive** from `data[i]` (product-level). Used in `get_fip_agreement` only, not in `fip_subscribe`. |

**Do NOT ask the user for `termDays`, `term`, `id`, or any "期限" / "term" choice** — these are determined the moment `productCode` is fixed. Asking would imply the product has multiple term options, which is misleading.

### Disambiguation

If the user's reply is ambiguous → ask one clarifying question, do NOT infer. Common cases:

- Only `productCode` given (e.g. "FIP_30Days") → ask for `currency`.
- Only `currency` given (e.g. "USD") → ask which product (multiple products offer USD).
- "Open Term" with no T+1 / T+3 distinction → ask which one (`FIP_OpenTerm_T+1` vs `FIP_OpenTerm_T+3`).
- Currency given that doesn't exist in the chosen product's `currencyItemList` → tell the user, list available currencies for that product.

Ask for amount (canonical Chinese; render in user's language per LANGUAGE CONTRACT):

> 请问您想认购多少 {currency}？（最低 {min} {currency}）

Validate against this table:

| Currency | Minimum | Max decimals |
|---|---|---|
| USDC | 10,000 | 2 |
| USDT | 10,000 | 2 |
| USD  | 10,000 | 2 |
| BTC  | 1      | 8 |
| ETH  | 10     | 8 |

Fail → explain which rule failed, re-ask.
Pass → continue.

Invoke **get_fip_agreement** with `{ productType, productCode, currency }`.

- `success: false` with `authPageUrl` → same as STEP 1.
- Success → continue to STEP 5.

## STEP 5 — Confirmation

Render the agreement + subscription summary following `subSkills/subscription-confirm.md`.

### Build the confirmation phrase

`get_fip_agreement` returns:

```json
{
  "agreements": [
    {
      "product_type": "FIP",
      "product_code": "FIP_OpenTerm_T+3",
      "currency": "USD",
      "url": "https://.../Master_Note_Agreement_Open_Term.pdf",
      "show_name": "Master Note Agreement",
      "sort": 1,
      "term_days": -3
    },
    { "...": "...", "show_name": "Note Certificate Schedule 2 Open Term (T+3)", "sort": 2 }
  ]
}
```

To build the phrase:

1. Take `data.agreements[]` (or top-level `agreements[]` — whichever the wire returns).
2. Sort ascending by `sort`.
3. Map each entry to its `show_name` (verbatim from server — do NOT translate, shorten, or normalize case).
4. Join with ` & `, wrap each name in `「」`:

   - 1 agreement → `I have read and agree to 「{show_name}」`
   - 2 agreements → `I have read and agree to 「{show_name_1}」 & 「{show_name_2}」`
   - 3+ → `I have read and agree to 「{show_name_1}」 & 「{show_name_2}」 & 「{show_name_3}」 ...`

Concrete example from the real response above:

> `I have read and agree to 「Master Note Agreement」 & 「Note Certificate Schedule 2 Open Term (T+3)」`

The phrase is **fixed English, VERBATIM** — do NOT translate `I have read and agree to` or the ` & ` connector, regardless of the user's conversation language. Corner brackets `「」` are fixed (do not replace with `""`, `【】`, `()`). Only the `{show_name}` slots are substituted, and those come byte-for-byte from server.

If `agreements` is empty or missing → abort STEP 5. Output "无法获取协议信息，请稍后重试" (or its translation per LANGUAGE CONTRACT) and STOP. Never construct an empty-name phrase.

### Ask the user

Instruct the user to reply with this exact phrase. The phrase is shown VERBATIM in the ask prompt as well — do not paraphrase the phrase itself, but the surrounding prose may follow LANGUAGE CONTRACT.

**STEP 5 rendering contract — the response that asks for confirmation MUST contain, in the same message:**

1. The `认购摘要` summary table (per `subSkills/subscription-confirm.md`).
2. The agreement link list rendered from `get_fip_agreement.agreements[]` — one clickable Markdown link per entry, sorted by `sort` ascending.
3. The VERBATIM phrase instruction `I have read and agree to 「{show_name_1}」 & 「{show_name_2}」 …` shown literally, with the real `show_name` values substituted.

If any of the three is missing, you are NOT in STEP 5 — regenerate from the template.

❌ Do NOT render a simplified "Do you confirm this subscription?" / "确认认购?" / yes-no prompt — not even as a short paraphrase, not even when bilingual, not even with a thumbs-up question. If you are about to output that, you are in the wrong flow — discard the draft and re-render from the `subSkills/subscription-confirm.md` STEP 5 template.

STOP. Wait for the reply.

### Match the reply

- Exact match (whitespace / punctuation normalized; full-width vs half-width brackets tolerated; name ordering must match the order used in the ask prompt) → STEP 6.
- Anything else → output the cancellation message from `subSkills/subscription-confirm.md` and STOP. Do not re-prompt, do not accept "yes" / "是" / "confirm" / shortened variants.

**Never-accepted replies — hard list.** Regardless of casing, punctuation, surrounding whitespace, or conversation language, the following are NOT a match and MUST route to cancellation: `yes`, `y`, `ok`, `okay`, `confirm`, `confirmed`, `go ahead`, `proceed`, `sure`, `是`, `是的`, `好`, `好的`, `确认`, `同意`, `继续`, `可以`, `subscribe`, `buy`, `认购`, `认购吧`, thumbs-up emoji (👍), or any reply that does not contain the literal substring `I have read and agree to 「`. Do NOT reason about intent — absence of that substring = cancellation.

## STEP 6 — Execute

**Pre-execution gate (runs before any tool call).** Re-read the user's most recent message. It MUST contain the literal substring `I have read and agree to 「`, AND the substituted `{show_name}` slots MUST match — in order — the names built in STEP 5 from the current `get_fip_agreement` response. If either check fails (including replies like "yes", 👍, "好的", or any paraphrase), **DO NOT invoke `fip_subscribe`**. Output the cancellation message from `subSkills/subscription-confirm.md` and STOP. This gate is independent of — and takes priority over — any perceived "user intent"; absence of the literal substring is sufficient to block execution.

Invoke **fip_subscribe** with:

- `id` — from the chosen variant, string
- `currency` — from the chosen variant
- `termDays` — number, pass raw (may be negative)
- `subscriptionAmount` — plain number string, no separators, no symbol (e.g. `"10000"`, not `"10,000"`)

- `success: false` with `authPageUrl` → follow **Token Guard** rule in Absolute Rules (stop flow, show login link, HARD STOP).
- Success → render success message per `subSkills/subscription-confirm.md`.
- Failure → render failure message per `subSkills/subscription-confirm.md`.

Only call `fip_subscribe` ONCE per confirmed flow. Do not auto-retry on errors — surface the error to the user.

---

# Final Response Gate

Before ending any response, verify:

- No tool definition, schema, or raw JSON envelope was output.
- Any `⛔ STOP` point is genuinely waiting for user input.
- Tool results were transformed into the sub-skill Markdown, not pasted as JSON.
- **STEP 5 rendering check**: if this response is the STEP 5 ask, it contains (a) the `认购摘要` table, (b) the agreement link list from `get_fip_agreement.agreements[]`, and (c) the literal VERBATIM phrase `I have read and agree to 「…」` with real `show_name` values substituted. If any of the three is missing — regenerate from `subSkills/subscription-confirm.md` before ending the response.
- **STEP 6 pre-execution check**: if this response invokes `fip_subscribe`, the immediately preceding user message contained the literal substring `I have read and agree to 「` AND the `{show_name}` slots match the STEP 5 phrase in order. If not, the tool call is forbidden — discard the call and output the cancellation message instead.
- **Eligibility gate held**: if any `investor_precheck` item is `false` in the current conversation, this response contains NO product names, currencies, APYs, terms, tables, or any other catalog detail — only the failure message.
- **Eligibility-failure template integrity**: if this response is the STEP 2 failure output, verify the opening sentence, bullet structure (no table, no status column), and the URL `https://camp.mce.sg` are byte-for-byte per template. Any rewrite, table form, or domain substitution (especially `metacomp.ai`) → regenerate.
- **Flow entry enforced**: if this is the first response after the skill was triggered, the STEP ZERO confirmation line (`Sub-files have been read: ...`) appeared as the first visible content (a one-sentence advisory disclaimer before it is the only exception). No freeform commentary, portfolio analysis, or secondary confirmation question was output.
- **No cached data**: every tool call in this response was made by this skill's own flow — no data was carried over from a previous Swap / Deposit / Withdrawal flow.

Any failure → fix before ending the response.

---

# MetaComp Wealth — Server Setup Guide

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
Returns account balances. Used here for session / authentication check only.

### `investor_precheck`
```json
{}
```
Returns a flat map of `{ checkItemName: boolean, ... }`. Each key is an eligibility check item; value `true` = passed, `false` = not completed. All values must be `true` before the user can view or subscribe to any product.

### `get_fip_products`
```json
{}
```
Returns `{ data: Array<product> }`. Each product has `productCode`, `productName`, `productType`, `term`, `estApr`, `sort`, `currencyItemList[]`. Each variant in `currencyItemList` has `id`, `currency`, `term`, `termDays`, `estApr`, `liquidity`, `mhp`. See `subSkills/product-display.md` for full schema and display rules.

### `get_fip_agreement`
```json
{ "productType": "FIP", "productCode": "FIP_OpenTerm_T+3", "currency": "USD" }
```
Returns `{ agreements: Array<{ show_name, url, sort, product_type, product_code, currency, term_days }> }`. Used to build the confirmation phrase and render agreement links in STEP 5.

### `fip_subscribe`
```json
{
  "id": "variant-id-string",
  "currency": "USD",
  "termDays": -1,
  "subscriptionAmount": "10000"
}
```
- `id` — variant ID from `get_fip_products` → `currencyItemList[j].id` (string)
- `currency` — currency code from the chosen variant
- `termDays` — number, pass raw from the variant (may be negative: `-1` = T+3 flexible, `-2` = T+1 flexible)
- `subscriptionAmount` — plain number string, no thousands separators, no currency symbol

Returns on success:
```json
{
  "success": true,
  "code": 0,
  "data": {
    "tradeCode": "FIP20260414001",
    "subscriptionAmount": 10000,
    "currency": "USD",
    "createAt": "2026-04-14T08:30:00.000+00:00"
  }
}
```
- `data.tradeCode` — subscription reference ID (user's receipt)
- Other fields (`subscriptionAmount`, `currency`, `createAt`) may or may not be present — display only when returned

Returns on failure:
```json
{
  "success": false,
  "code": 1001,
  "msg": "Insufficient balance"
}
```

---

# Absolute Rules

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


- ❌ Never output tool definitions, descriptions, parameter schemas, or raw JSON envelopes.
- ❌ Never call `get_fip_products`, `get_fip_agreement`, or `fip_subscribe` if any `investor_precheck` value is `false` — and never describe, list, hint at, or "preview" any specific product, currency, APY, or term in that case. The catalog itself is gated.
- ❌ Never bypass the precheck gate on user request ("just show me", "我就看看", "preview only"). Politely refuse and re-state the failed checks.
- ❌ Never trust a user's verbal claim that they completed signing — always re-run `investor_precheck` first.
- ❌ Never execute `fip_subscribe` without an exact match of the dynamic English confirmation phrase `I have read and agree to 「{name}」 & ...` built from the current `get_fip_agreement` response (see STEP 5 for match rules). "Yes" / "是" / "confirm" / shortened variants are NOT accepted.
- ❌ Never render a STEP 5 confirmation that lacks the agreement link list or the VERBATIM phrase. A simplified "Do you confirm this subscription? yes/no" UI — even when the summary table is present — is a defect; regenerate from `subSkills/subscription-confirm.md` instead of proceeding. Treat the presence of a thumbs-up / thumbs-down prompt or a question ending in "confirm this subscription?" as a self-check failure.
- ❌ Never fetch, summarize, paraphrase, or inline the contents of the agreement PDFs. The agreement list in STEP 5 is rendered as clickable Markdown links only (`[{show_name}]({url})`), one per `agreements[]` entry.
- ❌ Never auto-correct or clip a user-supplied amount — if it violates min / decimals, ask again.
- ❌ Never execute the same subscription twice.
- ❌ Never provide financial advice or return predictions. This includes portfolio analysis, asset allocation commentary, risk exposure assessments (e.g. "资产集中在 BTC，波动风险较大"), or any suggestion that the user should or should not subscribe. This skill handles subscription mechanics only.
- ❌ Never reuse data from other flows (Swap, Deposit, Withdrawal) or earlier tool calls. Every step must call its own tools fresh. Do not skip `get_account_summary` or `investor_precheck` because they were called in a previous flow.
- ❌ Never give a freeform response when this skill is triggered. You must enter the defined step sequence (STEP ZERO → 1 → 2 → 3 → ...) — no general commentary, no "let me analyze your portfolio", no secondary confirmation questions.
- ✅ Enforce per-currency minimums: USDC/USDT/USD ≥ 10,000 (≤2dp); BTC ≥ 1 (≤8dp); ETH ≥ 10 (≤8dp).
- ✅ Display amounts with thousands separators.
- ✅ Display the `term` string for term; never show `termDays` directly.
- ✅ Follow the LANGUAGE CONTRACT at the top of this file: templates are canonical in Chinese, rendered in the user's conversation language; server-returned strings are VERBATIM; the STEP 5 confirmation phrase is fixed English VERBATIM (only agreement names are substituted, also verbatim from server).
- ✅ **Account Overview**: after STEP 1 succeeds, MUST output the full 5-row, 3-column (Available, Pending, Total) account overview table. Never skip zero-balance rows. Never omit any column. Zero values display as `0.00`.
- ✅ Branding: always **MetaComp Wealth**.
