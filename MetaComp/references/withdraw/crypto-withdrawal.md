# Crypto Withdrawal Flow

This sub-skill defines the flow for withdrawing cryptocurrency from the user's MetaComp account to either their **own first-party wallet** or a **third-party beneficiary wallet**.

> **Third-party supporting document:** Third-party crypto withdrawals require the user to upload a supporting document (contract, agreement, invoice). The skill calls `request_file_upload` to mint a one-time browser upload URL, presents the URL to the user, then waits for the user to confirm the upload is complete. The returned `fileRef` is passed to `execute_crypto_withdrawal`. Each third-party flow MUST mint a fresh upload URL — never reuse a `fileRef` from an earlier flow (the server invalidates older URLs as soon as a new one is requested for the same user + purpose).

> **Token Guard applies to every MCP call in this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.
>
> **Cancel / Back / Confirm keywords** (defined in SKILL.md Absolute Rules) take priority over step-specific parsing at every step.
>
> **Progress header:** prepend each step with `Step X/Y — {step name}` / `第 X/Y 步 — {步骤名}`, where the baseline Y = 7 for first-party and 9 for third-party. Third-party adds STEP 6 (purpose) and STEP 7 (supporting document upload) between the amount step and the confirmation card. **STEP 0 (silent probe) renders no header and consumes no step number; when STEP 0 auto-resolves the party, STEP 1 is not shown — subtract 1 from Y.**

---

## Pre-Confirm Gate — Mandatory Purpose & Upload Check (third-party only)

**Same priority as Token Guard.** When `withdrawalParty === 2`, BEFORE
rendering the STEP 8 confirmation card you MUST verify BOTH:

1. `purposeOfTransaction` is set to a non-empty trimmed string (collected in STEP 6).
2. `fileRef` is set to the value returned by `request_file_upload` in
   STEP 7 of the **current withdrawal flow**, the user has explicitly
   confirmed (at some prior step within this same flow) that the upload
   is complete, AND `check_file_upload` returned `{ uploaded: true }` for
   that `fileRef` (STEP 7.3). A `fileRef` carried over from a previous
   withdrawal flow, a `fileRef` the user never confirmed, or one for which
   the latest `check_file_upload` returned `uploaded: false`, is NOT valid.

If either is missing, rendering STEP 8 is a rule violation — return to
the missing step, collect it, then come back.

**Self-check before sending response:** re-read your draft. If it shows
the confirmation card but either condition above is unmet, your draft
is INVALID — discard it and resume from the missing step.

`fileRef` is an opaque identifier — you may surface upload status to the
user in plain language ("upload received", "I'll wait for you to upload"),
but never echo the raw `fileRef` string or the words `fileRef` / `proof`
in user-visible text.

---

## Verification Code Is the Terminal Input (highest-priority ordering rule)

**Same priority as Token Guard.** The 6-digit verification code (2FA) is
the **last thing you ever collect** in a withdrawal. It is bound to the
STEP 8 confirmation card and authorizes *the exact transaction shown on
that card*. Once you have asked for the code, the only legal next move is
`execute_*` (STEP 9) or a code-retry/back/cancel — **never a request for a
new piece of data** (upload, purpose, amount, wallet, anything).

Why this is non-negotiable: a TOTP code is a time-boxed authorization for
a *specific, fully-specified* transaction the user just reviewed. If you
collect the upload (or any field) *after* the code, then the code the user
typed authorized an incomplete transaction, the card they approved was a
lie, and the TOTP has likely rotated by the time you finally submit. The
single most common failure here is reaching the confirm-card + code prompt
for a **third-party** withdrawal without having done STEP 6 (purpose) and
STEP 7 (upload) first — then trying to back-fill the upload after the code.
That ordering is always a bug.

**The correct third-party order is fixed — walk it in this exact sequence,
no collapsing, no reordering:**

```
5 amount → 6 purpose → 7 upload (+7.3 verify it landed) → 8 confirm card → ask for code → 9 execute
                                                          └─────────── code is asked HERE and nowhere earlier
```

First-party silently skips 6 and 7, so its order is `5 amount → 8 confirm
card → ask for code → 9 execute`.

**Self-check before any reply that contains a code prompt or reacts to a
received code:** if this is third-party, confirm `purposeOfTransaction` and
a verified `fileRef` are already in state (Pre-Confirm Gate above). If
either is missing, you jumped ahead — do NOT ask for the code; go back to
the missing step, collect it, re-render the STEP 8 card, *then* ask for the
code. If you ever catch yourself about to ask the user to upload/provide
anything right after they gave a code, stop: the fix is to rewind to the
confirm card, not to append the request.

> The one legitimate case where an upload follows a code is **failure
> recovery** (STEP 8 `back`, or a STEP 9 execute that fails on an
> expired/mismatched document). Even then you do NOT execute with the old
> code: after the user re-uploads, you return to the STEP 8 card and
> **ask for the code again**, because the code is — always — the last
> input before submit.

---

## STEP 0 — Resolve party from registered wallets (silent, before any question)

Crypto has a single axis to collapse (first-party vs third-party — there is no same-name concept). Goal: don't ask the user which party when only one is actually usable. Probe both party wallet lists once, up front, and reuse the result in STEP 3.

