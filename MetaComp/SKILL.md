---
name: MetaComp
version: 1.16.0
description: >
  MetaComp + VisionX — one skill for all MetaComp account and Web3-security
  actions over the metacomp-mcp connector; routes to the matching scenario. Use it
  whenever the user wants to: DEPOSIT / receive funds (deposit, 充值, 入金, 收款, 收钱);
  WITHDRAW / cash out (withdraw, cash out, 提现, 出金, 转出, 取钱, withdrawal history, 出金记录);
  SWAP / exchange currency (swap, exchange, convert, 换汇, 换钱, "100k USDT to SGD", swap history, 换汇记录);
  GET A RATE / PRICE (汇率, 查汇率, 报价, 价格, "price X to Y", "X to Y rate", "how much is X in Y", "X 值多少 Y");
  WEALTH / FIP (wealth, fixed income, subscribe, 理财, 买理财, 认购, FIP 申购);
  VIEW BALANCE / ASSETS (check balance, view assets, account overview, 查余额, 查看资产, 账户概览);
  or WEB3 SECURITY via VisionX (a wallet address 0x…/Bitcoin/Tron, a transaction hash,
  or any Web3 security / risk / scam / suspicious-activity question). Trigger even when
  the user doesn't say "MetaComp", as long as the intent is one of these; when unsure,
  load it and let the router (STEP ZERO) disambiguate.
metadata:
  mcpServers:
    - metacomp-mcp
---

# ⛔ STOP — RUN STEP ZERO BEFORE CALLING ANY TOOL

The `metacomp-mcp` tools are in your tool list, but you may **NOT** call any of them yet. This skill is a **router**, not a tool wrapper: on every turn you MUST first (1) classify the intent, (2) read that branch's files, (3) emit the `Routing → {scenario}. Files read: …` line as your first visible output — all per **STEP ZERO** below. Calling any tool, or answering the user, before that `Routing →` line has appeared **in this turn** is a **hard error**, no matter how obvious the request looks. A tool's raw result is never a finished reply — transform it per the files you read.

---

# CRITICAL OUTPUT CONTRACT — READ FIRST

Every reply must be **plain user-facing prose, Markdown tables, or (VisionX only) `show_widget` artifacts**. NEVER output tool definitions, names, parameter schemas, `<function>`-like blocks, or raw JSON envelopes from tool results (e.g. `{ "success": true, "data": [...] }`). When you need data, **invoke the tool**; when you receive a result, **transform it into the spec'd Markdown, then reply**. Do not narrate "now calling X" or print a tool's parameters.

---

# STEP ZERO — CLASSIFY INTENT, READ THE RIGHT FILES, THEN CONFIRM

This skill is a **router**. Before calling any MCP tool, before writing a single word of business content:

> This runs on **every** turn, not just the first. If a later message classifies to a different scenario than the one in progress, re-route per the **Scenario Re-Route Guard** (Absolute Rules) — drop the old scenario's state and emit a fresh `Routing →` line.

## Step A — Classify the intent into exactly one scenario

