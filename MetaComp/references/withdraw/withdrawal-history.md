# Withdrawal History — Query past withdrawals

## When to enter this sub-skill

Triggered from `SKILL.md` routing when the user asks:

- 「我刚才那笔出金到账了吗 / Did my withdrawal go through?」
- 「查我最近的出金记录 / Show my withdrawal history」
- 「上周的提现状态 / status of last week's withdrawal」
- 「我有几笔挂着的出金 / pending withdrawals」

This sub-skill is **read-only**. It does NOT initiate any withdrawal — see `fiat-withdrawal.md` / `crypto-withdrawal.md` for initiation flows.

## STEP 1 — Type filter is OPTIONAL (default: all types)

Do **NOT** ask "fiat or crypto?" by default. The query returns BOTH fiat and crypto withdrawals when no type is specified — that is the desired default for "show my withdrawals / 出金记录".

Only set `payeeAccountType` when the user has **explicitly** scoped the request to one type, or it is unambiguous from context:

- fiat / bank / SWIFT / 银行 → `payeeAccountType=1`
- crypto / on-chain / wallet / 链上 → `payeeAccountType=2`

If the user just initiated a withdrawal of a known type earlier in the same conversation and is now asking "did it go through?", you may infer that type. Otherwise, **omit `payeeAccountType` entirely** and show all withdrawals.

## STEP 2 — Call `get_withdrawal_list`

Default invocation — pass nothing and rely on server defaults:

- `pageNum` — optional, server default `1`. Omit unless paging.
- `pageSize` — optional, server default `5` (small page; show the user, then offer "more"). Omit to get 5.
- `payeeAccountType` — **optional**. Omit to return BOTH fiat and crypto. Set 1 / 2 only per STEP 1.
- `startTime` / `endTime` — only if the user mentioned a time window (format: `"YYYY-MM-DD HH:mm:ss"`, e.g. `"2026-04-01 00:00:00"`).

So a bare "show my withdrawals" is simply `get_withdrawal_list()` (no arguments).

## STEP 3 — Render results to the user

Because results may now mix fiat and crypto, **lead each record with a type label** derived from the record's own `payeeAccountType` field: `1` → `[法币 / Fiat]`, `2` → `[加密 / Crypto]`.

Then, for each record, show in this priority order:

1. **type label** — `[法币 / Fiat]` or `[加密 / Crypto]` from `payeeAccountType`
2. **paymentCode** — the user's reference (e.g. `WD2026042709550001`)
3. **createAt** — formatted as local time
4. **statusDesc** — the authoritative status label (always present). Render it **only** from `statusDesc`, mapped to the user's language: `processing` → 处理中 / Processing; `completed` → 已完成 / Completed; `rejected` → 已拒绝 / Rejected; `cancel` → 已取消 / Cancelled. Do NOT display the raw numeric `status` code, and do NOT invent any other state (there is no "审核中 / under review" — anything not completed/rejected/cancel is `processing`).
5. **currency** + **totalAmount** — display = `totalAmount / 10^decimals`. Use the currency decimals from the product base list.
6. **receiveAmount** (what the payee actually receives) and **totalChargeAmount** (fees) — both in display units (minor → display)
7. **purposeOfTransaction** — only when `paymentType === 22` (third-party). Skip for `paymentType === 21`.
8. **pathTo** (e.g. `"BANK"`) if non-null — clarifies the routing destination

Don't dump every raw field. Don't expose `poboInfo` internals, `proof`, or `fileRef` even if present in the tool output.

## STEP 4 — Pagination

If user asks for more, increment `pageNum`. If they ask for a specific `paymentCode` not on the current page, advise them to widen the time window or scroll pages. There is no server-side single-record lookup.

## Edge cases

- **Empty list** → "您当前没有出金记录 / No withdrawals on file." (Do not assume a single type — the default query spans both fiat and crypto.)
- **API error / 5xx** → surface a short apology and the request id; do NOT silently retry more than once.
- **Numeric fields:**
  - `fee`, `feeRate`, `additionalCharge` come as **strings** (treat as decimal strings).
  - `totalAmount`, `receiveAmount`, `chargeAmount`, `totalChargeAmount`, `deductibleAmount` come as **numbers in minor units**.
  - Always divide by `10^decimals` before displaying.
- **paymentType 21 vs 22:** only third-party records carry meaningful `purposeOfTransaction`; first-party is internal. Don't display `purposeOfTransaction` for `paymentType === 21`.

## Pitfalls

- ❌ Do NOT ask "fiat or crypto?" up front — the default is to query ALL types. Only filter by `payeeAccountType` when the user explicitly scoped it.
- ❌ Do NOT confuse `payerAccountType` (user side) with `payeeAccountType` (the optional filter field, also the per-record type label) — use `payeeAccountType` both to scope the query and to label each row.
- ❌ Do NOT read the raw numeric `status` code and label it yourself (it must never surface as "审核中 / under review" or any custom text). The server already collapses status into `statusDesc`; render only that, mapped per STEP 3.4.
- ❌ Do NOT call `get_deposit_list` for withdrawal queries — they are separate tools, separate endpoints.
- ❌ Do NOT show raw minor-unit amounts to the user — always convert via decimals first.
- ❌ Do NOT expose `poboInfo` internals, `proof`, or `fileRef` to the user.