> **"Never user-typed destination" stays intact:** STEP 0 only resolves the `withdrawalParty` flag by *reading* the registered wallet lists. The concrete wallet is still picked by the user from the system list in STEP 3.

### 0.1 Honor an explicit pin first
"my own wallet" / "自己的钱包" / "本人" → first-party; "to a friend" / "他人钱包" / "给朋友" → third-party. Record it; still run the probe (for the empty-state check). A pin to a party with no registered wallet routes to that party's empty-state — never a silent flip (SKILL.md → Destination Source of Truth).

### 0.2 Probe both party wallet lists (cache for STEP 3)
- `get_crypto_withdrawal_wallets({ withdrawalParty: 1 })` → `hasFirstWallet` = wallets non-empty.
- `get_crypto_withdrawal_wallets({ withdrawalParty: 2 })` → `hasThirdWallet` = wallets non-empty.

Token Guard on both. **Freshness Guard:** after an empty-state STOP + a continuation signal ("added" / "已添加" / "好了" / "你再试试"), re-run and re-evaluate — never re-assert a stale empty result.

### 0.3 Collapse
- **Neither** (and no pin satisfiable) → empty-state, ⛔ **STOP** (never accept a typed address):
  > You don't have any withdrawal wallets registered yet. Please add one in the [MetaComp dashboard](https://camp.mce.sg/), then come back. / 您还没有注册任何提现钱包，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加后再回来。
  - If a pin caused this (e.g. third-party pinned but `!hasThirdWallet`), use the pinned party's wording and do NOT silently flip:
    > You have no third-party wallets registered, so a third-party withdrawal isn't available. Please add one in the [MetaComp dashboard](https://camp.mce.sg/), or tell me to withdraw to your own wallet instead. / 您没有注册三方钱包，无法发起三方提现。请在 [MetaComp 控制台](https://camp.mce.sg/) 添加，或告诉我改用本人钱包提现。
- **Only first-party** (`hasFirstWallet && !hasThirdWallet`) → `withdrawalParty = 1`, announce one line, **skip STEP 1**, go to STEP 2.
- **Only third-party** (`hasThirdWallet && !hasFirstWallet`) → `withdrawalParty = 2`, announce one line, **skip STEP 1**, go to STEP 2.
- **Both** → go to STEP 1 (the genuine two-way question).

One-line announce when auto-resolved:
> Withdrawing to your **{own | third-party}** wallet. (If it should go elsewhere, just tell me.) / 本次提现将转到您的**{本人 | 他人}**钱包。（如需转到其他钱包，告诉我即可。）

> Note: a party can have a registered wallet but no withdrawable currencies; that residual case is still caught by STEP 2 Case A (empty currency list). STEP 0 only collapses the *party question*.

---

## STEP 1 — Determine Withdrawal Party

> **Skip this step when STEP 0 already resolved `withdrawalParty`** (only one party had registered wallets, or an explicit pin). Only ask the question below when both first- and third-party wallets exist.

If the user has already specified first-party or third-party, record `withdrawalParty` (1 or 2) and skip to STEP 2.

Otherwise, ask concisely:

> Withdraw to:
>
> 1. My own wallet (first-party) / 自己的钱包（一方）
> 2. Someone else's wallet (third-party) / 他人的钱包（三方）
>
> 提现到哪里？
>
> 1. 自己的钱包（一方）
> 2. 他人的钱包（三方）

⛔ **STOP.** Wait for the user's answer. Accept `1`, `first-party`, `自己`, `yes` → `1`; `2`, `third-party`, `他人`, `no` → `2`. Any other input → re-prompt in place:

> Please reply with **1** (first-party) or **2** (third-party). / 请回复 **1**（一方）或 **2**（三方）。

Record `withdrawalParty`. Then **immediately** proceed to STEP 2 — do NOT add commentary or ask follow-up questions.

---

## STEP 2 — Show Available Currencies (mandatory, immediate)

**Immediately** after determining `withdrawalParty`, call `get_withdrawal_currencies({ currencyType: 2, withdrawalParty })`. Do NOT insert any additional questions or commentary between STEP 1 and this call. The call is mandatory **even when the user already named a currency** — it is the only source of truth for what is currently withdrawable.

### Case A — Empty list

> No crypto currencies are currently available for withdrawal. / 当前没有可提现的加密货币。

⛔ **STOP.**

### Case B — User already named a currency (honor it — do NOT re-ask)

If the user already named a currency anywhere in this flow (e.g. the opening "I want to withdraw some **USDT**", or an earlier turn), do NOT render the list and ask again. Match the named code against the returned list **case-insensitively**:

- **Match found** → record `currency` (use the list's canonical casing), confirm in one short line, and **go straight to STEP 3**. Do NOT show the numbered list, do NOT ask "which currency".
  > Withdrawing **{currency}**. / 提现 **{currency}**。
- **Named but NOT in the list** → that currency isn't withdrawable right now. Render the full list (Case C) and say so:
  > **{namedCurrency}** isn't available for withdrawal right now — please pick one of the available currencies below. / 当前不支持提现 **{namedCurrency}**，请从下列可提现币种中选择。

This mirrors STEP 1's "already specified → skip the question" rule. **Re-asking for a currency the user already gave is an attention-drift bug — don't do it.**

> **Exception — returning to STEP 2 to change currency.** When the flow routes *back* to STEP 2 to pick a **different** currency (STEP 4 network-incompatibility, STEP 5 zero-balance, or an explicit "back"), the previously-named currency is the one being rejected — do NOT auto-re-select it. Skip Case B and go to Case C (render the list and let the user pick anew). Case B's short-circuit applies only to a currency the user is *actively requesting*, not one the flow just bounced off.

### Case C — No currency named yet → render the list and ask

**MUST render the full currency list as a numbered list, in the exact order returned by the tool.** Do NOT summarize, abbreviate, reorder, or skip any currencies. The numbering is purely positional over the returned order — the codes below are placeholders, your list follows whatever the tool returns:

English:
```
Available cryptocurrencies for withdrawal:

1. {currencies[0]}
2. {currencies[1]}
…
{N}. {currencies[N-1]}

Which cryptocurrency would you like to withdraw?
```

Chinese:
```
可提现的加密货币：

1. {currencies[0]}
2. {currencies[1]}
…
{N}. {currencies[N-1]}

请选择要提现的币种。
```

⛔ **STOP.** Wait for the user to pick. Accept **either** form:

- **A number** `n` — a 1-based index into the list **as shown**, valid for `1 ≤ n ≤ N` where `N = currencies.length`. The upper bound is **inclusive**: `N` itself is a valid choice (it selects the last row, `currencies[N − 1]`). Map `n` → `currencies[n − 1]`. Do NOT miscount — entering the last listed number must select the last currency, never "out of range".
- **A currency code** typed directly (e.g. `USDT`) — matched case-insensitively against the list.

Record `currency` (canonical casing from the list). Treat the input as invalid **only** when it is neither a valid index `1..N` nor a listed code → local retry (do NOT re-call the tool):

> Please pick one of: {currencies.join(", ")} — by number (1–{N}) or by code. / 请从以下币种中选择：{currencies.join("、")}——可输入编号（1–{N}）或币种代码。

### Funds-First early check (SKILL.md → Funds-First Gate, checkpoint 1)

Once `currency` is recorded, before moving to STEP 3, look up the available
balance for it in the **crypto** account: `crypto →
instrumentInfoMap[{currency}].availableAmount` from the Account Overview
gathered at SKILL.md entry (call `get_account_detail({ productCode: 'crypto' })`
if not cached, or if a Token Guard re-login happened since it was fetched —
don't gate on a stale number). If the currency key is missing OR
`availableAmount` is `0`/nullish:

> Your available {currency} balance is 0, so there's nothing to withdraw. Pick another currency, or type "cancel" to stop. / 您的 {currency} 可用余额为 0，无法提现。请另选币种，或输入"取消"结束。

⛔ **STOP** here — do NOT advance to wallet selection. Re-evaluate STEP 2 (Case C) when the user names another currency. Catching a zero balance now spares the user the wallet/amount/confirm/code steps on a doomed withdrawal.

---

## STEP 3 — Choose Wallet (addresses ALWAYS come from the system)

**Hard rule — never ask the user for a wallet address.** Destination wallet addresses (first-party **and** third-party) are pre-registered in MetaComp. They MUST be fetched from the system via `get_crypto_withdrawal_wallets` and presented as a list; the user only **picks one by number**. Never ask the user to type, paste, dictate, or otherwise supply a wallet address — not even for third-party. If the user volunteers an address, do NOT use it: still fetch the registered list and have them pick from it. A third-party beneficiary that isn't on the registered list must be added in the MetaComp dashboard first (see the third-party empty-list case below) — a hand-typed address is never accepted. (This restates SKILL.md → **Destination Source of Truth**, which applies here in full.)

**Worked counter-example — the mistake to never repeat.** User picked
first-party USDT; `get_crypto_withdrawal_wallets({ withdrawalParty: 1 })`
returned only a BTC wallet (no ETH wallet).

- ❌ **Wrong:** "There are no Ethereum wallets on file. You can either add
  one in the dashboard, **or provide the address directly and I'll process
  it as a third-party withdrawal.**" → then accepting the typed address.
  This breaks the rule three ways: it treats a network mismatch as an empty
  list, offers typed-address entry, and silently flips first-party →
  third-party.
- ✅ **Right:** show the BTC wallet in the list (it exists — it is NOT an
  empty list); the USDT-on-BTC compatibility is decided in STEP 4, not by
  hiding the wallet. If the user truly has *zero* first-party wallets,
  follow Case A: register-in-dashboard or cancel — never a typed address.

**Reuse STEP 0's probe for the resolved `withdrawalParty` — do NOT re-call** (re-fetch only on a Freshness Guard signal). STEP 0.2 already fetched `get_crypto_withdrawal_wallets({ withdrawalParty })` for both parties; use the cached list for the resolved party. The response shape is `{ wallets: Array<{ walletAddress, network, walletTag, ownerName }> }`.

### Case A — Empty list (first-party)

> You have no first-party wallets on file. Please register one in the [MetaComp dashboard](https://camp.mce.sg/) before withdrawing. / 您还没有绑定一方钱包，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加。

⛔ **STOP.**

**Do NOT** offer to accept a wallet address the user types, and do NOT
pivot to a third-party withdrawal to work around the empty list — both are
forbidden (SKILL.md → **Destination Source of Truth**). The only paths
forward are: register a first-party wallet in the dashboard, or cancel.

**On the user's next reply, apply SKILL.md → Freshness Guard.** A
continuation / done signal ("go on" / "added" / "已添加" / "好了" / "你再试试")
means the wallet may now be registered: **re-call
`get_crypto_withdrawal_wallets({ withdrawalParty })`** and re-evaluate this
step against the fresh result. Never re-assert "no wallets on file" from
memory, and never accept a hand-typed address.

### Case A — Empty list (third-party)

> You have no third-party beneficiary wallets on file. Please register one in the [MetaComp dashboard](https://camp.mce.sg/) before withdrawing. / 您还没有绑定三方受益人钱包，请先在 [MetaComp 控制台](https://camp.mce.sg/) 添加。

⛔ **STOP.**

**On the user's next reply, apply SKILL.md → Freshness Guard.** A continuation / done signal ("go on" / "added" / "已添加" / "好了" / "你再试试") means the wallet may now be registered: **re-call `get_crypto_withdrawal_wallets({ withdrawalParty })`** and re-evaluate this step against the fresh result. Do NOT repeat the "no wallets on file" message from memory, and never accept a hand-typed wallet address to work around an empty list.

### Case B — At least one wallet

Render (language follows user's dominant language). Render **one row per wallet** — never only the first row.

English:
```
Your registered wallets:

| # | Tag | Address | Network | Owner |
|---|-----|---------|---------|-------|
| 1 | {wallets[0].walletTag} | {wallets[0].walletAddress} | {wallets[0].network} | {wallets[0].ownerName} |
| 2 | {wallets[1].walletTag} | {wallets[1].walletAddress} | {wallets[1].network} | {wallets[1].ownerName} |
| … | … | … | … | … |

Which wallet would you like to send the funds to?
```

Chinese:
```
您已绑定的钱包：

| # | 标签 | 地址 | 网络 | 持有人 |
|---|------|------|------|--------|
| 1 | {wallets[0].walletTag} | {wallets[0].walletAddress} | {wallets[0].network} | {wallets[0].ownerName} |
| 2 | {wallets[1].walletTag} | {wallets[1].walletAddress} | {wallets[1].network} | {wallets[1].ownerName} |
| … | … | … | … | … |

请选择要转入的钱包。
```

⛔ **STOP.** Wait for the user to pick one. Out-of-range / invalid → local retry:

> Please reply with a number between 1 and {wallets.length}. / 请回复 1 到 {wallets.length} 之间的编号。

Record the full selected wallet row as `selectedWallet`. The `network` field will be passed verbatim to `execute_crypto_withdrawal` in STEP 8 — do NOT ask the user to re-enter it.

---

## STEP 4 — Currency ↔ Network Compatibility Check

Call `get_crypto_deposit_networks({ currency })` → returns `{ networks: string[] }`. This tool is reused from the deposit flow; the list of networks supporting a given currency is the same regardless of direction.

### Case A — `selectedWallet.network` NOT in `networks`

> The wallet you picked is on **{selectedWallet.network}**, but **{currency}** is not supported on that network. Supported networks for {currency}: {networks.join(", ")}.
>
> Would you like to:
> 1. Pick a different currency (go back to STEP 2)
> 2. Pick a different wallet (go back to STEP 3)
>
> 您选择的钱包网络是 **{selectedWallet.network}**，但 **{currency}** 不支持该网络。{currency} 支持的网络：{networks.join("、")}。
>
> 您希望：
> 1. 选择其他币种（返回 STEP 2）
> 2. 选择其他钱包（返回 STEP 3）

⛔ **STOP.** Wait for the user's choice, then jump back to the chosen STEP.

### Case B — Network matches

Proceed to STEP 5.

---

## STEP 5 — Enter Amount; Fetch Minimum and Fee

Prompt for amount first (fee depends on amount). The prompt wording
depends on `withdrawalParty`, because the entered amount means different
things in each fee model (see STEP 8):

- **First-party (`withdrawalParty === 1`)** — the entered amount is what
  is debited; the fee comes out of it:
  > Please tell me how much {currency} you want to withdraw. / 您想提现多少 {currency}？

- **Third-party (`withdrawalParty === 2`)** — the entered amount is what
  the **recipient receives**; the fee is added on top, so the account is
  debited a bit more. Say so explicitly:
  > How much {currency} should the recipient receive? The service fee is
  > added on top, so a little more than this will be debited from your
  > account. / 对方需要收到多少 {currency}？手续费会**额外加收**，因此账户
  > 实际扣款会比这个数略多。

⛔ **STOP.** On input, normalize (strip thousand separators `,`, trim whitespace) and locally validate `^\d+(\.\d+)?$` (same regex as fiat STEP 5). On failure:

> Amount must be a positive decimal, e.g. "200" or "0.5". Please try again. / 金额必须是正小数，例如 "200" 或 "0.5"，请重新输入。

Also enforce decimal-places compliance (crypto precision varies; for USDT/USDC assume 6, for BTC/ETH assume 8 if no product base list is available).

A first, cheap entered-amount check against available balance (`crypto` → `instrumentInfoMap[{currency}].availableAmount`; the STEP 2 Funds-First early check already fetched/validated this, so reuse it unless a Token Guard re-login happened since). If `BigNumber(amount).gt(available)`:

> Your available {currency} balance is {avail}. Please enter an amount ≤ {avail}. / 您的 {currency} 可用余额是 {avail}，请输入不大于 {avail} 的金额。

Re-prompt in place — do NOT advance. (This is a fast local reject on the entered amount; the authoritative sufficiency check against the **total debit** comes from the quote below.)

On input received, call:
- `get_withdrawal_quote({ withdrawalParty, currency, amount, currencyType: 2 })` → `{ fee: { serviceFee, amountReceived, withdrawalAmount }, minimumAmount: { minimumAmount }, balance }` — one call returns the service fee, the **server-computed** recipient amount and total debit (the correct fee direction for the party is already applied server-side), the minimum amount, and the funding-account `balance` (pass `currencyType: 2` so it resolves the crypto account).

Record `serviceFee`, `amountReceived`, and `withdrawalAmount` from the quote for the STEP 8 confirmation card. **Do NOT compute these yourself** — display the server's values verbatim.

**Funds-First sufficiency gate (SKILL.md → Funds-First Gate, checkpoint 2).** Read `balance` from the quote:
- `balance.sufficient === false` → the total debit exceeds the available balance. Stop and tell the user the shortfall — do NOT proceed to STEP 6/7/8 or ask for a code:
  > Your available {currency} balance is {balance.availableAmount}, which doesn't cover the total debit of {withdrawalAmount} {currency} (including the {serviceFee} fee). Please enter a smaller amount, or type "cancel". / 您的 {currency} 可用余额为 {balance.availableAmount}，不足以支付总扣款 {withdrawalAmount} {currency}（含手续费 {serviceFee}）。请输入更小的金额，或输入"取消"。

  Re-prompt for a new amount (stay on STEP 5, re-fetch quote).
- `balance.sufficient === true` → proceed.
- `balance === null` (balance unresolved) → fall back to a fresh `get_account_detail({ productCode: 'crypto' })` and compare `BigNumber(withdrawalAmount).gt(available)` yourself before advancing. Never advance on an unverified balance.

If `amount < minimumAmount`:

> The minimum withdrawal for {currency} is {minimumAmount}. Please enter a larger amount. / {currency} 的最小提现金额是 {minimumAmount}，请输入更大的金额。

Re-prompt for a new amount (stay on STEP 5, re-fetch quote).

On success (sufficient balance + amount ≥ minimum): if `withdrawalParty === 2` proceed to STEP 6; otherwise skip STEPs 6 and 7 entirely (they're third-party only) and go to STEP 8 (confirmation).

---

## STEP 6 — Purpose of Transaction (third-party only)

Skip entirely if `withdrawalParty === 1`.

For `withdrawalParty === 2`, collect `purposeOfTransaction`. Prompt
(language follows user):

> Please describe the purpose of this transaction in a sentence
> (e.g. "Payment for invoice #INV-001"). / 请用一句话说明本次交易的
> 用途（例如「支付发票 #INV-001」）。

After receiving input, trim whitespace. If empty or whitespace-only →
re-show the same prompt. Record `purposeOfTransaction`.

Then proceed to STEP 7.

---

## STEP 7 — Supporting Document Upload (third-party only)

Skip entirely if `withdrawalParty === 1`.

Third-party crypto withdrawals require a supporting document (contract,
agreement, or invoice) so compliance can match the transaction to a
real off-platform agreement. The user uploads it through a one-time
browser link minted by the server — you do NOT receive or handle the
file directly.

### 7.1 — Request a fresh upload URL

Call `request_file_upload({ purpose: "crypto_withdrawal_proof" })`.

The response is `{ uploadUrl, fileRef, expiresInSeconds }`. Record
`fileRef` in skill state. **MUST call this every time you reach STEP 7,
even if a `fileRef` is already in state from an earlier turn or an
earlier flow — older upload URLs are auto-invalidated server-side as
soon as a new one is minted for the same user + purpose.**

⛔ Token Guard applies — if the response has `success: false` and
`authPageUrl`, follow the Token Guard rule in SKILL.md.

### 7.2 — Present the link and wait

Render (language follows user):

English:
```
To complete this third-party withdrawal, please upload a supporting
document (contract, agreement, or invoice) here:

**[Open upload page]({uploadUrl})**

Accepted formats: PDF, PNG, JPEG, WebP. Maximum size: 5 MB. The link is
valid for the next {minutes} minutes.

Reply **"uploaded"** (or **"已上传"**) once the upload page shows
success, and I'll continue. Reply **"cancel"** to abort.
```

Chinese:
```
为完成本次三方提现，请通过以下链接上传支撑材料（合同 / 协议 / 发票）：

**[打开上传页]({uploadUrl})**

支持格式：PDF、PNG、JPEG、WebP。文件大小不超过 5 MB。该链接在 {minutes}
分钟内有效。

上传成功后回复 **"已上传"** 或 **"uploaded"**，我会继续后续步骤。回复
**"取消"** 可放弃本次提现。
```

Where `{minutes}` is `Math.floor(expiresInSeconds / 60)`.

⛔ **STOP.** Wait for the user. Keyword routing:

- `uploaded` / `已上传` / `done` / `好了` / `上传完成` → go to **7.3 (verify the upload landed)** below — do NOT jump straight to STEP 8.
- `cancel` / `取消` / `放弃` → abort.
- `back` / `返回` / `上一步` → return to STEP 6 (re-enter purpose).
  Do NOT call `request_file_upload` again immediately — only re-mint
  when re-entering STEP 7.
- Any other input → re-show the link with a short nudge:
  > I'll wait until the upload is done — reply "uploaded" or "已上传"
  > once the upload page shows success.

⚠️ Do NOT silently assume the upload happened just because time passed.
The server-side CAS check at submit time means a stale `fileRef` will
fail the withdrawal — the explicit user confirmation is your signal that
a real file is now on file.

If the user reports the upload page showed an error, suggest they retry
on the same link first; if the link itself shows expired/invalid,
re-enter STEP 7 (which will mint a new URL).

> **Cross-flow stomp:** if the user starts a second withdrawal flow
> mid-air (in another chat / tab / message), that second flow's
> `request_file_upload` will invalidate THIS flow's link, and any
> upload the user already finished against this link becomes
> unusable. There is no way to recover the prior file — the user must
> upload again against the freshest link. If execution later fails
> with a "supporting document invalid/expired" error (see STEP 9
> failure handling), it almost always means this happened.

### 7.3 — Verify the upload landed (before STEP 8)

When the user confirms the upload, call `check_file_upload({ fileRef, purpose: "crypto_withdrawal_proof" })` with the `fileRef` from 7.1. This is a read-only existence check — it does NOT mint a new URL.

- `{ uploaded: true }` → proceed to STEP 8.
- `{ uploaded: false }` → the file isn't on the server yet (upload not finished, or the link was superseded by a newer one). Tell the user — in their language — that you don't see it yet, ask them to confirm the upload page showed success, then reply "uploaded" again. **Stay on this step — do NOT re-mint a new URL** (re-minting would invalidate a file they may have just uploaded) and do NOT advance to STEP 8:
  > I don't see the document on file yet. Please make sure the upload page showed success, then reply "uploaded" again. / 我这边还没收到该文件。请确认上传页显示「成功」后，再回复"已上传"。
- ⛔ Token Guard applies — `success: false` with `authPageUrl` → follow the Token Guard rule in SKILL.md.

**Why verify here:** the server only hard-validates the document at `execute_crypto_withdrawal` time (STEP 9). Checking now turns a late, end-of-flow failure into immediate feedback. The STEP 9 server-side CAS check still stands as the final backstop.

Then proceed to STEP 8.

---

## STEP 8 — Confirm Card + Verification Code

Use the `serviceFee`, `amountReceived`, and `withdrawalAmount` recorded
from the STEP 5 quote — **display them verbatim, do not recompute.** The
server already applied the correct fee direction for the party type
(third-party: fee on top, so `amountReceived` = entered amount and
`withdrawalAmount` = entered + fee; first-party: fee deducted, so
`amountReceived` = entered − fee and `withdrawalAmount` = entered amount).
Letting the model do this arithmetic is exactly what caused the old
"you receive 19.98" bug, so don't.

Render confirmation card (language follows user; Chinese variant below):

English:
```
Please confirm your crypto withdrawal:

| | |
|---|---|
| Currency | {currency} |
| Amount to recipient | {amountReceived} {currency} |
| Network | {selectedWallet.network} |
| Destination wallet | {walletTag} — {walletAddress} |
| Owner | {ownerName} ({withdrawalParty === 1 ? "first-party" : "third-party"}) |
| Service fee | {serviceFee} {currency} |
| Total debited from account | {withdrawalAmount} {currency} |
```

Chinese:
```
请确认本次加密货币提现：

| | |
|---|---|
| 币种 | {currency} |
| 对方到账金额 | {amountReceived} {currency} |
| 网络 | {selectedWallet.network} |
| 目标钱包 | {walletTag} — {walletAddress} |
| 持有人 | {ownerName}（{withdrawalParty === 1 ? "一方" : "三方"}） |
| 手续费 | {serviceFee} {currency} |
| 账户实际扣款 | {withdrawalAmount} {currency} |
```

For `withdrawalParty === 2`, append exactly **two** additional rows:

```
| Purpose | {purposeOfTransaction} |
| Supporting document | uploaded ✓ |
```

The "Supporting document" row is purely a status indicator so the user
can see their upload was registered. Do NOT show the raw `fileRef`
string or any internal identifier.

After the card, add this one-line caveat (the quote is fee-only and cannot
know any deduction, which is applied at execution):

> Note: these are fee-based estimates. If a deduction/credit applies it is
> applied at submission — the final figures (including any deductible
> amount) are shown on the receipt. / 注：以上为含手续费的预估金额。如有抵扣
> 将在提交时计算，最终金额（含抵扣金额）以提交后的回执为准。

Then:

```
⚠ **Irreversible operation.** Once submitted, the on-chain transaction cannot be recalled. Please verify the destination address and network are exactly correct before confirming. (You will enter your verification code in the next step.)
```

End the card with:

> Type `confirm` or `确认` to proceed, "back" to edit previous fields, or "cancel" to abort. / 输入 `confirm` 或 `确认` 继续，"返回"修改前序字段，"取消"退出。

⛔ **STOP.** Per the SKILL.md **Transaction Confirmation Gate**, accept ONLY an exact `confirm` / `确认` here (trimmed, case-folded). Anything else — `yes` / `好` / `ok` / `确定`, or a verification code typed early — does NOT count → re-ask for `confirm` / `确认`. Do NOT request or accept the verification code at this step; the code is asked separately in STEP 8.1 only AFTER a valid confirmation. `back` / `cancel` route as below.

Keyword routing (checked before step-specific parsing):
- `back` / `返回` / `上一步` →
  - if `withdrawalParty === 2` → return to STEP 7, which always re-mints
    a fresh upload URL (per STEP 7's own contract) and requires the user
    to upload again. Tell the user concisely:
    > Going back to the upload step — I'll generate a fresh upload
    > link. The previous one is no longer valid. / 已返回上传步骤，
    > 我会生成新的上传链接，原链接失效。
    A second `back` from STEP 7 returns to STEP 6 (re-enter
    `purposeOfTransaction`); a third returns to STEP 5 (re-enter amount).
  - if `withdrawalParty === 1` → return to STEP 5 (re-enter amount).
- `cancel` / `取消` / `放弃` → abort.

**Note:** if the user just wants to retype the verification code (e.g.
their TOTP rotated), they should NOT use "back" — just re-send the
correct code. "back" is destructive in the third-party path because it
forces a fresh upload.

## STEP 8.1 — Verification code (only after an exact `confirm` / `确认`)

Reached ONLY once STEP 8 received an exact `confirm` / `确认`. Prompt:

> Please enter your 6-digit verification code from your authenticator app (e.g. Google Authenticator). / 请输入您认证器应用中的 6 位动态验证码（如 Google Authenticator）。

⛔ **STOP.** Wait for a `verificationCode` string.

If the supplied code is not exactly 6 digits:
> The code must be exactly 6 digits. Please try again. / 验证码必须是 6 位数字，请重新输入。

If the user wants to retype the code (e.g. their TOTP rotated), they just re-send the correct code — do NOT use "back" (back is destructive in the third-party path, forcing a fresh upload). `cancel` / `取消` aborts.

Once a valid 6-digit code is received → proceed to STEP 9 (Execute).

Once both the confirmation (STEP 8) and the code (STEP 8.1) are in hand → proceed to STEP 9 (the "Execute" section below). Progress header counts:
- First-party: confirmation card is `Step 6/7`, execution is `Step 7/7`.
- Third-party: confirmation card is `Step 8/9`, execution is `Step 9/9`.

The doc section number ("STEP 8 / STEP 9") and the user-facing progress
header are intentionally decoupled — first-party silently collapses
STEPs 6 and 7 because they're third-party only.

---

## STEP 9 — Execute

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

Do NOT pass `fileRef`, `purposeOfTransaction`, `proof`, or `photo` — first-party does not require compliance fields, and `proof` / `photo` are not part of the tool schema anymore.

### Third-party (`withdrawalParty === 2`)

`purposeOfTransaction` was collected in STEP 6 and `fileRef` was minted
+ confirmed in STEP 7. Execute:

```ts
execute_crypto_withdrawal({
  withdrawalParty: 2,
  currency,
  amount,
  walletAddress: selectedWallet.walletAddress,
  network: selectedWallet.network,
  verificationCode,
  fileRef,
  purposeOfTransaction,
})
```

Do NOT pass `proof` or `photo` (those fields no longer exist in the
schema). Do NOT mint a new `request_file_upload` here — it would
invalidate the `fileRef` you just collected. The server validates
`fileRef` server-side: it must belong to the same user, match
`purpose = "crypto_withdrawal_proof"`, and still be in the active slot;
on success the upload record is consumed and removed.

### On success

Render result card (only show rows where the field is present in the response). Language follows the user; Chinese variant below.

**Use the server's returned amounts verbatim — do NOT recompute.** The
backend already applied the correct fee direction AND any deduction for
this transaction: `amountReceived` is what the recipient gets,
`withdrawalAmount` is the total debited from the account, `chargeAmount`
is the gross service fee, and `deductibleAmount` is any credit/offset
applied (often `0`, but can reduce the net charge — show it when it is
present and non-zero so the user sees why the figures differ from the
STEP 8 estimate). The STEP 8 confirmation card is a fee-only estimate and
does NOT include `deductibleAmount`, so these executed numbers are the
source of truth. If `amountReceived` is absent, fall back to the
skill-state `amountReceived` from STEP 8 (never to the raw entered
`amount`). For `Network`, prefer the response `network` and fall back to
`selectedWallet.network` when it is null.

English:
```
✅ **Withdrawal Submitted**

| | |
|---|---|
| TX Code | {txCode} |
| Currency | {currency} |
| Status | {status} (pending) |
| Amount to recipient | {amountReceived} |       ← if present, else STEP-8 amountReceived
| Service fee | {chargeAmount} |                  ← if present
| Deductible amount | {deductibleAmount} |       ← if present and ≠ 0
| Total debited | {withdrawalAmount} |           ← if present
| Destination | {selectedWallet.walletAddress} |
| Network | {network ?? selectedWallet.network} |
| Time | {createAt} |                            ← if present
```

Chinese:
```
✅ **提现已提交**

| | |
|---|---|
| 交易码 | {txCode} |
| 币种 | {currency} |
| 状态 | {status}（处理中） |
| 对方到账金额 | {amountReceived} |            ← 如有返回，否则取 STEP 8 的 amountReceived |
| 手续费 | {chargeAmount} |                    ← 如有返回
| 抵扣金额 | {deductibleAmount} |              ← 如有返回且非 0
| 账户实际扣款 | {withdrawalAmount} |          ← 如有返回
| 接收方 | {selectedWallet.walletAddress} |
| 网络 | {network ?? selectedWallet.network} |
| 时间 | {createAt} |                          ← 如有返回
```

Then **STOP** (flow complete).

### On failure — Token Guard (check FIRST)

If response contains `success: false` with `authPageUrl` → follow **Token Guard** rule in SKILL.md Absolute Rules. Do NOT proceed to error handling below.

### On failure — step-specific

- If the backend `msg` indicates the uploaded proof is invalid / expired / does not belong to the user / purpose mismatch → output:
  > The supporting document couldn't be matched — the upload link likely expired or was replaced by a newer one. I'll get you a fresh link, and once it's uploaded we'll finish with your verification code. / 上传的支撑材料未能匹配，通常是上传链接过期或被新链接替换了。我来重新生成上传链接，传好后我们用验证码完成最后一步。

  Then return to STEP 7 (which re-mints via `request_file_upload`). Keep
  amount and purpose state, but **discard the verification code** — per the
  "Verification Code Is the Terminal Input" rule, after re-upload you come
  back through the STEP 8 card and ask for a fresh code. The old code
  authorized a submission that already failed and the TOTP has likely
  rotated; never resubmit with it.

- If the backend `msg` indicates "invalid verification code" / "expired code" / similar → output:
  > Your verification code is invalid or expired. Please open your authenticator app, get the current 6-digit code, and paste it here. / 验证码无效或已过期，请打开验证器 App 获取当前 6 位验证码后重新输入。

  Go back to the final prompt of STEP 8 (keep everything else, including the existing `fileRef` and `purposeOfTransaction`; wait only for a new code).

- Any other backend error → output:
  > Withdrawal failed: {reason}. Funds may or may not have been reserved — please check your transaction history before retrying. / 提现失败：{reason}。资金可能已被冻结，请先查看交易记录再决定是否重试。

  Then **STOP**.

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
Returns: `{ wallets: Array<{ walletAddress, network, walletTag, ownerName }> }`. Use `withdrawalParty: 1` for first-party, `2` for third-party.

### `get_crypto_deposit_networks`
```json
{ "currency": "USDT" }
```
Returns: `{ networks: string[] }` — networks that support the given currency. Reused from deposit flow for compatibility checking.

### `get_withdrawal_quote`

Input: `{ withdrawalParty: 1|2, currency, amount, currencyType: 2 }` (pass `currencyType: 2` for crypto so the funding-account balance resolves)
Output: `{ fee: { serviceFee, amountReceived, withdrawalAmount }, minimumAmount: { minimumAmount }, balance: { currency, availableAmount, sufficient } | null }`
Purpose: single call returning fee + minimum + funding-account balance. `balance.sufficient` is computed server-side against the **total debit** (`fee.withdrawalAmount`) — gate on it per SKILL.md → Funds-First Gate. `balance` is `null` when it couldn't be resolved (currencyType omitted / lookup failed); fall back to a fresh `get_account_detail({ productCode: 'crypto' })`. Downstream fee/minimum calls run in parallel; any failure fails the whole call.

### `request_file_upload`

```json
{ "purpose": "crypto_withdrawal_proof" }
```

Returns: `{ uploadUrl, fileRef, expiresInSeconds }`. Mints a one-time
browser upload URL for the active user. Each call SUPERSEDES any prior
pending upload for the same `(user, purpose)` — the previous URL stops
working server-side as soon as a new one is minted. Always call inside
STEP 7 of the third-party crypto withdrawal flow; never reuse a
`fileRef` from an earlier flow.

### `check_file_upload`

```json
{ "fileRef": "f_8c1a9e...", "purpose": "crypto_withdrawal_proof" }
```

Returns: `{ uploaded: boolean }`. Read-only existence check for the
document behind `fileRef` — `true` only when a file has actually been
uploaded for that `fileRef` and it belongs to the current user (and
matches `purpose`). Used in STEP 7.3 to verify the upload landed before
STEP 8 / execution. Does NOT mint a new URL, so it never invalidates a
pending upload. A `false` result means keep waiting on the same link —
do not re-mint.

### `execute_crypto_withdrawal`

First-party example (full address — never truncate in user-facing output):
```json
{
  "withdrawalParty": 1,
  "currency": "USDT",
  "amount": "500",
  "walletAddress": "0x1234567890abcdef1234567890abcdef12345678",
  "network": "ETH",
  "verificationCode": "123456"
}
```

Third-party example — `fileRef` comes from the prior
`request_file_upload` call in STEP 7; `purposeOfTransaction` from STEP 6:
```json
{
  "withdrawalParty": 2,
  "currency": "USDT",
  "amount": "500",
  "walletAddress": "TXYZabcdefghijklmnopqrstuvwxyz123456",
  "network": "TRON",
  "verificationCode": "123456",
  "fileRef": "f_8c1a9e...",
  "purposeOfTransaction": "Payment for invoice #INV-001"
}
```

Returns: `{ txCode, currency, status, withdrawalAmount?, chargeAmount?, totalChargeAmount?, deductibleAmount?, amountReceived?, to?, network?, createAt?, updateAt? }`.

The `proof` and `photo` fields no longer exist in the schema. Third-party
crypto withdrawals MUST send `fileRef`; first-party MUST NOT.