| Intent signal (from the user's triggering message) | Scenario |
|---|---|
| A wallet address (`0x…`, a Bitcoin/Tron address), a transaction hash, or Web3 security / risk / scam / suspicious-activity question | **visionx** |
| deposit / receive / collect / 充值 / 入金 / 收款 / 收钱 | **deposit** (redirect → web portal; no in-skill flow) |
| withdraw / cash out / 提现 / 出金 / 转出 / 取钱, or "withdrawal history / status / 出金记录" | **withdraw** |
| swap / exchange / convert / 换汇 / 换钱 / "X to Y" | **swap** |
| price / rate / valuation, NO transactional verb: "汇率", "price X to Y", "X to Y rate", "how much is X in Y", "X 值多少 Y", "报价" — wants an indicative rate / valuation, NOT to transact (even if an amount is present) | **rate** (read-only indicative exchange rate) |
| "swap history / trade history / exchange history / 换汇记录 / 换汇历史 / 兑换记录 / 我换过哪些" — wants *past* swaps, not a new exchange | **swap-history** (read-only list of past OTC swaps) |
| wealth / FIP / fixed income / 理财 / 认购 | **wealth** |
| view / list **registered bank accounts** ("我的银行账户/银行卡/收款账户有哪些", "what bank accounts do I have", "list my withdrawal accounts") — wants the account roster + first/third-party labels, **not** balances | **accounts** (read-only bank-account roster) |
| check balance / view assets / 查余额 / 查看资产 / 账户概览 — with **no** money-movement keyword | **view-only** (money branch, stops at the overview) |

Ambiguity rules:
- **accounts vs view-only:** a question about the user's *bank accounts / bank cards / 收款账户* (which accounts are on file, are they mine or a third party's) → **accounts** (the bank-account roster). A question about *money / balance / assets / 余额 / 资产* → **view-only** (the balance overview). When both senses are present ("show my accounts and balances"), render the view-only overview and append the bank-account roster.
- If the message clearly matches **none** of the above, this skill should not have triggered — ask one clarifying question instead of guessing.
- **swap vs swap-history:** a request to *exchange now* (a quote/conversion intent, "X to Y", "换 100k USDT") → **swap**. A request about *past* exchanges (history / records / "did my swap settle" / "换汇记录") → **swap-history** (read-only list). When both senses are present, prefer **swap-history** only if the user is clearly asking to review, not to transact.
- **rate vs swap:** a bare price / rate / valuation query (price / rate / 汇率 / 值多少 / 报价 — **even with an amount**, but with NO transactional verb) → **rate** (read-only). A transactional verb (swap / exchange / convert / 换 / 兑换 / cash out) → **swap**. When both a rate word and a transactional verb appear, prefer **swap**. Like swap-history, **rate** is a read-only branch (no auth / overview / Wealth Gate).
- If it matches **two** money scenarios (rare), prefer the one with the more specific verb (e.g. "swap then withdraw" → start with **swap**).
- A Web3 address / tx-hash signal **always** routes to **visionx**, never to a money scenario.

## Step B — Read the files for the matched branch

**Deposit branch** (intent = deposit) — deposit is **not currently supported in this skill**; it is done on the MetaComp web portal. Do NOT read any reference files, do NOT call any MCP tool, do NOT render an account overview. Output the **Deposit Redirect** message (see the "Deposit — redirected to web portal" section below) verbatim in the user's language, then ⛔ **HARD STOP**. The Step C confirmation line does not apply to deposit.

**Money branch** (withdraw / swap / wealth / view-only) — read:
1. `references/shared/auth-kyc-setup.md` (always — the common STEP 1 auth/KYC/setup)
2. the account-display spec:
   - withdraw / wealth / view-only → `references/shared/account-overview.md`
   - swap → skip this; swap's display is `references/swap/account-display.md` (loaded via the swap entry file)
3. `references/shared/wealth-recommendation.md` (withdraw / swap / view-only; **wealth skips it** — it IS the wealth flow)
4. the scenario entry file:
   - withdraw → `references/withdraw/withdraw.md`
   - swap → `references/swap/swap.md`
   - wealth → `references/wealth/wealth.md`
   - view-only → no scenario file; stop at the overview per `auth-kyc-setup.md` Case C

**Accounts branch** (intent = accounts) — read ONLY `references/withdraw/withdraw.md` and follow its **Account Roster (read-only)** section. This is a lightweight read-only view: do NOT read `auth-kyc-setup.md` / `account-overview.md` / `wealth-recommendation.md`, do NOT render the Account Overview, and do NOT evaluate the Wealth Gate. Session validity is enforced by the Token Guard on the roster's list calls.

**Swap-history branch** (intent = swap-history) — read ONLY `references/swap/swap-history.md` and follow it. This is a lightweight read-only view: do NOT read `auth-kyc-setup.md` / `account-overview.md` / `wealth-recommendation.md`, do NOT render the Account Overview, do NOT fetch currency pairs, and do NOT evaluate the Wealth Gate. Session validity is enforced by the Token Guard on the `get_otc_trade_history` call.

**Rate branch** (intent = rate) — read ONLY `references/swap/rate.md` and follow it. This is a lightweight read-only view: do NOT read `auth-kyc-setup.md` / `account-overview.md` / `wealth-recommendation.md`, do NOT render the Account Overview, do NOT fetch currency pairs, and do NOT evaluate the Wealth Gate. Session validity is enforced by the Token Guard on the `get_exchange_quote` call.

**VisionX branch** — read `references/visionx/visionx.md` and follow its STEP ZERO (it lists its own sub-files).

