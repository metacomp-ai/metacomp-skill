---
name: MetaComp-Deposit
version: 0.5.3
description: >
  Deposit funds into MetaComp Deposit account.
  Trigger when the user mentions: deposit, receive money, collect payment,
  充值, 入金, 收款, 收钱, 我要收钱, 我有一笔钱要收.
  Also triggers on general asset-viewing queries: check balance, view assets, my assets,
  my balance, account overview, 查看资产, 查看余额, 看看余额, 看看资产, 我的资产,
  账户概览, 账户余额 — these enter View-Only Mode (see STEP 1 Case C).
metadata:
  mcpServers:
    - metacomp mcp
---

# STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before calling any MCP tool:

**Step A — Read all sub-skill files:**
1. `subSkills/fiat-deposit.md`
2. `subSkills/crypto-deposit.md`
3. `subSkills/wealth-recommendation.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read: fiat-deposit ✓ / crypto-deposit ✓ / wealth-recommendation ✓

Do not proceed until this line appears in the response.

---

# STEP 1 — Probe & Authenticate

Call `get_account_summary()` to verify the user's session.

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

When the user confirms → go back to STEP 1 (re-call the tool).

> 🔁 **Resume checklist (do not skip any step):** after the re-call succeeds on Case C, walk through the full post-overview sequence in order — **(1) Account Overview table → (2) Per-Currency Detail → (3) Wealth Product Recommendation trigger evaluation → (4) View-Only Mode closing / STEP 2**. A continuation reply like "go on" / "继续" / "I've logged in" is a flow-control signal; it does NOT override the **original triggering message** when evaluating WEALTH_RECOMMENDATION_TRIGGER condition 5. Evaluate that condition against the user's original intent, not the continuation.

### Case C — Success (no `success: false` in response)

**Mandatory: render the Account Overview table before proceeding.** Use the data from `get_account_summary` directly. All 5 rows must appear even if balances are zero. All 3 columns (Available, Pending, Total) must appear. Zero values display as `0.00`, never as `—` or omitted.

#### English

```
**Your Account Overview**

| Account Type         | Available (USD)          | Pending (USD)          | Total (USD)          |
|----------------------|--------------------------|------------------------|----------------------|
| Fiat                 | {fiat.availableAmount}   | {fiat.pendingAmount}   | {fiat.totalAmount}   |
| Crypto               | {crypto.availableAmount} | {crypto.pendingAmount} | {crypto.totalAmount} |
| Investment Fiat      | {investment_fiat.availableAmount}   | {investment_fiat.pendingAmount}   | {investment_fiat.totalAmount}   |
| Quarantine Portfolio | {quarantine_portfolio.availableAmount} | {quarantine_portfolio.pendingAmount} | {quarantine_portfolio.totalAmount} |
| Investment Product   | {investment_product.availableAmount}   | {investment_product.pendingAmount}   | {investment_product.totalAmount}   |
```

#### Chinese

```
**您的账户概览**

