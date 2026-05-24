# Fiat Withdrawal Flow (First-Party Only)

This sub-skill defines the flow for withdrawing fiat currency from the user's MetaComp account **to their own first-party bank account**. Third-party fiat withdrawal is explicitly out of scope for this skill.

> **Token Guard applies to every MCP call in this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## STEP 1 — Choose Currency

Call `get_withdrawal_currencies({ currencyType: 1, withdrawalParty: 1 })`.

### Case A — Empty list

> No fiat currencies are currently available for withdrawal. Please contact MetaComp support.

⛔ **STOP.**

### Case B — At least one currency

Render the list (English / Chinese depending on user language):

```
Which fiat currency would you like to withdraw?

1. USD
2. SGD
...
```

⛔ **STOP.** Wait for the user to pick one.

---

## STEP 2 — Choose First-Party Bank Account

Call `get_withdrawal_bank_accounts()`. The response is `{ accounts: Array<{ baTag, baNumber, ownerName, relationType }> }` and contains both first-party (`relationType === 1`) and third-party (`relationType === 2`) entries.

**Filter to `relationType === 1` only.**

### Case A — Filtered list empty

> You have no first-party bank accounts on file. Please register one in the MetaComp dashboard before withdrawing.

⛔ **STOP.**

### Case B — At least one first-party account

Render as a numbered table:

```
Your first-party bank accounts for {currency}:

| # | Tag | Account Number | Owner |
|---|-----|----------------|-------|
| 1 | {baTag} | {baNumber} | {ownerName} |

Which account would you like to receive the funds in?
```

⛔ **STOP.** Wait for the user to pick one. Record the selected `{baNumber}` as `bankAccountNumber` for STEP 5.

---

## STEP 3 — Enter Amount

Call `get_withdrawal_minimum_amount({ currency })` → returns `{ minimumAmount }`.

Prompt:

```
The minimum withdrawal for {currency} is {minimumAmount}. How much would you like to withdraw?
```

⛔ **STOP.** When the user replies with a number, validate:

- `amount > 0`
- `amount >= minimumAmount`
- Decimal places ≤ the currency's precision (fiat is typically 2; if unsure, allow 2)

Validation failure templates:

- `amount <= 0`: "Amount must be greater than zero. Please enter a new amount."
- `amount < minimumAmount`: "The minimum withdrawal for {currency} is {minimumAmount}. Please enter a larger amount."
- Too many decimal places: "{currency} supports at most {decimals} decimal places. Please enter a new amount."

On any validation failure → re-prompt (stay on STEP 3). On success → proceed to STEP 4.

---

## STEP 4 — Show Service Fee and Confirm

Call `get_withdrawal_service_fee({ withdrawalParty: 1, currency, amount })` → returns `{ serviceFee }`.

Compute `amountReceived = amount - serviceFee` (string math; keep the same decimal places as `amount`).

Render confirmation card:

```
Please confirm your fiat withdrawal:

| | |
|---|---|
| Currency | {currency} |
| Amount | {amount} |
| Service fee | {serviceFee} |
| You will receive | {amountReceived} |
| Destination | {baTag} — {baNumber} ({ownerName}) |

Please confirm the details above (reply "yes/确认/好"), and provide your **verification code** (the 6-digit code from your authenticator app, e.g. Google Authenticator).
```

⛔ **STOP.** Wait for:
1. Explicit confirmation ("yes/确认/好/ok"), **and**
2. A `verificationCode` string.

If the user only confirms but does not include a code, ask once: "Please also provide your verification code." If the user only provides a code but did not confirm, ask once: "Can you confirm the details above before I submit?"

On both received → proceed to STEP 5.

---

## STEP 5 — Execute

Call:

```
execute_fiat_withdrawal({
  withdrawalParty: 1,
  currency,
  amount,
  bankAccountNumber,
  verificationCode
})
```

**Do NOT pass `chargeType`** — first-party does not need it.

### On success

Render result card (only show rows where the field is present in the response):

```
✅ **Withdrawal Submitted**

| | |
|---|---|
| TX Code | {txCode} |
| Currency | {currency} |
| Status | {status} (pending) |
| Amount | {withdrawalAmount} |       ← if present
| Service fee | {chargeAmount} |      ← if present
| You will receive | {amountReceived} | ← if present
| Destination | {to} |               ← if present
| Time | {createAt} |                 ← if present

Fiat bank transfers typically complete within 1–3 business days.
```

Then **STOP** (flow complete).

### On failure — Token Guard (check FIRST)

If response contains `success: false` with `authPageUrl` → follow **Token Guard** rule in SKILL.md Absolute Rules. Do NOT proceed to error handling below.

### On failure — step-specific

- If the backend `msg` indicates "invalid verification code" / "expired code" / similar → output:
  > Your verification code is invalid or expired. Please open your authenticator app, get the current 6-digit code, and paste it here.

  Go back to the final prompt of STEP 4 (keep everything else collected; wait only for a new `verificationCode`).

- If response contains `success: false` **and** `code: 30009` (msg typically starts with `InteBank Infor Error`) → the beneficiary bank record is missing intermediary (correspondent) bank information. Output the bilingual message below and **STOP**. Do NOT retry automatically — the user must add the information on the MetaComp portal first.

  **English:**
  > ⚠ The beneficiary bank record is missing **intermediary bank** information (error code `30009` — InteBank Infor Error). Please go to the [MetaComp portal](https://camp.mce.sg), open this beneficiary account, and add the intermediary/correspondent bank details. Once saved, let me know and we can retry the withdrawal.

  **Chinese:**
  > ⚠ 该收款银行账户缺少**中间行**信息（错误码 `30009` — InteBank Infor Error）。请前往 [MetaComp 官网](https://camp.mce.sg)，打开该收款账户并补充中间行信息。补充完成后告诉我，我们再重新尝试出金。

- Any other backend error → display the backend `msg` verbatim and **STOP**.

---

## Display Rules

- Amounts with thousands separators (`10,000` not `10000`)
- Do NOT fabricate fields; show only fields returned by the API
- Account numbers shown in full (no truncation)
- Language follows user; mixed → English

---

## Tool Reference

### `get_withdrawal_currencies`
```json
{ "currencyType": 1, "withdrawalParty": 1 }
```
Returns: `{ currencies: string[] }` — fiat currency codes the user can withdraw to their own bank account. This list is pre-filtered to only include currencies where MetaComp has a configured receiving bank account, so all returned currencies are guaranteed to be executable.

### `get_withdrawal_bank_accounts`
```json
{}
```
Returns: `{ accounts: Array<{ baTag, baNumber, ownerName, relationType }> }`. Skill filters to `relationType === 1` (first-party).

### `get_withdrawal_minimum_amount`
```json
{ "currency": "USD" }
```
Returns: `{ minimumAmount: number }` — minimum amount per transaction.

### `get_withdrawal_service_fee`
```json
{ "withdrawalParty": 1, "currency": "USD", "amount": "500" }
```
Returns: `{ serviceFee: string }` — the calculated service fee deducted from the withdrawal amount. The fee logic is handled server-side; use the returned value as-is.

### `execute_fiat_withdrawal`
```json
{
  "withdrawalParty": 1,
  "currency": "USD",
  "amount": "500",
  "bankAccountNumber": "HSBC123456",
  "verificationCode": "123456"
}
```
Returns: `{ txCode, currency, status, withdrawalAmount?, chargeAmount?, totalChargeAmount?, amountReceived?, to?, network?, createAt?, updateAt? }`. Only `txCode`, `currency`, and `status` are guaranteed; display other fields only when present.
