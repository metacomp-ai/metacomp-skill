# Fiat Withdrawal Flow

This sub-skill defines the flow for withdrawing fiat currency from the user's MetaComp account. Supports four paths:
1. first-party × non-same-name
2. first-party × same-name
3. third-party × non-same-name
4. third-party × same-name

Third-party paths require both `purposeOfTransaction` and `chargeType`. Same-name paths use `get_named_account_list` (account) + `get_withdrawal_currencies` with `isSameNameAccount: true` (currency — party-aware, so same-name first- and third-party are both reachable) and pass `isSameNameAccount: true` to `get_withdrawal_quote` and `execute_fiat_withdrawal`.

> **Token Guard applies to every MCP call.** Check each response for `success: false` with `authPageUrl` FIRST; if present, follow the Token Guard rule in SKILL.md.
>
> **Cancel / Back / Confirm keywords** (defined in SKILL.md Absolute Rules) take priority over step-specific parsing at every step.
>
> **Progress header:** prepend each step with `Step X/Y — {step name}` / `第 X/Y 步 — {步骤名}`, where Y depends on the active branch (see §Branch Map).

---

## Branch Map

The narrative below (STEP 0 → STEP 8) is the single source of truth for the flow. The order is always: **STEP 0 resolve party & same-name from what's registered (silent probe + collapse) → STEP 1 `withdrawalParty` (only if STEP 0 left it open) → STEP 2 `isSameNameAccount` (only if STEP 0 left it open) → STEP 3 currency → STEP 4 bank account → STEP 5 amount (first-party also quotes here) → STEP 6 `purposeOfTransaction` + `chargeType` + quote (third-party only; the quote is deferred to STEP 6.3 because the fee floor depends on `chargeType`) → STEP 7 confirm → STEP 8 execute.**

STEP 0 makes the most useful default decision *for* the user: it asks STEP 1 / STEP 2 **only when there is a genuine ≥2-way choice**, auto-resolves an axis that has just one viable value, and routes to the register-in-dashboard empty-state when nothing is viable. The user can always redirect with one sentence afterward.

### Total-step count per branch (for the `Step X/Y` header)

`Y` = the number of user-facing STOPs in the **resolved** branch. STEP 0 renders **no** progress header and consumes no step number. Start from the per-branch baseline below, then **subtract 1 for each of STEP 1 / STEP 2 that STEP 0 auto-resolved** (no question shown).

| Branch | baseline Y (if both STEP 1 & STEP 2 were asked) |
|---|---|
| same-name × first-party | 7 |
| same-name × third-party | 8 |
| non-same-name × first-party | 7 |
| non-same-name × third-party | 8 |

Worked example: a single offerable combo (e.g. only a first-party regular account, no same-name) → STEP 0 resolves both axes, first visible step is STEP 3 currency → `Y = 7 − 2 = 5`.

---

## STEP 0 — Resolve party & same-name from what's registered (silent, before any question)

Goal: don't ask the user a question whose answer is already forced by what they have registered. Probe the destinations and currency availability once, up front, decide which of the four `(withdrawalParty, isSameNameAccount)` combinations are actually usable, and only ask about axes that still have a real ≥2-way choice. The probe results feed STEP 3 and STEP 4 — do not re-fetch them there.

> **Why this is safe for the "never user-typed destination" rule:** STEP 0 only resolves the two classification flags (`withdrawalParty`, `isSameNameAccount`). It never selects or accepts a concrete account number — that still happens in STEP 4, from the system list, by user pick. STEP 0 only ever *reads* system lists.

### 0.1 Honor an explicit pin first
If the trigger message pins an axis — "转给朋友"/"给 XX 转账"/"to a friend" → third-party; "我自己的账户"/"to my own account"/"本人" → first-party; "同名账户"/"same-name" → same-name — record that flag. A pin narrows the offerable set in 0.4; it does **not** skip the probe (we still need the other axis and the empty-state check). A pin to a value that turns out non-offerable routes to that value's empty-state — never a silent flip to the other value (SKILL.md → Destination Source of Truth).

