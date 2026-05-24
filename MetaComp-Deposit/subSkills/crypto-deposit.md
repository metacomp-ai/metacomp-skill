# Crypto Deposit Flow

This sub-skill defines the flow for depositing cryptocurrency into the user's MetaComp account.

> **Token Guard applies to every MCP call in this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

---

## STEP 1 — Resolve Currency (bypass when already known)

**Normal entry path:** SKILL.md STEP 2 has already presented the unified currency list and the user selected a cryptocurrency. SKILL.md routes directly into STEP 2 of this file with `currency = <user's choice>` (used as `{coin}` in the steps below). **Skip this STEP 1 entirely.**

**Defensive entry path:** Only if this sub-skill is somehow entered without a known `currency` (edge case — not the normal flow), execute the fallback below:

Call `get_crypto_deposit_currencies`.

### Case A — Empty list

> No crypto currencies are currently available for deposit. Please contact MetaComp support.

⛔ **STOP.**

### Case B — At least one currency

> What cryptocurrency would you like to receive?

Display the full currency list. ⛔ **STOP.** Wait for the user to choose (e.g. USDT), then proceed to STEP 2.

---

## STEP 2 — Ask Network

Call `get_crypto_deposit_networks(currency)`.

### Case A — Empty list

> No networks are currently available for **{coin}**. Please contact MetaComp support.

⛔ **STOP.**

### Case B — At least one network

> You want to receive **{coin}**. Please select a network:

Display the full network list. ⛔ **STOP.** Wait for the user to choose.

---

## STEP 3a — Get Wallet Address (silent — no output)

Call `get_crypto_wallet_addresses(network)`. Parse the response and extract `walletAddress` from `structuredContent.addresses[]`.

**Do NOT output anything to the user yet.** Proceed immediately to STEP 3b.

---

## STEP 3b — Present Address (chat) + QR Artifact

> ⛔ **OUTPUT CONTRACT — READ THIS BEFORE ANY OUTPUT**
>
> **Sequence is fixed:**
> 1. **FIRST (chat text):** a short message containing the **actual wallet address string** from the tool response, wrapped in inline-code backticks on its own line. The user copies from this line.
> 2. **SECOND (Artifact):** the HTML Artifact carrying the QR code, emitted immediately after the chat message.
>
> **Substitution check (MANDATORY before sending Part 1):** `{walletAddress}`, `{coin}`, `{network}` MUST be replaced with the actual values from the tool response. If any placeholder remains, or the value would be empty / `null` / `undefined` → **STOP**, do not send; either re-read STEP 3a's tool output or fall through to the QR Fallback branch. Never send a template with a missing / empty variable.
>
> **No raw HTML in chat:** chat text MUST NOT contain `<!DOCTYPE`, `<html`, `<script`, `<div`, `<style`, `<body`, `<head`, or any HTML tag opener. HTML lives only inside the Artifact. Chat emphasis is Markdown only — backticks for the address, `**bold**` for the network name.
>
> **Render target** (location-neutral): the address and QR live **inside the chat conversation body**. Never direct the user to a panel, sidebar, or any specific screen region.
>
> **FORBIDDEN phrasings (non-exhaustive — the *intent* is blocked, not only these exact strings):**
> - English: `artifact panel`, `on the right`, `right panel`, `right-hand panel`, `right side`, `right-side panel`, `side panel`, `sidebar`, `the panel`, `see the panel`, `check the panel`, `open the panel`, `in the panel on the right`, `in the sidebar`
> - Chinese: `右侧面板`, `右边栏`, `右侧`, `右边`, `右方`, `右手边`, `侧边栏`, `边栏`, `侧栏`, `旁边的面板`, `右侧的面板`, `请查看右侧`, `请看右侧`, `右侧二维码`, `右侧生成`, `右边显示`, `右侧显示`
>
> **ALLOWED phrasings** (location-neutral, referring to the conversation itself):
> - English: `above`, `below`, `here`, `in this message`, `the QR code below`, `scan the QR code`
> - Chinese: `上方`, `下方`, `此处`, `以下`, `本条消息中`, `扫描下方二维码`, `扫描二维码`

### Part 1 — Address message in chat (FIRST, PRIMARY)

Output the message below. The wallet address MUST appear as the actual string from `structuredContent.addresses[].walletAddress`, rendered inside inline-code backticks on its own line.

**English:**

