# Withdraw scenario

Entered from SKILL.md after the shared STEP 1 (`../shared/auth-kyc-setup.md`): session verified, Account Overview + Per-Currency Detail rendered, **Wealth Evaluation Gate** evaluated. This file is STEP 2 onward.

---

# STEP 2 — Route: Fiat, Crypto, or History?

If the user already specified the type (e.g. "我要出 USDT", "withdraw 500 USD"), skip the question and route directly.

Otherwise, ask:

> Would you like to withdraw **fiat currency** or **cryptocurrency**?
>
> 1. Fiat currency (e.g. USD, SGD, EUR, GBP)
> 2. Cryptocurrency (e.g. USDT, USDC, BTC, ETH)

⛔ **STOP.** Wait for the user's answer.

Routing:
- **Roster query** — if the user only wants to *see which bank accounts they have registered* (no money-movement intent — "我的银行账户有哪些", "查看我的银行卡 / 收款账户", "what bank accounts do I have", "list my withdrawal accounts") → follow the **Account Roster (read-only)** section below. Do NOT enter an initiation flow or ask for an amount.
- **History query** — if the user is asking about *past* withdrawals (status, "did it go through", listing, "show my history", 出金记录) → follow `withdrawal-history.md`. Do NOT enter the initiation flows below.
- **Fiat** → `fiat-withdrawal.md`, from its STEP 1.
- **Crypto** → `crypto-withdrawal.md`, from its STEP 1 (it determines first-party vs third-party).

---

# Account Roster (read-only) — list registered bank accounts WITH their party label

Reached either as the standalone **accounts** scenario (routed directly here by SKILL.md — no Account Overview, no Wealth Gate) or when a user already inside the withdraw flow asks to see their accounts. The whole point of this view is the **first-party / third-party / same-name** label — that is the question the user is implicitly asking ("which of these are mine vs someone else's?"), so it must be visible per account, never omitted.

Fetch all registries (in parallel if possible; Token Guard applies to each):
- `get_fiat_withdrawal_bank_accounts({ withdrawalParty: 1 })` → first-party regular accounts, and `get_fiat_withdrawal_bank_accounts({ withdrawalParty: 2 })` → third-party regular accounts (the tool filters by party server-side). Each row still carries `relationType` (1 = first-party, 2 = third-party); combine both lists for the roster.
- `get_named_account_list()` → same-name accounts (a separate registry; their party is chosen at withdrawal time, so list them under their own heading rather than guessing a party).

Group and render under three headings; **omit a group that is empty**, and render **every** account in a group (never just the first row):

```
Your registered bank accounts / 您已注册的银行账户：

**First-party (your own) / 一方（本人）**
| # | Account # / 账号 | Owner / 户名 | Bank / 银行 |
|---|---|---|---|
| 1 | {baNumber} | {ownerName} | {bankName or swiftCode} |

**Third-party / 三方**
| # | Account # / 账号 | Owner / 户名 | Bank / 银行 | Relationship / 关系 |
|---|---|---|---|---|
| … | {baNumber} | {ownerName} | {bankName or swiftCode} | {relationship} |

**Same-name / 同名**
| # | Account # / 账号 | Owner / 户名 | Bank / 银行 |
|---|---|---|---|
| … | {baNumber} | {ownerName} | {bankName or swiftCode} |
```