### 0.2 Probe destination accounts (regular probed per party; cache for STEP 4)
- `get_fiat_withdrawal_bank_accounts({ withdrawalParty: 1 })` → `hasRegular[1]` = 列表非空（服务端已按一方过滤）；`get_fiat_withdrawal_bank_accounts({ withdrawalParty: 2 })` → `hasRegular[2]` = 列表非空（服务端已按三方过滤）。两次结果分别缓存给 STEP 4 复用。
- `get_named_account_list()` → `hasSameName` = list non-empty. (This list is **party-agnostic** — it does NOT tell us first vs third; that distinction comes from currency availability in 0.3.)

Token Guard applies to both. **Freshness Guard:** if the previous turn ended on an empty-state STOP and the user now sends a continuation/done signal ("go on" / "added" / "已添加" / "好了" / "你再试试"), re-run these calls and re-evaluate — never re-assert a stale empty result.

### 0.3 Probe currency availability — only for account-backed combos (cache for STEP 3)
A same-name account can be used for *either* party; which party is actually usable for a currency is decided by the trading-pair layer. So for each `(p, s)` whose account side holds in 0.2, probe:

`curr[p][s] = get_withdrawal_currencies({ currencyType: 1, withdrawalParty: p, isSameNameAccount: s })`

Record whether it is non-empty. **Skip** the probe for any combo with no backing account (e.g. don't probe same-name currencies when `!hasSameName`; don't probe `p=2` regular when `!hasRegular[2]`). These calls are exactly the ones STEP 3 would make — STEP 3 reuses them.

### 0.4 Build the offerable set and collapse
`V = { (p, s) : its account side holds AND curr[p][s] is non-empty }`, over `p ∈ {1,2}`, `s ∈ {false, true}`. Apply any 0.1 pin by removing combos that contradict it.

**Empty `V`** → render the matching empty-state and ⛔ **STOP** (do NOT proceed, do NOT accept a typed account):
- nothing registered at all:
  > You don't have any withdrawal bank accounts registered yet. Please add one in the [MetaComp dashboard](https://camp.mce.sg/), then come back. / 您还没有注册任何提现银行账户，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加后再回来。