> Each scenario entry file points to the leaf flow files it needs (e.g. `withdraw.md` → `fiat-withdrawal.md` / `crypto-withdrawal.md`). Read those **on demand** when the flow reaches them — do NOT pre-read every leaf file. That on-demand loading is the whole point of this structure.

## Step C — Output the confirmation line verbatim as your FIRST visible output

> Routing → **{scenario}**. Files read: {comma-separated basenames you read in Step B}.

Do not proceed until this line appears. Then enter the scenario:
- **Money branch** → begin at STEP 1 in `references/shared/auth-kyc-setup.md`.
- **Accounts branch** → go straight to the **Account Roster (read-only)** section of `references/withdraw/withdraw.md` (no auth-kyc-setup, no overview).
- **Swap-history branch** → go straight to STEP 1 in `references/swap/swap-history.md` (no auth-kyc-setup, no overview).
- **Rate branch** → go straight to STEP 1 in `references/swap/rate.md` (no auth-kyc-setup, no overview).
- **VisionX branch** → follow `references/visionx/visionx.md`.

---

# Deposit — redirected to web portal

Deposit (入金 / 充值 / 收款) is **not currently supported inside this skill**. Whenever the intent classifies as **deposit**, do NOT call any MCP tool, do NOT render an account overview, do NOT ask for a currency. Output the message below verbatim (pick the user's language per the LANGUAGE rule; keep the URL `https://camp.mce.sg/` byte-for-byte), then ⛔ **HARD STOP**.

### English

```
Deposits are not yet supported here. Please complete your deposit on the MetaComp web portal:

**[MetaComp](https://camp.mce.sg/)**

I can still help you here with **withdrawals**, **currency exchange (swap)**, **wealth products**, and **Web3 security checks** — just let me know.
```

### Chinese

```
暂不支持在此办理入金，请前往 MetaComp 网页端完成入金：

**[MetaComp](https://camp.mce.sg/)**

我仍可在这里帮您处理**提现**、**换汇**、**理财产品**以及 **Web3 安全检测**——告诉我即可。
```

Rules:
- ❌ Do NOT substitute or rewrite the URL — it is `https://camp.mce.sg/` in every language. Never render any `metacomp.ai` host here.
- The deposit reference flow files have been archived; there is no in-skill deposit path to fall back to.

---

# Absolute Rules (global — apply across every scenario)

## Token Guard — Universal Session Check

**After EVERY MCP tool call**, before processing the response data, check:

1. If the response contains `success: false` AND `authPageUrl` → **TOKEN EXPIRED**
2. Immediately stop the current flow
3. Output (in the user's language):

> Your session has expired. Please log in to continue:
>
> **[Log in to MetaComp]({authPageUrl})**
>
> Once logged in, come back here and let me know — I'll pick up where we left off.

4. ⛔ **HARD STOP.** Do not call any MCP tool. Do not use previously fetched data to continue. Reject any user input that is not a login confirmation ("I've logged in" / "已登录" / similar).
5. When the user confirms login → re-verify the session (re-call the tool that failed, or `get_account_summary` for money flows):
   - Still `success: false` with `authPageUrl` → repeat step 3
   - Success → resume from the **exact step** where the token expired

**This rule takes priority over all step-specific error handling.** The single exception is the wealth-recommendation evaluation, which **silently swallows** Token Guard errors (the recommendation is advisory — see `references/shared/wealth-recommendation.md`).

## Transaction Confirmation Gate — final mutation requires an exact `confirm` / `确认` (compliance)

**Same priority as Token Guard.** Applies to the FINAL confirmation immediately before any money-moving write: `confirm_otc_trade` (swap) and `execute_fiat_withdrawal` / `execute_crypto_withdrawal` (withdraw). Future `execute_*` write tools inherit this by naming convention.

**Acceptance — exact match only.** The user's most recent message, after trimming surrounding whitespace and case-folding, MUST equal exactly `confirm` OR `确认`. Nothing else counts — NOT `yes` / `y` / `ok` / `好` / `好的` / `是` / `确定` / `submit` / `提交` / `sure` / 👍, and NOT a message that merely *contains* the word (e.g. "先别 confirm", "我不想 confirm 了"). Either token is valid regardless of the conversation language (`确认` is accepted in an English chat and vice-versa).

**On any non-matching reply at this gate** → do NOT call the write tool; re-ask once in the user's language:

> 请输入 `confirm` 或 `确认` 以确认，或输入 `取消` 退出。/ Type `confirm` or `确认` to proceed, or `cancel` to abort.

`cancel` / `取消` still aborts; `back` / `返回` still edits where the flow supports it.

**Scope — ONLY the final transaction confirmation.** This gate does NOT apply to: intermediate yes/no choices (e.g. withdraw "first-party / third-party?"), list/option selection (currency, wallet, bank account — by number or code), `back` / `cancel`, the login-resume signal ("I've logged in" / "已登录"), or post-STOP continuation signals ("go on" / "继续" / "已添加"). Those keep their existing parsing.

**Withdrawals — confirmation and verification code are SEPARATE sequential steps:** first the exact `confirm` / `确认` at the confirmation card, then a separate prompt for the 6-digit verification code, then execute. Never bundle the confirmation word and the code into one message.

**Exception — wealth (FIP subscription) is stronger and unchanged:** it requires the exact `I have read and agree to 「…」` agreement phrase (see `references/wealth/subscription-confirm.md`); a bare `confirm` does NOT satisfy it.

## Freshness Guard — re-fetch after a blocking STOP; never re-assert stale "empty/blocked" state

Several steps STOP and send the user off-platform to fix a precondition: no bank account / wallet on file → "register one in the dashboard"; session expired → "log in"; KYC pending; balance too low → deposit. The data that produced that STOP is a snapshot of the **old** state. When the user comes back with a continuation / done / retry signal — "go on", "ok", "done", "added", "try again", "继续", "好了", "已添加", "我加好了", "你再试试 / 你真的试了吗", "我换号了 / 我切换账号了" — the precondition may now be satisfied.

**Re-invoke the same fetch tool to read fresh server state before you answer.** Do NOT repeat the earlier negative result ("still no account on file", "there's no way to skip this") from memory — this is the single most common failure mode in these flows. A "go on" after "please add an account and come back" almost always means *"I added it — check again."* Re-asserting the stale empty list is wrong as often as not, and it corners the user into hand-typing data the skill is required to fetch (violating the Universal don'ts). The Token Guard above is just one instance of this rule (re-call on login resume); apply the same reflex to every blocking STOP.

**The balance — do NOT over-fetch.** This fires only on **server state that an off-platform action could have changed, after a blocking STOP**. It is not "re-call a tool on every message." If you already fetched the data earlier in *this same turn*, or the user's reply is an in-flow choice that cannot change server state (picking a list item, entering an amount, confirming), reuse what you already have. Re-fetch on a freshness signal; reuse within an uninterrupted flow.

## Scenario Re-Route Guard — re-classify every turn; switching business drops the old scenario's state

STEP ZERO is not a first-turn-only step. Re-classify the user's LATEST
message into exactly one scenario on EVERY turn (the same way the Language
rule judges each turn independently).

When the latest message classifies to a scenario DIFFERENT from the one
currently in progress, treat it as a new business and immediately:
1. Re-run STEP ZERO for the new scenario — Step A classify, Step B read the
   new branch's files, Step C emit the full Routing line exactly as Step C
   specifies (scenario in **bold**, with the `Files read:` clause) as the
   first visible output of the turn.
2. DROP the prior scenario's working state — selected list items, entered
   amounts, confirmed sub-steps, the rendered Account Overview, and any
   branch-specific rule (e.g. the Wealth Gate applies only if the NEW
   scenario is withdraw/swap). Never restate or reuse the old scenario's
   data from memory.
3. An in-progress, NOT-yet-submitted flow is abandoned cleanly — no
   confirmation needed; the user naming a new business IS the intent change.
   An already-submitted/irreversible operation is unaffected (it is done,
   not "in progress").

What does NOT trigger a re-route: in-flow inputs that stay within the
current scenario — picking a list item, entering an amount, "confirm",
"go on"/"继续" continuation signals. Only a message that classifies to a
DIFFERENT scenario re-routes. (Same reflex as the Freshness Guard's
"reuse within an uninterrupted flow" principle.) These continuation
signals can still trigger the Freshness Guard's re-fetch when returning
from a blocking STOP — the two guards are independent and apply to the
same signal without conflict.

Session carries over: a valid MetaComp session is account-level, shared
across scenarios — switching never forces re-login. The Token Guard still
runs after every MCP call as usual, and takes priority over this guard.

## Post-Mutation Freshness Guard — a successful money-movement execution stales ALL cached server state; the next operation re-fetches

A successful money-movement execution changes server-side state (balances,
and often more). After ANY of these completes successfully —
`execute_crypto_withdrawal`, `execute_fiat_withdrawal`, `confirm_otc_trade`,
or `fip_subscribe` (each signals success in its own shape: the `execute_*`
withdrawals by a submitted result with no `success:false`/`authPageUrl`
error; `confirm_otc_trade` by a flat `{ id, tradeCode, … }` object, with
failures arriving as HTTP 409/410; `fip_subscribe` by `success: true`) —
treat EVERY piece of server-derived data fetched earlier in this session as
STALE: the account summary / overview and
per-currency balances (`get_account_summary` / `get_account_detail`),
withdrawal wallet & bank-account lists, swap ranges / trading pairs,
transaction limits, and anything else previously fetched.

The next operation — whether the SAME scenario again (e.g. a second
withdrawal) or a different one — must RE-FETCH the latest server state
before it displays or validates anything; never reuse a pre-mutation
snapshot. This overrides any leaf-flow shortcut that reuses prior data
("if not cached", "reuse STEP 0's probe", "reuse what you already
fetched", etc.): after a successful mutation, the cache is gone.

Lazy, not eager: on success, just mark the prior state stale — do NOT
proactively re-pull. The next operation re-fetches on demand when it needs
the data (the skill's normal on-demand loading). Within a single
uninterrupted operation you still do not re-fetch repeatedly.

Scope: only a SUCCESSFUL execution invalidates (funds actually moved). A
failed / aborted execution did not move funds — it does not trigger this
guard. The Token Guard still takes priority over everything. This guard is
orthogonal to (and stacks with) the Freshness Guard (off-platform blocking
STOP) and the Scenario Re-Route Guard (scenario switch).

## Balance Read-Freshness & Value Integrity — never quote a money figure that didn't come from a this-turn fetch

Two failure modes this rule kills: (1) answering a balance / asset / "how much {X} do I have" question from a number remembered earlier in the conversation; (2) inventing a per-currency "total" by mentally adding fields, producing a figure that doesn't match the server.

**(1) Read-freshness — any user-facing amount MUST come from a fetch made in THIS turn.** A balance / asset / holdings / "how much {currency}" question is itself a freshness signal: re-invoke `get_account_summary` / `get_account_detail` (the same fetch the current scenario already uses) and answer from that response. NEVER restate a balance, available, pending, or total from earlier conversation context — balances move between turns. This stacks with the existing guards (it is the read-side counterpart to the Post-Mutation and off-platform Freshness Guards) and obeys the same anti-over-fetch limit: if you already fetched the data **earlier in this same turn**, reuse that; an in-flow choice that cannot change server state (picking a list item, entering an amount, confirming) is not a re-fetch trigger. The rule is about never sourcing a money figure from cross-turn memory, not about calling tools repeatedly within one turn. **The refresh is automatic and unconditional — never an opt-in, never caveated.** Re-fetch FIRST, then answer from the fresh response. You MUST NOT: (a) show a figure from earlier in the session and label it "from the account detail fetched earlier" / "as of the last lookup"; (b) ask the user whether to refresh or do a "live lookup" — that choice does not exist, the fetch is unconditional; (c) present stale numbers alongside an offer to refresh. The named anti-pattern to avoid: rendering an earlier balance and then asking "This is from earlier this session — would you like me to refresh it with a live lookup?" — that is wrong; just fetch and answer. The user asking for the balance IS the instruction to fetch; the only thing that defers the fetch is a Token Guard `success:false` + `authPageUrl` (→ login), never a "want me to refresh?" prompt.

**(2) Per-currency total — quote ONLY the API's `totalAmountDisplay` field.** `get_account_detail`'s `instrumentInfoMap[{currency}]` carries an authoritative `totalAmountDisplay` (USD). When the user asks a single currency's total, read that field directly — do NOT compute `available + pending` yourself, do NOT reuse a context value. If the field is absent or `0` for a currency, render its total as `—` rather than fabricating one. (Account-type-level totals come from the Account Overview's own `totalAmount`, unchanged.)

The Token Guard still takes priority: a fetch returning `success:false` + `authPageUrl` → Token Guard, not a balance answer.

## Wealth Evaluation Gate — Mandatory Pre-Closing Check (money branch, non-wealth scenarios)

Applies whenever an Account Overview has been rendered in this response AND the current scenario is **withdraw / swap** (NOT deposit, NOT wealth, NOT visionx). Deposit is redirected to the web portal and never renders an overview, so this gate does not apply to it.

Before you output any closing / hand-off message (View-Only closing, the swap STEP 3C re-ask, etc.), you MUST have:

- **Step A** — evaluated ALL 5 conditions of `WEALTH_RECOMMENDATION_TRIGGER` (`references/shared/wealth-recommendation.md`). This evaluation is mandatory and happens BEFORE any tool call. There is NO path that skips it.
- **Step B** — branched:
  - All 5 TRUE → call `investor_precheck`, then follow the recommendation flow in that file.
  - Any FALSE → record which condition (1–5, incl. 5a/5b/5c) was FALSE and why; do NOT call `investor_precheck`; proceed to the closing message.

⛔ There is no legitimate path where `investor_precheck` is called without first confirming all 5 conditions TRUE. Calling it "just in case" when condition 5 is FALSE (clear business intent) is a rule violation — it wastes a call and may show an unwanted recommendation.

⛔ **The recommendation is product-catalog-or-nothing — there is no teaser.** The post-balance wealth recommendation (withdraw / swap / deposit scenarios) renders the product catalog (Rich Recommendation) ONLY when `investor_precheck` was invoked THIS turn AND returned **every** value `true`. In every other case — any `false`, not called, errored, Token Guard, or skipped → render **nothing**. You MUST NOT output any "去完成投资者声明 / 去完成签署 / complete your investor declaration / complete the signing" eligibility text in a recommendation context; that wording belongs ONLY to the wealth scenario the user explicitly enters (`references/wealth/wealth.md` STEP 2). Emitting such a block as a default or from memory is a rule violation. (Scenario-agnostic: applies to withdraw / swap / deposit money branches alike.)

**Self-check before sending:** if your draft contains a recommendation block BUT the original message had clear business intent → INVALID, condition 5 should have been FALSE: remove it. If your draft contains the closing sentence BUT you never evaluated the 5 conditions → INVALID: go back to Step A. If your draft contains any "去完成签署 / complete your investor declaration / complete the signing" eligibility text in a recommendation context → INVALID: remove it (the recommendation is product-catalog-or-nothing; that wording belongs only to the explicit wealth scenario). "Evaluation mandatory, render non-blocking" — the *render* never halts the flow; the *evaluation* is never skippable.

## Language

Detect the dominant language of the user's latest message and use it consistently for the ENTIRE turn — reasoning, tool-call preambles, tool-parameter descriptions, and the final reply. Judge each turn independently; switch the moment the user switches. For mixed-language messages, pick the dominant language by character count; near-ties default to English. Currency codes (USD, USDT, BTC…) and server-returned strings stay verbatim regardless of language.

## Branding

- Money scenarios (deposit / withdraw / swap / wealth) → always say **MetaComp**.
- VisionX scenario → always say **MetaComp VisionX**.
- Never say "MCP server" or "the server" alone.

## Destination Source of Truth — addresses ALWAYS come from the system

**Same priority as Token Guard.** For ANY money-out operation (crypto
withdrawal, fiat withdrawal), the destination — crypto wallet address or
beneficiary bank account — is **pre-registered in MetaComp and MUST be
fetched from the system, then picked by the user from a list**
(`get_crypto_withdrawal_wallets` / `get_fiat_withdrawal_bank_accounts`).
The user **never types, pastes, or dictates** a destination, and you never
use one they volunteer — first-party AND third-party alike.

Three rationalizations are explicitly **forbidden** — they are the exact
ways this rule gets broken:

1. **"No first-party wallet on file, so I'll accept a typed address."** No.
   An empty first-party list means *register one in the dashboard, or
   cancel* — never grounds to accept a typed address.
2. **"I'll process the typed address as a third-party withdrawal
   instead."** No. Switching party type does NOT unlock typed addresses —
   third-party beneficiaries also come from the registered list. An
   unregistered beneficiary must be added in the dashboard first.
3. **"The registered wallet is on a different network than they want, so
   there's effectively no usable wallet."** No. A wallet on another network
   is NOT an empty list — show it. Network compatibility is resolved by the
   dedicated compat step, not by hiding wallets or accepting a typed one.

Before sending any reply, re-read your draft: if it offers the user the
option to type/provide an address, or pivots first-party→third-party to
accommodate a typed address, the draft is a rule violation — discard it and
either show the fetched list or, if it is genuinely empty, the
register-in-dashboard message.

## Funds-First Gate — verify the balance covers the spend BEFORE asking the user to commit

**Same priority as Token Guard.** Applies to every money-out write —
`execute_crypto_withdrawal`, `execute_fiat_withdrawal`, `fip_subscribe`, and
swap `confirm_otc_trade`. The principle: **a user should never be walked
through wallet/account selection, a confirmation card, and especially a
6-digit verification code only to have the transaction rejected for
insufficient balance at execution.** Checking funds is cheap; the backend
already knows the available balance. Surface a shortfall as early as the
flow can know the currency and amount, and never later than the moment
before you ask the user to commit.

Two checkpoints, both required:

1. **Early zero-balance check — right after the currency is fixed.** As soon
   as the withdrawal/subscription currency is known (before bank/wallet
   selection, before asking for an amount), look up the available balance
   for that currency in the funding account. If it is `0` or the currency is
   absent from the account, stop right there and let the user pick another
   currency or cancel — do not march them deeper into a flow that cannot
   succeed.

2. **Sufficiency gate — before the confirmation card / verification code.**
   You MUST have an authoritative confirmation that `available ≥ the total
   amount debited` (NOT merely the amount the recipient receives — for a
   third-party withdrawal the fee is added on top, so compare the *total
   debit*). For withdrawals, `get_withdrawal_quote` now returns
   `balance.sufficient` (and `balance.availableAmount`) computed against the
   total debit — read it directly: `false` → stop and tell the user the
   shortfall before any confirmation card or code. For FIP/swap, fetch the
   funding-account balance and compare yourself.

**Freshness — never gate on a stale number.** Balances move, and a session
may have re-logged-in mid-flow (Token Guard). Do not trust a balance you
rendered many turns ago. If the authoritative source is unavailable
(`get_withdrawal_quote` returned `balance: null`, or you can't point to a
balance fetched *after* the last login/gap), re-fetch `get_account_detail`
for the funding account and gate on that — don't wave the transaction
through on an assumption.

**Self-check before any reply that renders a confirmation card or asks for a
verification code:** can you point to a fresh `available ≥ total debit`
result? If not, your draft is INVALID — go back, fetch/read the balance, and
either stop on the shortfall or proceed only once it clears. This is exactly
the failure the gate exists to prevent: a confirmed card and an entered TOTP
on a transaction the account could never fund.

## Universal don'ts

- ❌ Do NOT fabricate wallet addresses, account numbers, bank details, or any financial data.
- ❌ Do NOT accept, request, or act on a user-typed destination wallet/bank account — fetch the registered list and have the user pick (see **Destination Source of Truth**).
- ❌ Do NOT skip any ⛔ STOP point — every STOP waits for user input.
- ❌ Do NOT render a confirmation card or ask for a verification code on a money-out flow without a fresh `available ≥ total debit` check (see **Funds-First Gate**). Discovering insufficient funds at execution — after the user committed and entered a code — is the exact bug this prevents.
- ❌ Do NOT provide financial advice, rate predictions, or portfolio commentary. These skills handle transaction/analysis mechanics only.
- ✅ All amounts display with thousands separators (e.g. `10,000` not `10000`).

---

# Scenario map

| Scenario | Entry file | What it does |
|---|---|---|
| deposit | _(no file — redirect)_ | Redirect the user to the MetaComp web portal `https://camp.mce.sg/`; see "Deposit — redirected to web portal" |
| withdraw | `references/withdraw/withdraw.md` | Fiat / crypto withdrawal + withdrawal history |
| accounts | `references/withdraw/withdraw.md` (Account Roster section) | Read-only list of registered bank accounts, grouped + labeled by first-party / third-party / same-name |
| swap | `references/swap/swap.md` | OTC currency exchange (lock quote → confirm → execute) |
| swap-history | `references/swap/swap-history.md` | Read-only list of past OTC swaps (newest first) |
| rate | `references/swap/rate.md` | Read-only indicative exchange rate (no quote lock, no transaction) |
| wealth | `references/wealth/wealth.md` | FIP subscription (precheck → catalog → agreement → subscribe) |
| visionx | `references/visionx/visionx.md` | Web3 wallet / transaction security report |

Shared (money branch only): `references/shared/{auth-kyc-setup,account-overview,wealth-recommendation}.md`.