Rules:
- The party heading **is** the label — derive first-party vs third-party from `relationType` (1 → first-party, 2 → third-party); never infer it from the name. For third-party, also show `relationship` when present (e.g. "supplier", "spouse") since that is the detail the user cares about.
- All accounts are read straight from the system response — this is a read-only view; do NOT accept or invite a typed account, and do NOT start a withdrawal (SKILL.md → Destination Source of Truth still applies).
- **Empty everywhere** → tell the user they have no bank accounts registered yet and can add one in the [MetaComp dashboard](https://camp.mce.sg/). Do not error out.
- Close by offering the natural next step in one line: *"Want to withdraw to one of these, or add another in the [MetaComp dashboard](https://camp.mce.sg/)? / 需要提现到其中某个账户，或在 [MetaComp 控制台](https://camp.mce.sg/) 再添加一个吗？"*

---

# Tool Reference (withdraw-specific)

Fiat-specific tools → see `fiat-withdrawal.md`. Crypto-specific tools → see `crypto-withdrawal.md`. History → see `withdrawal-history.md`.

---

# Scenario Absolute Rules (withdraw)

## Auto-collapse forced choices (apply in both fiat and crypto sub-skills)

Each initiation sub-skill begins with a silent **STEP 0** that probes what the user has actually registered before asking which party (and, for fiat, same-name vs not). The principle: make the most useful default decision *for* the user and only ask about real choices.

- A party / same-name axis with **exactly one** viable value → the skill picks it silently and says so in one line, inviting a natural-language override ("if it should go elsewhere, just tell me").
- An axis with **two** viable values → ask, exactly as before.
- An axis (or a pinned value) with **no** registered, usable destination → the existing register-in-dashboard empty-state; ⛔ STOP.

A pin or natural-language override that names a destination type with **no** registered account/wallet routes to that type's empty-state — **never** a silent switch to the other type. This is SKILL.md → **Destination Source of Truth** applied at selection time: STEP 0 resolves only the classification flags by *reading* system lists; the concrete account/wallet is still fetched and picked from the list in the later selection step, never user-typed.

## Cancel / Back / Confirm Keywords (apply in every withdraw sub-skill)

Before interpreting any user message as a step-specific input, check these keywords FIRST — they override step-specific parsing:

- **Cancel**: 取消 / cancel / 放弃 / abort → clear all collected inputs, exit to SKILL.md entry. Output:
  > Withdrawal cancelled. Let me know when you want to try again. / 已取消本次提现。您随时可以重新发起。
- **Back / Previous step**: 返回 / back / 上一步 / previous → return to the most recent step that accepted user input; skip intermediate auto-steps. Output:
  > Going back to the previous step. / 返回上一步。
- **Confirm** (only at the confirmation card): 确认 / confirm / 确定 / yes / 是 → proceed to execute.

At a confirmation card, prompt:
> Type "confirm" to proceed, "back" to edit, or "cancel" to abort. / 输入"确认"继续，"返回"修改，"取消"退出。

## Submit Gate — Write Operation Confirmation

**Same priority as Token Guard.** Applies to any `execute_*_withdrawal` write tool. Estimate-first, explicit post-estimate confirmation (`confirm` / `确认` / `yes` / `是`), structured submit response. Crypto withdrawal additionally requires the irreversibility warning at the confirmation card (STEP 8 of `crypto-withdrawal.md`) — never skip it. See `crypto-withdrawal.md` / `fiat-withdrawal.md` for the per-flow confirmation cards.

**Funds-First precondition (SKILL.md → Funds-First Gate).** Before that confirmation card and the verification code, the balance must already be confirmed to cover the **total debit** (`get_withdrawal_quote` → `balance.sufficient`, compared against `fee.withdrawalAmount`, not the recipient amount). A `sufficient:false` (or a fresh `get_account_detail` showing a shortfall) stops the flow with the shortfall message — it never reaches the card or the code. This is the fix for the "walked all 7 steps + entered a TOTP, then failed at execute on 0 balance" case.

## Verification Code Is the Last Input (apply in every withdraw sub-skill)

**Same priority as Token Guard.** The 6-digit verification code (2FA) is bound to the confirmation card and is **the final input before submit**. Never request any other data — supporting-document upload, purpose, amount, wallet — *after* asking for the code. For third-party crypto withdrawal in particular, purpose (STEP 6) and document upload (STEP 7) come **before** the confirmation card + code (STEP 8); if you find yourself wanting an upload right after a code, you skipped a step — rewind to it, re-show the card, then re-ask the code. The code authorizes the exact reviewed transaction, and TOTP codes expire, so collecting anything after it is always wrong. See the "Verification Code Is the Terminal Input" rule in `crypto-withdrawal.md` for the full rationale and recovery path.

## Fresh Per-Flow Parameters — No Cross-Flow Inheritance (apply in every withdraw sub-skill)

**Same priority as Token Guard.** Every withdrawal is a clean slate. **Never inherit any value from a previous withdrawal flow** in the same conversation — re-collect `currency`, `amount`, the destination account/wallet, `withdrawalParty`, `isSameNameAccount`, `chargeType`, `purposeOfTransaction`, `verificationCode`, and `fileRef` from scratch for the new flow (a `fileRef` is in particular never reused across flows — see the dedicated `fileRef` rule in Scenario don'ts below).

- The moment a new withdrawal starts (a fresh "I want to withdraw …", or a follow-up like "send another 200"), discard all parameters collected for the prior flow. A value the user states in the new request (e.g. the amount in "send another 200") seeds **only** that one field of the new flow; it never pulls in the prior destination, party, fee choice, or any other parameter — those are re-collected and re-confirmed from scratch.
- The confirmation card MUST be rebuilt **only** from values (re-)collected in the current flow. Do not pre-fill it from a prior flow's account, amount, or currency held in memory.
- The destination account/wallet is always re-fetched and re-picked from the list in the current flow's selection step (SKILL.md → Destination Source of Truth) — never carried over from the previous flow's selection.
- The card the user confirms is the authoritative record of what will execute; if anything on it was silently inherited rather than re-collected, that is a bug — rewind and re-collect.

---

# Scenario don'ts (withdraw)

- ❌ Do NOT assume fiat or crypto — confirm with the user if not explicitly stated.
- ❌ Do NOT fabricate bank account numbers, wallet addresses, or any financial data.
- ❌ Do NOT ask the user to type, paste, or supply a destination crypto wallet address — first-party OR third-party. Addresses are pre-registered in MetaComp; always fetch them via `get_crypto_withdrawal_wallets({ withdrawalParty })` and have the user pick from the list by number. A third-party beneficiary that isn't registered must be added in the dashboard first (STEP 3 empty-list case) — never accept a hand-typed address. (Same principle for fiat: beneficiary bank accounts come from `get_fiat_withdrawal_bank_accounts`, never typed.)
- ❌ Do NOT fabricate or pre-fill `verificationCode` — the user must type it themselves.
- ❌ Do NOT skip the irreversibility warning on crypto confirmation (STEP 8 of `crypto-withdrawal.md`).
- ❌ Do NOT request any new data (upload, purpose, amount, wallet) after asking for the 6-digit verification code — 2FA is always the last input before submit (see `crypto-withdrawal.md` → "Verification Code Is the Terminal Input").
- ❌ Do NOT send `chargeType` when executing a first-party fiat withdrawal.
- ❌ Do NOT carry any parameter (`currency`, `amount`, destination account/wallet, `withdrawalParty`, `isSameNameAccount`, `chargeType`, `purposeOfTransaction`, `verificationCode`, `fileRef`) over from a previous withdrawal flow into a new one — each flow re-collects every value from scratch and the confirmation card is rebuilt only from the current flow's inputs (see "Fresh Per-Flow Parameters" above).
- ❌ Do NOT send `fileRef` / `purposeOfTransaction` when executing a first-party crypto withdrawal — they are third-party only.
- ❌ Do NOT call `request_file_upload` for first-party crypto withdrawal — no supporting document is required.
- ❌ Do NOT reuse a `fileRef` from a previous flow. A fresh `request_file_upload` MUST be called each time the third-party flow enters STEP 7 (including re-entry via "back"); the server auto-invalidates earlier URLs once a new one is requested for the same user + purpose.
- ❌ Do NOT echo internal variable names (`withdrawalParty`, `purposeOfTransaction`, `selectedWallet`, `isSameNameAccount`, `chargeType`, `fileRef`, `verificationCode`, `walletAddress`, `holderCode`, `relationType`, etc.) in user-visible text. Do NOT narrate internal state transitions or procedural tool calls. User-visible text describes the user-relevant outcome in business language only. The mandatory progress header (`Step X/Y — {step name}` / `第 X/Y 步 — {步骤名}`) is the only allowed surfacing of flow state.
- ✅ Third-party **fiat** withdrawal IS supported — see `fiat-withdrawal.md` (requires `purposeOfTransaction` and `chargeType`).
- ✅ Third-party **crypto** withdrawal IS supported — see `crypto-withdrawal.md`. It collects `purposeOfTransaction` AND a supporting document: call `request_file_upload` to mint a one-time browser upload URL, present it, wait for the user to confirm upload, then pass the returned `fileRef` to `execute_crypto_withdrawal`.
- ✅ Always record the selected wallet's `network` from `get_crypto_withdrawal_wallets` and pass it verbatim to `execute_crypto_withdrawal` (do not re-ask the user).
- ✅ **Account Overview** was rendered in shared STEP 1 — do not re-render here unless resuming after a Token Guard login.
