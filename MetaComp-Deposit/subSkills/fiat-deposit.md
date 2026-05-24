# Fiat Deposit Flow

This sub-skill defines the flow for depositing fiat currency into the user's MetaComp account.

> **Token Guard applies to every MCP call in this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## STEP 1 — Resolve Currency (bypass when already known)

**Normal entry path:** SKILL.md STEP 2 has already presented the unified currency list and the user selected a fiat currency. SKILL.md routes directly into STEP 2 of this file with `currency = <user's choice>`. **Skip this STEP 1 entirely.**

**Defensive entry path:** Only if this sub-skill is somehow entered without a known `currency` (edge case — not the normal flow), execute the fallback below:

Call `get_fiat_deposit_currencies`.

### Case A — Empty list

> No fiat currencies are currently available for deposit. Please contact MetaComp support.

⛔ **STOP.**

### Case B — At least one currency

> What fiat currency would you like to receive?

Display the full currency list. ⛔ **STOP.** Wait for the user to choose, then proceed to STEP 2.

---

## STEP 2 — Prefer Same-Name Account, Fall Back to Big Account

After the user selects a currency (e.g. USD), decide which receiving account to show by calling two tools in sequence:

1. Call `get_named_account_currencies` → `{ currencies: string[] }` — the fiat currencies that support same-name (同名) transfers for this user.
2. **Branch on membership:**
   - If `currency` is in `currencies` → **Case B (same-name account)**: call `get_named_account_list` → render the user's registered same-name accounts.
   - Otherwise → **Case A (big account)**: call `get_deposit_bank_account(currency)` → render MetaComp's receiving account.

> Rationale: when the user has a registered bank account in their own name for this currency, wiring from their own account is faster and avoids AML friction. Only fall back to MetaComp's central receiving account when no same-name account is available.

### Case A — No same-name account (use big account)

Call `get_deposit_bank_account(currency)` → `{ accounts: Array<{ ownerName, ownerAddress, ownerCountryCode, baNumber, swiftCode, bankName, bankAddress, countryCode }> }`. Render the first account (or all if multiple):

### English

```
Your MetaComp receiving account for {currency}:

| | |
|---|---|
| Account Name | {ownerName} |
| Account Address | {ownerAddress} |
| Country | {ownerCountryCode} |
| Account Number (IBAN) | {baNumber} |
| SWIFT Code | {swiftCode} |
| Bank Name | {bankName} |
| Bank Address | {bankAddress} |
| Bank Country | {countryCode} |

Please share these details with the sender to complete the transfer.
```

### Chinese

```
您的 MetaComp {currency} 收款账户信息：

| | |
|---|---|
| 账户名称 | {ownerName} |
| 账户地址 | {ownerAddress} |
| 国家 | {ownerCountryCode} |
| 账户号码 (IBAN) | {baNumber} |
| SWIFT 代码 | {swiftCode} |
| 银行名称 | {bankName} |
| 银行地址 | {bankAddress} |
| 银行国家 | {countryCode} |

请将以上信息发送给汇款方，以完成转账。
```

### Case B — Has same-name account(s)

Call `get_named_account_list` → `{ accounts: Array<{ ownerName, ownerAddress, ownerCountryCode, baNumber, swiftCode, bankName, bankAddress, countryCode }> }`.

- If `accounts` is empty, **fall back to Case A** (this can happen if `get_named_account_currencies` reported support but the user has not registered a specific account yet).
- Otherwise, render all entries as separate cards (one per account).

### English

```
You have same-name account(s) registered for {currency}. Please use one of your own bank accounts below:

**Account 1**

| | |
|---|---|
| Account Name | {ownerName} |
| Account Address | {ownerAddress} |
| Country | {ownerCountryCode} |
| Account Number (IBAN) | {baNumber} |
| SWIFT Code | {swiftCode} |
| Bank Name | {bankName} |
| Bank Address | {bankAddress} |
| Bank Country | {countryCode} |

(repeat the block above for each additional account)

Please ask the sender (yourself) to initiate the wire from one of these accounts.
```

### Chinese

```
您为 {currency} 注册的同名账户如下，请使用您本人的以下账户汇款：

**账户 1**

| | |
|---|---|
| 账户名称 | {ownerName} |
| 账户地址 | {ownerAddress} |
| 国家 | {ownerCountryCode} |
| 账户号码 (IBAN) | {baNumber} |
| SWIFT 代码 | {swiftCode} |
| 银行名称 | {bankName} |
| 银行地址 | {bankAddress} |
| 银行国家 | {countryCode} |

（如有多个同名账户，按上方格式依次展开）

请您本人从上述账户之一发起汇款。
```

---

## Display Rules

- All account/bank fields come directly from the API response — do NOT fabricate or assume any values
- Display all fields returned by the API, not just the examples above
- Sensitive fields (account number, SWIFT, etc.) should be displayed in full — the user needs to share them with the sender

---

## STEP 3 — Wait for Transfer

After displaying the receiving account, the conversation pauses. The user will come back when the sender has initiated the transfer.

Typical user message: "帮我看看钱到账了吗", "Has the transfer arrived?", "Check my balance"

---

## STEP 4 — Verify Transfer via Deposit List

Call `get_deposit_list(pageNum=1, pageSize=5, payeeAccountType=1)` — `payeeAccountType=1` is fixed because this sub-skill handles fiat deposits.

### Case A — Empty list

> No recent fiat deposits found. Bank transfers can take 1–3 business days to settle. Please confirm the sender has initiated the transfer, then let me know when to check again.