| 账户类型 | 可用 (USD) | 待处理 (USD) | 总计 (USD) |
|---------|-----------|-------------|-----------|
| 法币账户 | {fiat.availableAmount}   | {fiat.pendingAmount}   | {fiat.totalAmount}   |
| 加密货币 | {crypto.availableAmount} | {crypto.pendingAmount} | {crypto.totalAmount} |
| 投资法币 | {investment_fiat.availableAmount}   | {investment_fiat.pendingAmount}   | {investment_fiat.totalAmount}   |
| 隔离资产 | {quarantine_portfolio.availableAmount} | {quarantine_portfolio.pendingAmount} | {quarantine_portfolio.totalAmount} |
| 投资产品 | {investment_product.availableAmount}   | {investment_product.pendingAmount}   | {investment_product.totalAmount}   |
```

All amounts with thousands separators (e.g. `13,887,754,197.50`).

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

#### Wealth Product Recommendation (non-blocking)

After rendering the Account Overview **and before the View-Only Mode closing / STEP 2**, evaluate the WEALTH_RECOMMENDATION_TRIGGER (defined in `subSkills/wealth-recommendation.md`). If TRUE, follow the recommendation flow in that file — call `investor_precheck`, then conditionally `get_fip_products`, and render the appropriate template. This step sits **between** Per-Currency Detail and the final closing message — do not merge them or skip the evaluation, even when resuming after a Token Guard login.

#### View-Only Mode

If the user's original trigger message expressed **only an asset-viewing intent** (e.g. "check my balance", "查看资产", "i want to know my assets", "看看余额") with **no deposit keywords**, then after rendering the Account Overview and wealth recommendation:

> Is there anything else you'd like to do? You can **deposit**, **withdraw**, or **exchange currencies**.

⛔ **STOP.** Do not proceed to STEP 2. Wait for the user's next instruction. If the user then expresses a deposit intent → proceed to STEP 2. If they express a different intent (withdraw, swap, wealth) → that skill takes over.

#### Normal Mode

If the user's trigger message contained deposit intent → proceed to **STEP 2** as usual.

---

# STEP 2 — Choose Currency (unified fiat + crypto list)

**Shortcut** — if the user has already specified a concrete currency (e.g. "我要入 USDT", "deposit USD", "收 BTC"), skip the list entirely and route:

- Fiat currency specified → `subSkills/fiat-deposit.md` **STEP 2**, with `currency = <user's choice>`.
- Crypto currency specified → `subSkills/crypto-deposit.md` **STEP 2**, with `currency = <user's choice>`.

Otherwise, proceed to the parallel fetch below.

## Parallel fetch

Call these two tools **in parallel**:

- `get_fiat_deposit_currencies`
- `get_crypto_deposit_currencies`

**Token Guard applies to both responses.** If either is `success: false` with `authPageUrl` → Token Guard preempts, stop flow, render login link (see Absolute Rules). Do NOT render the list.

## Render (English)

> Which currency would you like to deposit? Here are the currencies currently supported for your account:
>
> **Fiat currencies:**
> {fiat_list_comma_separated}
>
> **Cryptocurrencies:**
> {crypto_list_comma_separated}
>
> Please tell me which one.

## Render (Chinese)

> 您想充值哪种币种？以下是您账户目前支持的币种：
>
> **法币：**
> {fiat_list_comma_separated}
>
> **数字货币：**
> {crypto_list_comma_separated}
>
> 请告诉我您要选择的币种。

Pick exactly one language version per the turn's dominant language (see SKILL.md language rule). The currency codes (USD, USDT, BTC, etc.) stay as-is regardless of language.

## Empty section rendering

- `fiat_list` empty → that section body becomes `No fiat currencies are currently available for your account` / `目前暂无可用法币`.
- `crypto_list` empty → that section body becomes `No cryptocurrencies are currently available for your account` / `目前暂无可用数字货币`.
- **Both empty** → do NOT render the sectioned list at all. Instead output `No deposit currencies are currently available. Please contact MetaComp support.` / `目前暂无可用充值币种，请联系 MetaComp 客服。` and ⛔ **HARD STOP**.

⛔ **STOP.** Wait for the user's choice.

## Routing after user picks

1. Normalize the reply (trim + uppercase) for list membership comparison.
2. If normalized reply matches an entry in `fiat_list` → `subSkills/fiat-deposit.md` **STEP 2**, `currency = <normalized>`.
3. Else if normalized reply matches an entry in `crypto_list` → `subSkills/crypto-deposit.md` **STEP 2**, `currency = <normalized>`.
4. Else (not in either list) → respond with `"{user_input}" is not in the supported list right now` / `"{user_input}" 不在当前支持的币种列表中` + re-render both sectioned lists + ⛔ **STOP** and wait for another choice. Do NOT guess, do NOT default-route.

**Tie-breaker (rare):** if a currency appears in both lists (unlikely edge case), default to **fiat routing**.

---