- third-party pinned but no offerable third-party path:
  > You have no usable third-party withdrawal path right now. Please add a third-party bank account in the [MetaComp dashboard](https://camp.mce.sg/), or tell me to withdraw to your own account instead. / 您当前没有可用的三方提现路径。请在 [MetaComp 控制台](https://camp.mce.sg/) 添加三方银行账户，或告诉我改用本人账户提现。
- same-name pinned but none offerable: analogous wording for same-name.

**Resolve the same-name axis (STEP 2):** look at the distinct `s` values in `V`.
- one value → set `isSameNameAccount` to it, **skip STEP 2**.
- two values → go to **STEP 2** (real choice); after the user answers, drop combos with the other `s`.

**Resolve the party axis (STEP 1):** look at the distinct `p` values in the surviving `V` (after same-name is fixed).
- one value → set `withdrawalParty` to it, **skip STEP 1**.
- two values → go to **STEP 1** (real choice).

**Announce auto-resolved axes in ONE line** so the user knows the default chosen and can override:
> Using your **{own | third-party}**{, **same-name**} account for this withdrawal. (If it should go elsewhere, just tell me.) / 本次提现将使用您的**{本人 | 他人}**{、**同名**}账户。（如需转到其他账户，告诉我即可。）

If both axes auto-resolved → skip STEP 1 and STEP 2 entirely, go straight to **STEP 3** (the currency list for the resolved combo is already in `curr[...]`). Carry `withdrawalParty` / `isSameNameAccount` forward exactly as STEP 1/STEP 2 would have set them.

---

## STEP 1 — Determine `withdrawalParty`

> **Skip this step when STEP 0 already resolved `withdrawalParty`** (only one party offerable for the resolved same-name value, or an explicit pin). Only ask the question below when STEP 0 left two party values open.

If the user's trigger message already implies it (e.g. "转给朋友", "to my own account", "我自己的账户", "给 XX 转账"), record `withdrawalParty` (1 = first-party, 2 = third-party) and skip to STEP 2.

Otherwise ask:

> Withdraw to your own account (first-party) or someone else's (third-party)?
> 1. Own account (first-party) / 自己的账户（一方）
> 2. Someone else's account (third-party) / 他人的账户（三方）
>
> 提现到自己的账户还是他人账户？
> 1. 自己的账户（一方）
> 2. 他人的账户（三方）

⛔ **STOP.** Wait for the user's choice. Accept `1`, `first-party`, `自己`, `yes` → `1`; `2`, `third-party`, `他人`, `no` → `2`. Any other input → re-prompt in place:

> Please reply with **1** (first-party) or **2** (third-party). / 请回复 **1**（一方）或 **2**（三方）。

Record `withdrawalParty`. Then immediately proceed to STEP 2.

---

## STEP 2 — Determine `isSameNameAccount`

> **Skip this step when STEP 0 already resolved `isSameNameAccount`** (only one same-name value offerable). Only ask when both same-name and non-same-name combos are offerable.

Ask:

> Is the destination a same-name account?
> 1. Yes — same-name / 是，同名账户
> 2. No — regular / 否，普通账户
>
> 提现到的是否是同名账户？
> 1. 是（同名）
> 2. 否（普通）

⛔ **STOP.** Wait for the user. Accept `1`, `是`, `yes` → `true`; `2`, `否`, `no` → `false`. Any other input → re-prompt in place:

> Please reply with **1** (same-name) or **2** (regular). / 请回复 **1**（同名）或 **2**（普通）。

Record `isSameNameAccount: boolean`.

If the user asks what "same-name" means, answer with:

> A same-name account is a bank account pre-registered with MetaComp where the owner's name exactly matches your own. / 同名账户是指户主姓名与您本人完全一致、已在 MetaComp 预先绑定的银行账户。

---

## STEP 3 — Choose currency

The currency list for the resolved `(withdrawalParty, isSameNameAccount)` is **already in `curr[withdrawalParty][isSameNameAccount]` from STEP 0.3 — reuse it; do NOT re-call** (re-fetch only on a Freshness Guard signal, e.g. after the user adds an account and returns).

If you must fetch (no cached value, or a Freshness re-fetch), use the single party-aware tool for **both** same-name and non-same-name:
- `get_withdrawal_currencies({ currencyType: 1, withdrawalParty, isSameNameAccount })`

> Do NOT use `get_named_account_currencies` — it is hardcoded to the first-party path and cannot see same-name third-party currencies. `get_withdrawal_currencies` with the resolved flags is the only correct source.

### Empty list
⛔ **STOP** with:

> No fiat currencies are currently available for withdrawal on this path. Please contact MetaComp support or register a suitable account in the [MetaComp dashboard](https://camp.mce.sg/). / 当前路径下没有可提现的法币。请联系 MetaComp 支持或在 [MetaComp 控制台](https://camp.mce.sg/) 添加合适的账户。

### Non-empty list

**Already named a currency?** If the user already named a currency anywhere in this flow, do NOT render the list and ask again. Match it against the returned list **case-insensitively**: if found, record `currency` (canonical casing from the list), confirm in one short line (`Withdrawing **{currency}**. / 提现 **{currency}**。`), and go straight to STEP 4. If named but not in the list, render the list (below) and say it isn't available. Re-asking for a currency the user already gave is an attention-drift bug. **Exception:** when the flow routes *back* to STEP 3 to change currency (e.g. STEP 5 zero-balance, explicit "back"), do NOT auto-re-select the rejected currency — render the list and let the user pick anew.

Otherwise, render a numbered list of all currencies **in the exact order returned by the tool**. Do NOT summarize, abbreviate, or reorder. Accept **either** a 1-based index `n` (`1 ≤ n ≤ N`, **inclusive** — `N` selects the last row, mapped as `currencies[n − 1]`) **or** a currency code typed directly (case-insensitive). Do NOT miscount: the last listed number is valid, never "out of range". Invalid only when it matches neither → show the valid set and ask again (local retry — do not call the tool again):

> Please pick one of: {currencies.join(", ")} — by number (1–{N}) or by code. / 请从以下币种中选择：{currencies.join("、")}——可输入编号（1–{N}）或币种代码。

Record `currency`.

### Funds-First early check (SKILL.md → Funds-First Gate, checkpoint 1)

Once `currency` is recorded, before STEP 4, look up its available balance in the funding account — `isSameNameAccount === true` → `named_account`, else → `fiat` (call `get_account_detail({ productCode })` if not cached, or after a Token Guard re-login — don't gate on a stale number). If the currency key is missing OR `availableAmount` is `0`/nullish:

> Your available {currency} balance is 0, so there's nothing to withdraw. Pick another currency, or type "cancel" to stop. / 您的 {currency} 可用余额为 0，无法提现。请另选币种，或输入"取消"结束。

⛔ **STOP** — do NOT advance to bank-account selection. Re-evaluate STEP 3 when the user names another currency. (This is the early catch for the EUR-with-zero-balance case: stop now rather than after the bank account, amount, confirmation card, and a verification code.)

---

## STEP 4 — Choose bank account

**Hard rule — never ask the user for a bank account number.** Beneficiary
bank accounts (first-party, third-party, and same-name) are pre-registered
in MetaComp. They MUST be fetched from the system and presented as a list;
the user only **picks one by number**. Never ask the user to type, paste,
or dictate an account number, and if they volunteer one, do NOT use it —
still fetch the registered list and have them pick. An account that isn't
on the list must be added in the MetaComp dashboard first — a hand-typed
account number is never accepted, and a missing first-party account is
never grounds to accept a typed one or to pivot the withdrawal to
third-party. (This restates SKILL.md → **Destination Source of Truth**,
which applies here in full.)

**Reuse STEP 0's probe — do NOT re-call** (re-fetch only on a Freshness Guard signal). STEP 0.2 already fetched the same-name list and both per-party regular lists.

If `isSameNameAccount === true`:
- Use the cached `get_named_account_list()` result from STEP 0.2.

If `isSameNameAccount === false`:
- Use the cached `get_fiat_withdrawal_bank_accounts({ withdrawalParty })` result from STEP 0.2 for the resolved party. The server already filtered by party — render the rows as-is. Do NOT re-filter or merge in the other party's accounts.

Both tools return `{ accounts: FiatBankAccountItem[] }`. Each item has this shape (null when upstream omits): `{ baNumber, ownerName, ownerAddress, ownerCountryCode, ownerType, relationship, ownerCorporateCountryCode, swiftCode, bankName, bankAddress, countryCode, baTag, relationType }`.

### Empty
⛔ **STOP** with one of:

- Same-name empty:
  > You have no same-name accounts on file. Please register one in the [MetaComp dashboard](https://camp.mce.sg/). / 您还没有同名账户，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加。
- Non-same-name × first-party empty:
  > You have no first-party bank accounts on file for this path. Please register one in the [MetaComp dashboard](https://camp.mce.sg/). / 您当前路径下没有一方银行账户，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加。
- Non-same-name × third-party empty:
  > You have no third-party bank accounts on file for this path. Please register one in the [MetaComp dashboard](https://camp.mce.sg/). / 您当前路径下没有三方银行账户，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加。

Do NOT offer to accept an account number the user types, and do NOT pivot
to a third-party withdrawal to work around an empty first-party list — both
are forbidden (SKILL.md → **Destination Source of Truth**). The only paths
forward are: register a suitable account in the dashboard, or cancel.

**On the user's next reply, apply SKILL.md → Freshness Guard.** A continuation / done signal ("go on" / "added" / "已添加" / "好了" / "你再试试") means the account may now exist: **re-call the same tool** (`get_named_account_list` for same-name, else `get_fiat_withdrawal_bank_accounts({ withdrawalParty })` for the resolved party) and re-evaluate this step against the fresh result. Do NOT repeat the "no account on file" message from memory, and never ask the user to type a bank account number to work around an empty list.

### Non-empty

**Lead with the party label.** This list has already been narrowed to a single relationship type (STEP 0 / STEP 2 / STEP 4 filtering), so the user can't tell from the rows alone whether these are their own, a third party's, or same-name accounts — say it explicitly in the header. Derive `branchLabel`:
- `isSameNameAccount === true` → **same-name / 同名账户**
- else `withdrawalParty === 1` → **first-party (your own) / 一方（本人）账户**
- else `withdrawalParty === 2` → **third-party / 三方账户**

Then render a numbered table. Always show `baNumber` and `ownerName`; show one additional column depending on which fields are non-null:
- `swiftCode` non-null → Swift / 银行代码
- else if `baTag` non-null → Tag / 标签
- else → only `baNumber` + `ownerName`

Example (non-same-name × first-party, with `baTag`). Render **one row per account** — never only the first row:

```
Your {branchLabel} accounts for this withdrawal / 本次可用的{branchLabel}：

| # | Account # / 账号 | Owner / 户名 | Tag / 标签 |
|---|---|---|---|
| 1 | {accounts[0].baNumber} | {accounts[0].ownerName} | {accounts[0].baTag} |
| 2 | {accounts[1].baNumber} | {accounts[1].ownerName} | {accounts[1].baTag} |
| … | … | … | … |

Pick one by number. / 请按编号选择。
```

Out-of-range → show the valid range and ask again (local retry):

> Please reply with a number between 1 and {accounts.length}. / 请回复 1 到 {accounts.length} 之间的编号。

Record `bankAccountNumber = chosen.baNumber` and keep a reference to the chosen row for the confirmation card.

---

## STEP 5 — Amount + quote

Prompt — wording depends on `withdrawalParty`, because the entered amount
means different things in each fee model (see STEP 7):

- **First-party (`withdrawalParty === 1`)** — the entered amount is what
  is debited; the fee comes out of it:
  > How much {currency} do you want to withdraw? / 您想提现多少 {currency}？

- **Third-party (`withdrawalParty === 2`)** — the entered amount is what
  the **recipient receives**; the service fee is added on top, so the
  account is debited a bit more (bank intermediary fees, if any, are
  separate — see STEP 7 disclaimer):
  > How much {currency} should the recipient receive? The service fee is
  > added on top, so a little more than this will be debited from your
  > account. / 对方需要收到多少 {currency}？手续费会**额外加收**，因此账户
  > 实际扣款会比这个数略多。

Wait for amount. Normalize: strip thousand separators (`,`), trim whitespace. Locally validate `^\d+(\.\d+)?$`. On failure:

> Amount must be a positive decimal, e.g. "200" or "0.5". Please try again. / 金额必须是正小数，例如 "200" 或 "0.5"，请重新输入。

### Local pre-quote validations

Run these BEFORE calling `get_withdrawal_quote` (uses cached balance, no extra API call):

Look up available balance from the Account Overview gathered at SKILL.md entry:
- `isSameNameAccount === true` → use `named_account` detail (call `get_account_detail({ productCode: 'named_account' })` if not already cached)
- `isSameNameAccount === false` → use `fiat` balance

Read `available = instrumentInfoMap[{currency}].availableAmount`. If the currency key is missing OR `available` is nullish, treat `available` as `0` and output:

> Your available {currency} balance is 0. Please pick another currency or type "back" to return to STEP 3. / 您的 {currency} 可用余额为 0，请另选币种，或输入"返回"回到 STEP 3。

Otherwise, `BigNumber(amount).gt(available)` →
> Your available {currency} balance is {avail}. Please enter an amount ≤ {avail}. / 您的 {currency} 可用余额是 {avail}，请输入不大于 {avail} 的金额。

Ask for a new amount in place — do NOT jump back to STEP 4 (unless the user types "back").

### Fetch the quote — timing depends on party

The third-party fee floor depends on `chargeType` (the "OUR" bearer uses a
different minimum fee), so a third-party quote is only correct once
`chargeType` is known. Therefore:

- **First-party (`withdrawalParty === 1`):** fetch the quote now (no
  `chargeType`):
  ```
  get_withdrawal_quote({ withdrawalParty: 1, currency, amount, currencyType: 1, isSameNameAccount })
  ```
  Then apply **Quote handling** below and go to STEP 7.
- **Third-party (`withdrawalParty === 2`):** do NOT fetch the quote here —
  `chargeType` hasn't been collected yet, and quoting without it would show
  the wrong minimum fee. Skip the rest of STEP 5 and go to STEP 6; the quote
  (with `chargeType`) is fetched in **STEP 6.3**.

### Quote handling

Run this wherever the quote was fetched — STEP 5 for first-party, STEP 6.3
for third-party.

Response: `{ fee: { serviceFee, amountReceived, withdrawalAmount }, minimumAmount: { minimumAmount: number }, balance: { currency, availableAmount, sufficient, fundingAccount: { productCode, label }, alternateFundingAccount?: { productCode, label, availableAmount } } | null }`. The server applies the correct fee direction AND the chargeType-dependent fee floor; `amountReceived` (recipient's net) and `withdrawalAmount` (total debited) are server-computed. Record all three for the confirmation card — **do NOT recompute them.**

**Funds-First sufficiency gate (SKILL.md → Funds-First Gate, checkpoint 2).** Read `balance` from the quote (it was resolved because `currencyType: 1` was passed; for same-name it reflects the `named_account`):
- `balance.sufficient === false` → the total debit exceeds available. Stop and tell the user the shortfall — do NOT render the STEP 7 confirmation card or ask for a code:
  > Your available {currency} balance is {balance.availableAmount}, which doesn't cover the total debit of {fee.withdrawalAmount} {currency} (including the {fee.serviceFee} fee). Please enter a smaller amount, or type "cancel". / 您的 {currency} 可用余额为 {balance.availableAmount}，不足以支付总扣款 {fee.withdrawalAmount} {currency}（含手续费 {fee.serviceFee}）。请输入更小的金额，或输入"取消"。

  Re-prompt for a new amount in place, then re-fetch the quote.
  - **But if `balance.alternateFundingAccount` is present** — do NOT show the shortfall message above, do NOT advise a retry, and do NOT treat it as a system glitch. It is a strong signal that `isSameNameAccount` was set wrong: the account you checked (`balance.fundingAccount.label`) is short, but the other account (`balance.alternateFundingAccount.label`) holds enough. Go back and confirm the account type:
    > The {balance.fundingAccount.label} you picked has {balance.availableAmount} {currency} available, but your {balance.alternateFundingAccount.label} holds {balance.alternateFundingAccount.availableAmount} {currency}. Did you mean to withdraw from that account? Reply **yes** to switch, or tell me the right account. / 您选的是{balance.fundingAccount.label}（可用 {balance.availableAmount} {currency}），但您的{balance.alternateFundingAccount.label}里有 {balance.alternateFundingAccount.availableAmount} {currency}。是否其实要从那个账户出金？回复**是**切换，或告诉我正确的账户。

    If the user confirms the switch, flip `isSameNameAccount` and return to **STEP 3** — re-resolve currency, bank account, amount and re-quote from there (changing `isSameNameAccount` changes the available currencies and account list, so they MUST be re-resolved per STEP 0 / STEP 3, never reused).
- `balance.sufficient === true` → proceed.
- `balance === null` (unresolved) → fall back to a fresh `get_account_detail` for the funding account (`named_account` if `isSameNameAccount`, else `fiat`) and compare `BigNumber(fee.withdrawalAmount).gt(available)` yourself. Never advance to STEP 7 on an unverified balance.

**Min-amount check:** `BigNumber(amount).lt(quote.minimumAmount.minimumAmount)` →
> The minimum withdrawal for {currency} is {min}. Please enter an amount ≥ {min}. / {currency} 的最小提现金额是 {min}，请输入不小于 {min} 的金额。

Re-prompt for a new amount in place, then re-fetch the quote (first-party:
here; third-party: re-run STEP 6.3 with the same `chargeType`).

**Quote display on success** (display the server's values verbatim — do not do the arithmetic yourself):

```
Amount to recipient / 对方到账：{fee.amountReceived} {currency}
Service fee / 手续费：{fee.serviceFee} {currency}
Total debited from account / 账户实际扣款：{fee.withdrawalAmount} {currency}
```

Note: for third-party, `amountReceived` here is before bank intermediary fees. Those may further reduce the final received amount; the confirmation card in STEP 7 will restate this disclaimer.

**Quote call failure (network / 5xx / upstream business):**

> The quote service is temporarily unavailable: {reason}. Reply with the amount again to retry, or type "cancel" to abort. / 报价服务暂时不可用：{reason}。请再次发送金额以重试，或输入"取消"退出。

⛔ **STOP.** Do NOT auto-retry, do NOT advance, do NOT fabricate a quote. Accepted next inputs:
- An amount string → re-run local validations and re-call `get_withdrawal_quote`.
- `cancel` / `取消` → exit to SKILL.md entry.
- Anything else → re-show the message above.

Record `amount`, `fee.*`, `minimumAmount` for the confirmation card.

After a successful quote, proceed to STEP 7. (First-party reaches Quote
handling from STEP 5; third-party reaches it from STEP 6.3.)

---

## STEP 6 — Third-party metadata (third-party only)

Skip entirely if `withdrawalParty === 1`.

For `withdrawalParty === 2`, collect **both** `purposeOfTransaction` and `chargeType` before the confirmation card so the user sees them on the card itself.

### 6.1 `purposeOfTransaction`

Prompt:

> Please describe the purpose of this transaction in a sentence (contract / invoice / reason). / 请用一句话说明本次转账用途（合同 / 发票 / 款项说明）。

After receiving input, trim whitespace. If empty or whitespace-only → re-show the same prompt. Record `purposeOfTransaction`.

### 6.2 `chargeType` (bank-transfer fee bearer)

Prompt:

```
Who bears the bank-transfer fee? / 银行手续费由谁承担？
1) Beneficiary (BEN) / 收款方
2) Sender (OUR — default) / 发起方（默认）
3) Shared (SHA) / 共担
```

Default to `2` when the user replies with an empty string, `default`, or `默认`. Accept only `1`, `2`, or `3`. Any other input → re-prompt in place:

> Please reply with **1** (BEN), **2** (OUR, default), or **3** (SHA). / 请回复 **1**（收款方承担）、**2**（发起方承担，默认）或 **3**（共担）。

Record `chargeType: 1 | 2 | 3`. Keep the label for the confirmation card:
- `1` → `Beneficiary (BEN) / 收款方`
- `2` → `Sender (OUR) / 发起方`
- `3` → `Shared (SHA) / 共担`

Then proceed to STEP 6.3.

### 6.3 Fetch the quote (now that `chargeType` is known)

The third-party fee floor depends on `chargeType` (OUR uses `minimumFeeOur`),
so the quote MUST be fetched here, after 6.2 — not in STEP 5.

```
get_withdrawal_quote({ withdrawalParty: 2, currency, amount, currencyType: 1, isSameNameAccount, chargeType })
```

Handle the response with **STEP 5 → Quote handling** (Funds-First
sufficiency gate, min-amount check, quote display, failure handling, record
`fee.*`). The sufficiency gate matters most for third-party here: the fee is
added **on top**, so the total debit (`fee.withdrawalAmount`) exceeds the
recipient amount the user typed — `balance.sufficient` already compares
against that total, so honor it even when the entered amount alone looked
affordable. If the min-amount check
fails, re-prompt for a new amount, then re-run this 6.3 quote with the same
`chargeType`. If the user later changes `chargeType` (e.g. via "back" from
STEP 7), re-run this quote so the fee reflects the new bearer.

Then proceed to STEP 7.

---

## STEP 7 — Confirmation card

Use the `serviceFee` / `amountReceived` / `withdrawalAmount` recorded from
the STEP 5 quote — display verbatim, do not recompute:

```
Please confirm / 请确认：

Branch / 分支：{same-name|non-same-name} × {first-party|third-party}
Currency / 币种：{currency}
Amount to recipient / 对方到账：{fee.amountReceived} {currency}
Service fee / 手续费：{fee.serviceFee} {currency}
Total debited from account / 账户实际扣款：{fee.withdrawalAmount} {currency}
Destination / 目标账户：{baNumber} — {ownerName}{extra}
```

`{extra}` includes `swiftCode` / `baTag` / `bankName` when available (same pick logic as STEP 4).

If `withdrawalParty === 2`, append:

```
Purpose / 用途：{purposeOfTransaction}
Fee borne by / 手续费承担方：{chargeType label}
```

Then, still for third-party, append the disclaimer:

> Note: "Amount to recipient" excludes bank intermediary fees. The final received amount depends on `Fee borne by` (BEN/OUR/SHA) and the clearing banks. / 注：对方到账金额未扣除银行中间行费用，最终到账金额取决于"手续费承担方"（BEN/OUR/SHA）及清算行。

For **all** parties, append this caveat — the quote is fee-only and cannot
know any deduction (first-party deductions reduce the fee; third-party
depends on who bears the fee), which is applied at execution:

> Note: these are fee-based estimates. If a deduction/credit applies it is
> applied at submission — the final figures (including any deductible
> amount) are shown on the receipt. / 注：以上为含手续费的预估金额。如有抵扣
> 将在提交时计算，最终金额（含抵扣金额）以提交后的回执为准。

End the card with:

> Type "confirm" to proceed, "back" to edit, or "cancel" to abort. / 输入"确认"继续，"返回"修改，"取消"退出。

Keyword routing (checked before step-specific parsing):
- exact `confirm` / `确认` (per SKILL.md Transaction Confirmation Gate; `yes` / `是` / `好` / `ok` do NOT count → re-ask) → STEP 8
- `back` / `返回` / `上一步` →
  - if `withdrawalParty === 2` → return to STEP 6.2 (re-enter `chargeType`); a second `back` from 6.2 returns to 6.1 (re-enter `purposeOfTransaction`). Must not skip STEP 6 on the way back. After re-entering `chargeType`, STEP 6.3 re-fetches the quote so the fee reflects the new bearer.
  - if `withdrawalParty === 1` → return to STEP 5 (re-enter amount).
- `cancel` / `取消` / `放弃` → exit

---

## STEP 8 — Execute

### 8.1 Ask `verificationCode`

> Please enter your 6-digit verification code from your authenticator app. / 请输入您认证器应用中的 6 位动态验证码。

Validate `^\d{6}$`. On failure:

> The code must be exactly 6 digits. Please try again. / 验证码必须是 6 位数字，请重新输入。

Record `verificationCode`.

### 8.2 Call `execute_fiat_withdrawal`

```
execute_fiat_withdrawal({
  withdrawalParty,
  currency,
  amount,
  bankAccountNumber,
  verificationCode,
  chargeType,          // only pass when withdrawalParty === 2; omit otherwise
  isSameNameAccount,   // only pass when true; omit when false
  purposeOfTransaction // only pass when withdrawalParty === 2; omit otherwise
})
```

### 8.3 Display the result (only show rows where the field is present in the response)

Destination uses the same `{extra}` logic as STEP 4 / STEP 7 — append `swiftCode` / `baTag` / `bankName` when available.

**Use the server's returned amounts verbatim — do NOT recompute.** The
backend already applied the correct fee direction AND any deduction for
this transaction: `amountReceived` is the recipient's net,
`withdrawalAmount` is the total debited from the account, `chargeAmount`
is the gross service fee, and `deductibleAmount` is any credit/offset
applied (often `0`; show it when present and non-zero so the user sees why
the figures differ from the STEP 7 estimate). The STEP 7 confirmation card
is a fee-only estimate and does NOT include `deductibleAmount`, so these
executed numbers are the source of truth. If `amountReceived` is absent,
fall back to the STEP 7 `amountReceived` — never to the raw entered
`amount`.

English:
```
✅ **Withdrawal Submitted**

| | |
|---|---|
| TX Code | {txCode} |
| Currency | {currency} |
| Status | {status} (pending) |
| Amount to recipient | {amountReceived} |         ← if present, else STEP-7 amountReceived
| Service fee | {chargeAmount} |                    ← if present
| Deductible amount | {deductibleAmount} |         ← if present and ≠ 0
| Total debited | {withdrawalAmount} |             ← if present
| Destination | {baNumber} — {ownerName}{extra} |
| Time | {createAt} |                              ← if present
```

Chinese:
```
✅ **提现已提交**

| | |
|---|---|
| 交易码 | {txCode} |
| 币种 | {currency} |
| 状态 | {status}（处理中） |
| 对方到账金额 | {amountReceived} |              ← 如有返回，否则取 STEP 7 对方到账 |
| 手续费 | {chargeAmount} |                      ← 如有返回
| 抵扣金额 | {deductibleAmount} |                ← 如有返回且非 0
| 账户实际扣款 | {withdrawalAmount} |            ← 如有返回
| 接收方 | {baNumber} — {ownerName}{extra} |
| 时间 | {createAt} |                              ← 如有返回
```

### 8.4 Business error (non-401)

> Withdrawal failed: {reason}. Funds may or may not have been reserved — please check your transaction history before retrying. / 提现失败：{reason}。资金可能已被冻结，请先查看交易记录再决定是否重试。

Do NOT auto-retry. Let the user decide.