> Here is your **{coin}** receiving address on **{network}**:
>
> `{walletAddress}`
>
> You can copy the address above or scan the QR code shown next. ⚠ Please make sure the sender selects the correct network (**{network}**) — sending via the wrong network may result in permanent loss of funds.

**Chinese:**

> 这是您的 **{coin}** 收款地址（**{network}** 网络）：
>
> `{walletAddress}`
>
> 您可以复制上方地址，也可以扫描下方二维码。⚠ 请确保汇款方选择正确的网络（**{network}**），使用错误网络可能导致资金永久损失。

Pick exactly one language version per the turn's dominant language (see SKILL.md language rule). Never emit both.

### Part 2 — QR Artifact (SECOND, visual augmentation)

Immediately after Part 1 is emitted, create an **Artifact** (HTML type) to render the QR code. The Artifact sandbox displays it as an image — the user never sees the raw HTML.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{coin} Deposit Address</title>
<script src="https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; display: flex; justify-content: center; padding: 24px; }
  .card { background: #fff; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); padding: 32px; max-width: 420px; width: 100%; text-align: center; }
  .title { font-size: 18px; font-weight: 600; color: #1a1a1a; margin-bottom: 4px; }
  .network-badge { display: inline-block; background: #e8f5e9; color: #2e7d32; font-size: 13px; font-weight: 500; padding: 3px 10px; border-radius: 12px; margin-bottom: 20px; }
  .qr-container { background: #fff; border: 1px solid #eee; border-radius: 8px; padding: 16px; display: inline-block; margin-bottom: 20px; }
  .qr-container svg { display: block; }
  .address-label { font-size: 12px; color: #888; margin-bottom: 6px; }
  .address { font-family: 'SF Mono', 'Fira Code', monospace; font-size: 13px; color: #333; word-break: break-all; background: #f5f5f5; padding: 12px; border-radius: 8px; line-height: 1.5; user-select: all; cursor: pointer; }
  .warning { margin-top: 20px; padding: 12px; background: #fff3e0; border-radius: 8px; font-size: 13px; color: #e65100; line-height: 1.5; text-align: left; }
  .warning::before { content: "⚠ "; }
</style>
</head>
<body>
<div class="card">
  <div class="title">{coin} Deposit Address</div>
  <div class="network-badge">{network}</div>
  <div class="qr-container" id="qrcode"></div>
  <div class="address-label">Wallet Address (click to select)</div>
  <div class="address">{walletAddress}</div>
  <div class="warning">Please make sure the sender selects the correct network ({network}). Sending via the wrong network may result in permanent loss of funds.</div>
</div>
<script>
  var qr = qrcode(0, 'M');
  qr.addData('{walletAddress}');
  qr.make();
  document.getElementById('qrcode').innerHTML = qr.createSvgTag(6, 0);
</script>
</body>
</html>
```

**Artifact rules:**
- Artifact title: `{coin} Deposit - {network}`
- Type: `text/html`
- Replace `{walletAddress}`, `{coin}`, `{network}` with actual values from the tool response
- `{walletAddress}` appears in THREE places: the `qr.addData()` call, the `.address` div, and the `<title>`
- If multiple addresses are returned, include all of them in the same artifact (duplicate the `.card` div, each with its own `<script>` block and unique `id`)
- Do NOT use `data:` URLs — the artifact sandbox blocks them
- Do NOT use `<img src>` for the QR — use the JS-generated SVG

### QR Fallback (when address is missing or unavailable)

If `walletAddress` is empty, `null`, missing, or the tool returned an error, do **not** print the Part 1 template and do **not** create an Artifact. Instead output:

- English: *"No wallet address available for this network right now. Please try again in a moment or contact MetaComp support."*
- Chinese: *"该网络暂时无法获取收款地址，请稍后再试，或联系 MetaComp 客服。"*

### ⛔ STEP 3b Completion Check (silent, mandatory before STEP 4)

Before proceeding to STEP 4, verify:

- (a) **Address substring present** — does the Part 1 chat text contain a concrete wallet address string (not `{walletAddress}`, not empty, not `null`)? If NO → substitution failed, do not send; fix or fall through to QR Fallback.
- (b) **Artifact produced** — if address was non-empty, was Part 2 Artifact created? If NO → create it now.
- (c) **No HTML leak** — does any chat output contain a raw HTML tag (`<!DOCTYPE`, `<html`, `<script`, `<div`, `<style`, `<body`, `<head`, etc.)? If YES → remove from chat and ensure it lives only inside the Artifact.
- (d) **Location-neutral** — any FORBIDDEN positional phrasing OR directional word (right/left/side/panel/sidebar/面板/边/侧) in chat text? If YES → rewrite with ALLOWED phrasing before sending.

---

## STEP 4 — Wait for Transfer

After displaying wallet info, the conversation pauses. The user will come back when the sender has initiated the transfer.

Typical user message: "帮我看看钱转到了吗", "Has the transfer arrived?", "Check my balance"

---

## STEP 5 — Verify Transfer via Deposit List

Call `get_deposit_list(pageNum=1, pageSize=5, payeeAccountType=2)` — `payeeAccountType=2` is fixed because this sub-skill handles crypto deposits.

### Case A — Empty list

> No recent crypto deposits found. Please confirm the sender has initiated the transfer, then let me know when to check again.

⛔ **STOP.** Wait for the user.

### Case B — At least one record

Render the most recent 5 records (the response is already newest-first):

### English

```
Here are your most recent crypto deposits:

| # | Payment Code | Coin | Amount | Status | Network | TX Hash | Time |
|---|---|---|---|---|---|---|---|
| 1 | {paymentCode} | {currency} | {amount_display} | {status_display} | {payerSettleName} | {tx_hash_short} | {createAt_local} |

Which one is your transfer? I'll check its status and generate the KYT report.
```

### Chinese

```
以下是您最近的数币入金记录：

| # | Payment Code | 币种 | 金额 | 状态 | 网络 | TX Hash | 时间 |
|---|---|---|---|---|---|---|---|
| 1 | {paymentCode} | {currency} | {amount_display} | {status_display} | {payerSettleName} | {tx_hash_short} | {createAt_local} |

请告诉我哪一条是您本次的入金，我会为您查看状态并生成 KYT 报告。
```

### Display Rules

- `amount_display = totalAmount / 10^decimals`, with thousands separators. Decimal places come from the currency's product base list.
- `status_display`: use `statusDesc` if non-null; otherwise map the `status` code using the table below.
- `tx_hash_short` = first 10 chars + "..." + last 6 chars of `detail`; keep the full hash internally for STEP 6.
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

- If `status === 7` (Completed) → proceed to STEP 6 with `tx_hash = selected.detail ?? selected.coboInfo?.txHash`.
- If category is `failed` (`status` 8, 9, 20) → show the status label and explain the deposit was not successful.
- If category is `jailed` or `refunded` (`status` 17, 18, 19) → show the status label and advise contacting MetaComp support.
- Otherwise (all `pending` statuses) → show the "Transfer Pending" template below.

### Transfer Pending — English

```
⏳ **Transfer Pending**

Your transfer has not been confirmed yet. Blockchain confirmations may take some time depending on the network.

| Network | Typical Confirmation Time |
|---------|--------------------------|
| ETH     | ~5 minutes               |
| TRON    | ~3 minutes               |
| SOL     | ~1 minute                |
| BSC     | ~3 minutes               |

Would you like me to check again later?
```

### Transfer Pending — Chinese

```
⏳ **转账确认中**

您的转账尚未确认。区块链确认时间因网络而异。

| 网络 | 预计确认时间 |
|------|------------|
| ETH  | 约 5 分钟   |
| TRON | 约 3 分钟   |
| SOL  | 约 1 分钟   |
| BSC  | 约 3 分钟   |

需要我稍后再为您查询吗？
```

---

## STEP 6 — KYT (Know Your Transaction) Security Check

After the transfer is confirmed (status === 7), perform a KYT check using the VisionX tools. This step uses `get_transaction_security` and `get_wallet_security` from the **metacomp-mcp** server (same tools as the `MetaComp-VisionX` skill).

### 6a — Extract fields from deposit record

From the deposit record selected in STEP 5, extract:

| KYT field | Source | Notes |
|-----------|--------|-------|
| `hash` | `selected.detail ?? selected.coboInfo?.txHash` | On-chain tx hash |
| `network` | Map `payerSettleName` to KYT format (see table below) | |
| `asset` | `currency` | e.g. USDT, USDC, BTC |
| `direction` | Always `"received"` | This is a deposit |
| `from` | `payerSettleAccount` | Sender's wallet address |
| `to` | `payeeSettleAccount` OR the wallet address from STEP 3a | User's deposit address |

#### Network mapping

| Deposit record (`payerSettleName`) | KYT (`network`) |
|------------------------------------|------------------|
| ETH, ERC20, ARBITRUM, OPTIMISM, BASE | `Ethereum` |
| BTC, BITCOIN | `Bitcoin` |
| TRX, TRON, TRC20 | `Tron` |
| Other | Skip KYT — unsupported network |

### 6b — Skip conditions

If ANY of these are true, skip KYT entirely and show a message:

- `hash` is null/empty → "No on-chain transaction hash available for this deposit. KYT check skipped."
- `from` is null/empty → "Sender address not available. KYT check skipped."
- Network is unsupported → "KYT is only supported for Ethereum, Bitcoin, and Tron networks. This deposit was on {payerSettleName}."

### 6c — Call KYT tools (in parallel)

If all fields are available, call **both tools in parallel**:

1. `get_transaction_security({ network, transactionDetails: [{ hash, asset, direction: "received", from, to }] })`
2. `get_wallet_security({ network, walletAddress: from })` — check the **sender's** wallet

### 6d — Display results

Follow the output format defined in the **`MetaComp-VisionX`** skill:

1. **Transaction Security Report** — from `get_transaction_security` response:
   - Transaction info table (date, direction, asset, amount, USD value, from, to)
   - Risk level with color indicator (🟢 Low / 🟡 Medium / 🟠 Medium-High / 🔴 High)
   - Risk Sources table (type, ratio, interpretation)
   - Comprehensive Summary (4-5 sentences)

2. **Sender Wallet Report** — from `get_wallet_security` response:
   - Skip the Analysis Preface (since `get_transaction_security` was already called)
   - Wallet metrics + risk exposure (follow `wallet-report.md` Steps ②–⑦)

### 6e — Error handling

- Token Guard applies — check `success: false` with `authPageUrl` first
- `get_transaction_security` fails → show error, still attempt `get_wallet_security`
- `get_wallet_security` fails → show error, transaction report alone is still useful
- Both fail → "KYT check could not be completed. Please try again later or check manually at metacomp.ai."

---

## Display Rules

- All wallet addresses, TX hashes, and amounts come directly from the API — do NOT fabricate
- **QR code display:** Always create an HTML Artifact that generates the QR code client-side via `qrcode-generator` JS library from the wallet address string. Do NOT use `data:` URLs (sandbox blocks them). Do NOT use `<img src>` for QR. Do NOT output QR in chat markdown. See STEP 3.
- Network warning is **mandatory** in STEP 3
- All amounts with thousands separators where applicable
- TX hash displayed truncated in tables; use the full hash for KYT calls
- **KYT vendor confidentiality:** Do NOT name specific vendors (Beosin, Elliptic, etc.) outside of the Analysis Preface. Use "multiple vendors", "cross-vendor consensus" in all other sections.

---

## Tool Reference

### `get_crypto_deposit_currencies`
```json
{}
```
Returns: `{ currencies: string[] }` — crypto currency codes the user can deposit.

### `get_crypto_deposit_networks`
```json
{ "currency": "USDT" }
```
Returns: `{ networks: string[] }` — supported blockchain networks for the chosen currency.

### `get_crypto_wallet_addresses`
```json
{ "network": "ERC20" }
```
Returns: `{ addresses: Array<{ walletAddress: string, qrCodeDataUrl: string }> }`. The QR code is delivered as an MCP `image` block in the tool response (rendered by the host automatically). Do NOT embed `qrCodeDataUrl` via Markdown `![](...)` — Claude Web blocks `data:` URLs.

### `get_deposit_list`
```json
{ "pageNum": 1, "pageSize": 5, "payeeAccountType": 2 }
```
Returns paginated deposit records (newest first). Key fields for KYT: `detail` (tx hash), `payerSettleAccount` (sender address), `payeeSettleAccount` (receiver address), `payerSettleName` (network), `currency`. Amounts are in minor units.

### `get_transaction_security`
```json
{
  "network": "Ethereum",
  "transactionDetails": [{
    "hash": "0x...",
    "asset": "USDT",
    "direction": "received",
    "from": "0xSenderAddress...",
    "to": "0xYourAddress..."
  }]
}
```
Returns transaction risk assessment including risk level, risk sources, and taint ratios. From the **metacomp-mcp** server.

### `get_wallet_security`
```json
{ "network": "Ethereum", "walletAddress": "0xSenderAddress..." }
```
Returns wallet risk assessment including risk scores, exposure breakdown, and cross-vendor analysis. From the **metacomp-mcp** server.