# MetaComp Deposit — Server Setup Guide

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
Returns account balances (5 product types). Used for authentication check and Account Overview.

### `get_account_detail`
```json
{ "productCode": "fiat" }
```
Returns per-currency balances via `instrumentInfoMap`. Used for Per-Currency Detail display. Call with `productCode` = `fiat` or `crypto`.

### Fiat-specific tools
See `subSkills/fiat-deposit.md` for tool details.

### Crypto-specific tools (including KYT)
See `subSkills/crypto-deposit.md` for tool details. KYT uses `get_transaction_security` and `get_wallet_security` from the metacomp-mcp server.

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

## Wealth Evaluation Gate — Mandatory Pre-Closing Check

**This rule has the same priority as Token Guard.** It applies whenever an Account Overview has been successfully rendered in this response AND the current skill is NOT `MetaComp-Wealth`.

1. **Before you output** any terminal/closing message (the View-Only Mode line "Is there anything else you'd like to do? You can **deposit**, **withdraw**, or **exchange currencies**." / the STEP 2 routing question "Would you like to receive fiat currency or cryptocurrency?" / any similar handoff line), you MUST have completed the following **sequential** evaluation:

   **Step A — Evaluate ALL 5 conditions of WEALTH_RECOMMENDATION_TRIGGER** (defined in `subSkills/wealth-recommendation.md`). This evaluation is mandatory and must happen BEFORE any tool call. There is NO path that skips this evaluation.

   **Step B — Branch on result:**
   - **All 5 conditions TRUE** → call `investor_precheck`, then follow the recommendation flow in `subSkills/wealth-recommendation.md`.
   - **Any condition FALSE** → record which specific condition (1–5, including sub-clause 5a/5b/5c) evaluated FALSE and why. Do NOT call `investor_precheck`. Proceed directly to the closing message.

   ⛔ **There is no legitimate path where `investor_precheck` is called without first confirming all 5 conditions are TRUE.** Calling `investor_precheck` "just in case" or "to be safe" when condition 5 is FALSE is a rule violation — it wastes an API call and may render an unwanted recommendation to a user with clear business intent.

2. **Evaluation is mandatory, render is non-blocking.** "Non-blocking" in `wealth-recommendation.md` refers ONLY to the rendered output (the recommendation block never halts the primary flow). The evaluation itself is **not skippable** under any circumstance where conditions 1-2 hold (overview rendered + not MetaComp-Wealth). Treating the evaluation as optional is a rule violation.

3. **Self-check (mandatory before sending response):** Re-read your draft:
   - If it contains a recommendation block (product catalog) BUT the original triggering message had clear business intent (e.g. "withdraw USD", "deposit 100 USDT", "我要充值") → your draft is INVALID. Condition 5 should have been FALSE. Remove the recommendation, do NOT call `investor_precheck`, and proceed directly to the closing message.
   - If it contains the closing sentence BUT you did NOT evaluate the 5 conditions at all → your draft is INVALID. Go back to Step A.

4. A response that calls `investor_precheck` when condition 5 is FALSE, or that reaches the closing message without evaluating the 5 conditions, is treated the same as skipping Token Guard — a rule violation.

**This rule takes priority over the phrasing of the "Wealth Product Recommendation (non-blocking)" section in STEP 1** — that heading describes the *render* as non-blocking; the *evaluation* is mandatory per this Gate.

---

## QR Artifact Gate — Crypto Deposit Display

**This rule has the same priority as Token Guard.** It applies whenever crypto deposit STEP 3b is reached and `walletAddress` is non-empty.

