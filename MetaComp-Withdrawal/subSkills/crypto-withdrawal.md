# Crypto Withdrawal Flow

This sub-skill defines the flow for withdrawing cryptocurrency from the user's MetaComp account to either their **own first-party wallet** or a **third-party beneficiary wallet**.

> **Third-party compliance documents:** Third-party withdrawals require `photo` and `proof` file IDs for regulatory compliance. These are hardcoded internally (`44046`) and **NOT displayed to the user**.

> **Token Guard applies to every MCP call in this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## STEP 1 — Determine Withdrawal Party

If the user has already specified first-party or third-party, record `withdrawalParty` (1 or 2) and skip to STEP 1.

Otherwise, ask concisely:

> 提现到哪里？
>
> 1. 自己的钱包（一方）
> 2. 他人的钱包（三方）

English:

> Withdraw to:
>
> 1. My own wallet (first-party)
> 2. Someone else's wallet (third-party)

⛔ **STOP.** Wait for the user's answer. Record `withdrawalParty` (1 or 2). Then **immediately** proceed to STEP 2 — do NOT add commentary or ask follow-up questions.

---

## STEP 2 — Show Available Currencies (mandatory, immediate)

**Immediately** after determining `withdrawalParty`, call `get_withdrawal_currencies({ currencyType: 2, withdrawalParty })`. Do NOT insert any additional questions or commentary between STEP 1 and this call.

### Case A — Empty list

> No crypto currencies are currently available for withdrawal.

⛔ **STOP.**

### Case B — At least one currency

**MUST render the full currency list as a numbered list.** Do NOT summarize, abbreviate, or skip any currencies. Display ALL returned currencies:

```
可提取的加密货币：

1. USDT
2. USDC
3. BTC
4. ETH
...

请选择要提取的币种。
```

English:

```
Available cryptocurrencies for withdrawal:

1. USDT
2. USDC
3. BTC
4. ETH
...

Which cryptocurrency would you like to withdraw?
```

⛔ **STOP.** Wait for the user to pick one.

---

## STEP 3 — Choose Wallet

Call `get_crypto_withdrawal_wallets({ withdrawalParty })`. The backend filters wallets by the selected party type; response is `{ wallets: Array<{ walletAddress, network, walletType, walletTag, relationType, ownerName, cryptoExchange }> }`.

### Case A — Empty list

> You have no registered wallets for this withdrawal type. Please register one in the MetaComp dashboard.

⛔ **STOP.**

### Case B — At least one wallet

Render:

```
Your registered wallets:

| # | Tag | Address | Network | Owner | Exchange |
|---|-----|---------|---------|-------|----------|
| 1 | {walletTag} | {walletAddress} | {network} | {ownerName} | {cryptoExchange or "self-custody"} |

Which wallet would you like to send the funds to?
```

Display rule: if `cryptoExchange` is empty string, show `"self-custody"` instead.

⛔ **STOP.** Wait for the user to pick one. Record the full selected wallet row as `selectedWallet`. The `network` field will be passed verbatim to `execute_crypto_withdrawal` in STEP 7 — do NOT ask the user to re-enter it.

---

## STEP 4 — Currency ↔ Network Compatibility Check

Call `get_crypto_deposit_networks({ currency })` → returns `{ networks: string[] }`. This tool is reused from the deposit flow; the list of networks supporting a given currency is the same regardless of direction.

### Case A — `selectedWallet.network` NOT in `networks`

> The wallet you picked is on **{selectedWallet.network}**, but **{currency}** is not supported on that network. Supported networks for {currency}: {networks.join(", ")}.
>
> Would you like to:
> 1. Pick a different currency (go back to STEP 2)
> 2. Pick a different wallet (go back to STEP 3)

⛔ **STOP.** Wait for the user's choice, then jump back to the chosen STEP.

### Case B — Network matches

Proceed to STEP 5.

---

## STEP 5 — Enter Amount; Fetch Minimum and Fee

Prompt for amount first (fee depends on amount):

```
Please tell me how much {currency} you want to withdraw.
```

⛔ **STOP.** On input, validate `amount > 0` and decimal-places compliance (crypto precision varies; for USDT/USDC assume 6, for BTC/ETH assume 8 if no product base list is available).

On input received, call **in parallel**:
- `get_withdrawal_minimum_amount({ currency })` → `{ minimumAmount }`
- `get_withdrawal_service_fee({ withdrawalParty, currency, amount })` → `{ serviceFee }`

If `amount < minimumAmount`:

> The minimum withdrawal for {currency} is {minimumAmount}. Please enter a larger amount.

Re-prompt for a new amount (stay on STEP 5, re-fetch both).

On success, proceed to STEP 6.

---

## STEP 6 — Confirm Card + Verification Code

Compute `amountReceived = amount - serviceFee`.

