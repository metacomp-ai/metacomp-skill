---
name: MetaComp-Withdrawal
version: 0.4.1
description: >
  Withdraw funds out of MetaComp Withdrawal account.
  Trigger when the user mentions: withdraw, withdrawal, send money, cash out,
  提现, 出金, 转出, 取钱, 我要出金, 我要提现.
metadata:
  mcpServers:
    - metacomp mcp
---

# STEP ZERO — READ SUB-SKILLS THEN OUTPUT CONFIRMATION

Before writing a single word, before calling any MCP tool:

**Step A — Read all sub-skill files:**
1. `subSkills/fiat-withdrawal.md`
2. `subSkills/crypto-withdrawal.md`
3. `subSkills/wealth-recommendation.md`

**Step B — Output this line verbatim as the FIRST visible output:**

> Sub-files have been read: fiat-withdrawal ✓ / crypto-withdrawal ✓ / wealth-recommendation ✓

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

> 🔁 **Resume checklist (do not skip any step):** after the re-call succeeds on Case C, walk through the full post-overview sequence in order — **(1) Account Overview table → (2) Per-Currency Detail → (3) Wealth Product Recommendation trigger evaluation → (4) STEP 2**. A continuation reply like "go on" / "继续" / "I've logged in" is a flow-control signal; it does NOT override the **original triggering message** when evaluating WEALTH_RECOMMENDATION_TRIGGER condition 5. Evaluate that condition against the user's original intent, not the continuation.

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

After rendering the Account Overview **and before STEP 2**, evaluate the WEALTH_RECOMMENDATION_TRIGGER (defined in `subSkills/wealth-recommendation.md`). If TRUE, follow the recommendation flow in that file — call `investor_precheck`, then conditionally `get_fip_products`, and render the appropriate template. This recommendation is informational only and does NOT replace or delay STEP 2. The evaluation must still be performed when resuming after a Token Guard login — do not skip it.

Then proceed to **STEP 2**.

---

# STEP 2 — Route: Fiat or Crypto?

If the user has already specified the type (e.g. "我要出 USDT", "withdraw 500 USD"), skip the question and route directly.

Otherwise, ask:

> Would you like to withdraw **fiat currency** or **cryptocurrency**?
>
> 1. Fiat currency (e.g. USD, SGD, EUR, GBP)
> 2. Cryptocurrency (e.g. USDT, USDC, BTC, ETH)

⛔ **STOP.** Wait for the user's answer.

→ **Fiat:** follow `subSkills/fiat-withdrawal.md`, starting from its STEP 1.
→ **Crypto:** follow `subSkills/crypto-withdrawal.md`, starting from its **STEP 0** (determines first-party vs third-party).

---

# MetaComp Withdrawal — Server Setup Guide

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
Returns account balances. Used here for authentication check.

### Fiat-specific tools
See `subSkills/fiat-withdrawal.md` for tool details.

### Crypto-specific tools
See `subSkills/crypto-withdrawal.md` for tool details.

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

1. **Before you output** any terminal/closing message (the STEP 2 routing question "Would you like to withdraw fiat currency or cryptocurrency?" / any similar handoff line), you MUST have completed the following **sequential** evaluation:

   **Step A — Evaluate ALL 5 conditions of WEALTH_RECOMMENDATION_TRIGGER** (defined in `subSkills/wealth-recommendation.md`). This evaluation is mandatory and must happen BEFORE any tool call. There is NO path that skips this evaluation.

   **Step B — Branch on result:**
   - **All 5 conditions TRUE** → call `investor_precheck`, then follow the recommendation flow in `subSkills/wealth-recommendation.md`.
   - **Any condition FALSE** → record which specific condition (1–5, including sub-clause 5a/5b/5c) evaluated FALSE and why. Do NOT call `investor_precheck`. Proceed directly to the closing message.

   ⛔ **There is no legitimate path where `investor_precheck` is called without first confirming all 5 conditions are TRUE.** Calling `investor_precheck` "just in case" or "to be safe" when condition 5 is FALSE is a rule violation — it wastes an API call and may render an unwanted recommendation to a user with clear business intent.

2. **Evaluation is mandatory, render is non-blocking.** "Non-blocking" in `wealth-recommendation.md` refers ONLY to the rendered output (the recommendation block never halts the primary flow). The evaluation itself is **not skippable** under any circumstance where conditions 1-2 hold (overview rendered + not MetaComp-Wealth). Treating the evaluation as optional is a rule violation.

3. **Self-check (mandatory before sending response):** Re-read your draft:
   - If it contains a recommendation block (product catalog) BUT the original triggering message had clear business intent (e.g. "withdraw USD", "我要出金 USDT") → your draft is INVALID. Condition 5 should have been FALSE. Remove the recommendation, do NOT call `investor_precheck`, and proceed directly to the closing message.
   - If it contains the closing sentence BUT you did NOT evaluate the 5 conditions at all → your draft is INVALID. Go back to Step A.

4. A response that calls `investor_precheck` when condition 5 is FALSE, or that reaches the closing message without evaluating the 5 conditions, is treated the same as skipping Token Guard — a rule violation.

**This rule takes priority over the phrasing of the "Wealth Product Recommendation (non-blocking)" section in STEP 1** — that heading describes the *render* as non-blocking; the *evaluation* is mandatory per this Gate.

---

- ❌ Do NOT assume fiat or crypto — always confirm with the user if not explicitly stated
- ❌ Do NOT skip any STOP point — every STOP must wait for user input
- ❌ Do NOT fabricate bank account numbers, wallet addresses, or any financial data
- ❌ Do NOT fabricate or pre-fill `verificationCode` — the user must type it themselves
- ❌ Do NOT skip the irreversibility warning on crypto confirmation (STEP 5 of crypto-withdrawal)
- ❌ Do NOT send `chargeType` when executing a first-party fiat withdrawal
- ❌ Do NOT send `photo` / `proof` when executing a first-party crypto withdrawal
- ❌ Do NOT attempt third-party (beneficiary) **fiat** flows — fiat third-party withdrawal is not supported in this skill yet. If the user asks for third-party fiat, say: "Third-party fiat withdrawal is not supported in this skill yet. Please use the MetaComp dashboard."
- ✅ Third-party **crypto** withdrawal IS supported — see `subSkills/crypto-withdrawal.md` for the flow (uses hardcoded demo file IDs for compliance documents)
- ✅ Always record the selected wallet's `network` from `get_crypto_withdrawal_wallets` and pass it verbatim to `execute_crypto_withdrawal` (do not re-ask the user)
- ✅ All amounts displayed with thousands separators (e.g. 10,000 not 10000)
- ✅ **Account Overview**: after STEP 1 succeeds, MUST output the full 5-row, 3-column (Available, Pending, Total) account overview table. Never skip zero-balance rows. Never omit any column. Zero values display as `0.00`.
- ✅ **Language**: detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning/thinking, tool-call preambles, tool-parameter descriptions (e.g., TaskCreate subjects), and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English.
- ✅ **Branding**: always say **MetaComp Withdrawal** — never "MCP server" or "the server" alone