1. **Output sequence is fixed** — chat address message **FIRST**, QR Artifact **SECOND**. The chat message is the primary carrier of the wallet address; the Artifact is the visual augmentation that follows.
2. **Address substring presence** — the Part 1 chat message MUST contain the real `walletAddress` value from `structuredContent.addresses[].walletAddress`, wrapped in inline-code backticks on its own line. No `{walletAddress}` / `{coin}` / `{network}` placeholder may remain. No empty / `null` / `undefined` substitution may be sent. If substitution cannot be completed → fall through to the QR Fallback branch in the sub-skill; never send a garbled template.
3. **No raw HTML in chat** — chat text MUST NOT contain `<!DOCTYPE`, `<html`, `<script`, `<div`, `<style`, `<body`, `<head`, or any HTML tag opener. HTML lives only inside the Artifact. Chat emphasis is Markdown only (backticks, `**bold**`, blank-line paragraphs).
4. **Artifact SECOND** — immediately after Part 1 is emitted, create an HTML Artifact (type `text/html`) carrying the QR code.
5. **Location-neutral phrasing** — the QR and address live **inside the chat conversation body**. Never direct the user to a specific screen region.
   - **FORBIDDEN** (illustrative, intent-level, not only exact strings):
     - English: `artifact panel`, `on the right`, `right panel`, `right-hand panel`, `right side`, `right-side panel`, `side panel`, `sidebar`, `the panel`, `see the panel`, `check the panel`, `open the panel`, `in the panel on the right`, `in the sidebar`
     - Chinese: `右侧面板`, `右边栏`, `右侧`, `右边`, `右方`, `右手边`, `侧边栏`, `边栏`, `侧栏`, `旁边的面板`, `右侧的面板`, `请查看右侧`, `请看右侧`, `右侧二维码`, `右侧生成`, `右边显示`, `右侧显示`
   - **ALLOWED**: `above` / `below` / `here` / `in this message` / `scan the QR code` / `上方` / `下方` / `此处` / `本条消息中` / `扫描下方二维码` / `扫描二维码`.
6. **Silent self-check (mandatory before sending):**
   - (a) Part 1 chat text contains a real wallet address string (non-placeholder, non-empty, non-`null`)? If NO → STOP, do not send; re-read STEP 3a tool output, or fall through to QR Fallback.
   - (b) If address was non-empty, has Part 2 Artifact been produced? If NO → create it before sending.
   - (c) Any raw HTML tag in chat output? If YES → move the HTML into the Artifact and strip it from chat.
   - (d) Any FORBIDDEN positional phrasing OR directional word (right/left/side/panel/sidebar/面板/边/侧) in chat text? If YES → rewrite with ALLOWED phrasings.
7. Failing any of the above is a **rule violation** equivalent to skipping Token Guard. A response that sends a template sentence without the actual address value, or leaks raw HTML into chat, or skips the Artifact when the address is non-empty, all fall under this rule.

---

- ❌ Do NOT assume fiat or crypto — always confirm with the user if not explicitly stated
- ❌ Do NOT skip any STOP point — every STOP must wait for user input
- ❌ Do NOT fabricate wallet addresses, account numbers, or any financial data
- ❌ Do NOT skip either the address message OR the QR Artifact in crypto deposit STEP 3b. Sequence is fixed: chat message with the real `walletAddress` value **FIRST**, HTML Artifact **SECOND**. The chat message MUST contain the actual address string (not a `{walletAddress}` placeholder, not empty, not `null`) and MUST NOT contain any raw HTML tag (`<!DOCTYPE` / `<html` / `<script` / `<div` / `<style` / `<body` / `<head`). Location-neutral wording only — NEVER mention any panel / sidebar / right-hand side / 侧边栏 / 右侧 / 右边 / 右方 / 边栏 / 面板. See the QR Artifact Gate for the full contract, self-check, and allowed phrasings.
- ✅ All amounts displayed with thousands separators (e.g. 10,000 not 10000)
- ✅ **Account Overview**: after STEP 1 succeeds, MUST output the full 5-row, 3-column (Available, Pending, Total) account overview table. Never skip zero-balance rows. Never omit any column. Zero values display as `0.00`.
- ✅ **Language**: detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning/thinking, tool-call preambles, tool-parameter descriptions (e.g., TaskCreate subjects), and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English.
- ✅ **Branding**: always say **MetaComp Deposit** — never "MCP server" or "the server" alone