⛔ **STOP.** Wait for the user.

### Case B — At least one record

Render the most recent 5 records (the response is already newest-first):

### English

```
Here are your most recent fiat deposits:

| # | Payment Code | Currency | Amount | Status | Payer | Time |
|---|---|---|---|---|---|---|
| 1 | {paymentCode} | {currency} | {amount_display} | {status_display} | {payerName} | {createAt_local} |

Which one is your transfer? I'll show its status.
```

### Chinese

```
以下是您最近的法币入金记录：

| # | Payment Code | 币种 | 金额 | 状态 | 付款方 | 时间 |
|---|---|---|---|---|---|---|
| 1 | {paymentCode} | {currency} | {amount_display} | {status_display} | {payerName} | {createAt_local} |

请告诉我哪一条是您本次的入金，我会为您查看状态。
```

### Display Rules

- `amount_display = totalAmount / 10^decimals`, with thousands separators.
- `status_display`: use `statusDesc` if non-null; otherwise map the `status` code using the table below.
- `createAt_local` = `createAt` formatted as the user's locale + timezone.

#### Deposit Status Mapping

| Code | English | 中文 | Category |
|------|---------|------|----------|
| 1 | Initialized | 已创建 | pending |
| 2 | Pending | 待处理 | pending |
| 3 | Processing | 处理中 | pending |
| 4 | Pending Checker Review | 待审核 | pending |
| 5 | Pending Compliance Review | 待合规审核 | pending |
| 6 | Pending Settlement Approval | 待结算审批 | pending |
| 7 | **Completed** | **已完成** | **success** |
| 8 | Rejected | 已拒绝 | failed |
| 9 | Cancelled | 已取消 | failed |
| 10 | Pending Deposit Requirement | 待补充入金要求 | pending |
| 11 | Pending L1 Review | 待一级审核 | pending |
| 12 | Pending L2 Review | 待二级审核 | pending |
| 13 | Pending Maker Review | 待制单审核 | pending |
| 14 | Draft | 草稿 | pending |
| 15 | To Be Swept | 待归集 | pending |
| 16 | To Be Jailed | 待隔离 | pending |
| 17 | Jailed | 已隔离 | jailed |
| 18 | To Be Refunded | 待退款 | jailed |
| 19 | Refunded | 已退款 | refunded |
| 20 | Expired | 已过期 | failed |
| 21 | Pending Sweep | 待归集处理 | pending |
| 22 | Pending Jail | 待隔离处理 | pending |
| 23 | Pending Block Confirmation | 待区块确认 | pending |
| 24 | Pending KYT | 待 KYT 检查 | pending |
| 25 | Pending Refund Request | 待退款申请 | pending |
| 26 | Pending Missing Filed | 待补充材料 | pending |
| 27 | Pending VASP Message | 待 VASP 消息 | pending |

Unknown codes → display `Status code {status}`.

⛔ **STOP.** Wait for the user to pick a row.

### After user selects

- If `status === 7` (Completed) → show the Transfer Received template below.
- If category is `failed` (`status` 8, 9, 20) → show the status label and explain the deposit was not successful.
- If category is `jailed` or `refunded` (`status` 17, 18, 19) → show the status label and advise contacting MetaComp support.
- Otherwise (all `pending` statuses) → show the Transfer Pending template.

### Transfer Received — English

```
✅ **Transfer Received**

| | |
|---|---|
| Payment Code | {paymentCode} |
| Currency | {currency} |
| Amount | {amount_display} |
| Payer | {payerName} |
| Time | {createAt_local} |
```

### Transfer Received — Chinese

```
✅ **转账已到账**

| | |
|---|---|
| Payment Code | {paymentCode} |
| 币种 | {currency} |
| 金额 | {amount_display} |
| 付款方 | {payerName} |
| 时间 | {createAt_local} |
```

### Transfer Pending — English

```
⏳ **Transfer Pending**

Your deposit is still being processed. Bank transfers typically settle within 1–3 business days depending on the banks involved and cut-off times. Would you like me to check again later?
```

### Transfer Pending — Chinese

```
⏳ **转账处理中**

您的入金仍在处理中。银行转账通常在 1–3 个工作日内完成，具体时间取决于相关银行及截止时间。需要我稍后再为您查询吗？
```

---

## Tool Reference

### `get_fiat_deposit_currencies`
```json
{}
```
Returns: `{ currencies: string[] }` — fiat currency codes the user can deposit (e.g. `["USD", "EUR", "SGD"]`).

### `get_named_account_currencies`
```json
{}
```
Returns: `{ currencies: string[] }` — fiat currencies that support same-name (first-party) transfers for this user.

### `get_named_account_list`
```json
{}
```
Returns: `{ accounts: Array<{ ownerName, ownerAddress, ownerCountryCode, baNumber, swiftCode, bankName, bankAddress, countryCode }> }` — the user's registered same-name bank accounts (currency-agnostic).

### `get_deposit_bank_account`
```json
{ "currency": "USD" }
```
Returns: `{ accounts: Array<{ ownerName, ownerAddress, ownerCountryCode, baNumber, swiftCode, bankName, bankAddress, countryCode }> }` — MetaComp's central receiving account for the given currency.

### `get_deposit_list`
```json
{ "pageNum": 1, "pageSize": 5, "payeeAccountType": 1 }
```
Returns paginated fiat deposit records (newest first). Amounts are in minor units — divide by 10^decimals before display.