Render confirmation card:

```
Please confirm your crypto withdrawal:

| | |
|---|---|
| Currency | {currency} |
| Amount | {amount} |
| Network | {selectedWallet.network} |
| Destination wallet | {walletTag} — {walletAddress} |
| Owner | {ownerName} ({withdrawalParty === 1 ? "first-party" : "third-party"}) |
| Service fee | {serviceFee} {currency} |
| You will receive | {amountReceived} |

⚠ **Irreversible operation.** Once submitted, the on-chain transaction cannot be recalled. Please verify the destination address and network are exactly correct, and provide your **verification code** (the 6-digit code from your authenticator app, e.g. Google Authenticator).
```

⛔ **STOP.** Wait for:
1. Explicit confirmation ("yes/确认/好/ok"), **and**
2. A `verificationCode` string.

If the user only confirms without a code, ask once for the code. If only a code without confirmation, ask once for explicit confirmation.

On both received → proceed to STEP 7.

---

## STEP 7 — Execute

### First-party (`withdrawalParty === 1`)

```
execute_crypto_withdrawal({
  withdrawalParty: 1,
  currency,
  amount,
  walletAddress: selectedWallet.walletAddress,
  network: selectedWallet.network,
  verificationCode
})
```

Do NOT pass `photo` or `proof` — first-party does not need compliance documents.

### Third-party (`withdrawalParty === 2`)

```
execute_crypto_withdrawal({
  withdrawalParty: 2,
  currency,
  amount,
  walletAddress: selectedWallet.walletAddress,
  network: selectedWallet.network,
  verificationCode,
  photo: 44046,
  proof: 44046
})
```

> `photo` and `proof` are hardcoded compliance file IDs — do NOT display or mention them to the user.

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
| Amount received | {amountReceived} | ← if present
| Destination | {to} |               ← if present
| Network | {network} |              ← if present
| Time | {createAt} |                ← if present

On-chain confirmation typically takes a few minutes.
```

Then **STOP** (flow complete).

### On failure — Token Guard (check FIRST)

If response contains `success: false` with `authPageUrl` → follow **Token Guard** rule in SKILL.md Absolute Rules. Do NOT proceed to error handling below.

### On failure — step-specific

- If the backend `msg` indicates "invalid verification code" / "expired code" / similar → output:
  > Your verification code is invalid or expired. Please open your authenticator app, get the current 6-digit code, and paste it here.

  Go back to the final prompt of STEP 6 (keep everything else; wait only for a new code).

- Any other backend error → display the backend `msg` verbatim and **STOP**.

---

## Display Rules

- Amounts with thousands separators (`10,000` not `10000`)
- Do NOT fabricate fields; show only fields returned by the API
- Wallet addresses shown in full (no truncation)
- Language follows user; mixed → English

---

## Tool Reference

### `get_withdrawal_currencies`
```json
{ "currencyType": 2, "withdrawalParty": 1 }
```
Returns: `{ currencies: string[] }` — crypto currency codes available for withdrawal. Use `withdrawalParty: 1` for first-party, `2` for third-party.

### `get_crypto_withdrawal_wallets`
```json
{ "withdrawalParty": 1 }
```
Returns: `{ wallets: Array<{ walletAddress, network, walletType, walletTag, relationType, ownerName, cryptoExchange }> }`. Use `withdrawalParty: 1` for first-party, `2` for third-party.

### `get_crypto_deposit_networks`
```json
{ "currency": "USDT" }
```
Returns: `{ networks: string[] }` — networks that support the given currency. Reused from deposit flow for compatibility checking.

### `get_withdrawal_minimum_amount`
```json
{ "currency": "USDT" }
```
Returns: `{ minimumAmount: number }` — minimum withdrawal in the currency's native units.

### `get_withdrawal_service_fee`
```json
{ "withdrawalParty": 1, "currency": "USDT", "amount": "500" }
```
Returns: `{ serviceFee: string }` — the calculated service fee deducted from the withdrawal amount. The fee logic is handled server-side; use the returned value as-is.

### `execute_crypto_withdrawal`

First-party example:
```json
{
  "withdrawalParty": 1,
  "currency": "USDT",
  "amount": "500",
  "walletAddress": "0xABC...",
  "network": "ETH",
  "verificationCode": "123456"
}
```

Third-party example (compliance file IDs are internal, not shown to user):
```json
{
  "withdrawalParty": 2,
  "currency": "USDT",
  "amount": "500",
  "walletAddress": "0xABC...",
  "network": "ETH",
  "verificationCode": "123456",
  "photo": 44046,
  "proof": 44046
}
```

Returns: `{ txCode, currency, status, withdrawalAmount?, chargeAmount?, totalChargeAmount?, amountReceived?, to?, network?, createAt?, updateAt? }`.
