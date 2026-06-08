# Wealth Subscription Confirmation & Result Specification

This sub-skill defines the agreement + confirmation page (STEP 5), the success / failure / cancellation messages (STEP 6).

> **Token Guard applies to every MCP call referenced by this file.** After each tool call, check the response for `success: false` with `authPageUrl` FIRST. If detected → follow the **Token Guard** rule in SKILL.md Absolute Rules (stop flow, show login link, HARD STOP). Do NOT fall through to step-specific error handling.

All templates below are **canonical in Chinese**. Render in the user's conversation language per wealth.md LANGUAGE CONTRACT. When translating to English (or another language), translate headers / labels / prose but keep these items byte-for-byte:

- **VERBATIM — the STEP 5 confirmation phrase shell:** `I have read and agree to 「{show_name}」 & 「{show_name}」 & ...` — fixed English, never translated. Connectors (`I have read and agree to`, ` & `) and corner brackets `「」` are fixed. Only `{show_name}` slots are substituted, from `agreements[].show_name` in the `get_fip_agreement` response, also verbatim (no translation, no case normalization).
- **VERBATIM — server-returned strings:** `variant.term` (`Flexible`, `30 Days`, `90 Days`), `variant.estApr` (`10.00%`), `variant.liquidity` (`(T + 3 Settlement)`), `variant.mhp` (`Minimum Holding Period: 14 Days`), `productName`, `productCode`, `productType`, `agreements[].show_name`, `agreements[].url`, any server error message, any `tradeCode` / reference ID / timestamp.

Translation key (common row labels): `产品` → `Product`, `币种` → `Currency`, `期限` → `Term`, `年化` → `APY`, `结算` → `Liquidity`, `最短持有` → `Minimum holding period`, `认购金额` → `Subscription amount`, `认购摘要` → `Subscription Summary`, `认购协议` → `Subscription Agreement`, `认购成功` → `Subscription Successful`, `认购失败` → `Subscription Failed`, `原因` → `Reason`, `参考编号` → `Reference`, `时间` → `Time`.

---

## STEP 5 — Agreement & Confirmation Page

Display after `get_fip_agreement` returns and before `fip_subscribe` is called.

**Order:** summary table → agreement link list → confirmation instruction.

`get_fip_agreement` returns `agreements[]`, each with `show_name`, `url`, `sort`. Render the list sorted by `sort` ascending. Do NOT attempt to fetch or paste the PDF contents — show the clickable link with the `show_name` as the link text.

```
**认购摘要**

| | |
|---|---|
| 产品 | {productName}（{productType} / {productCode}） |
| 币种 | {currency} |
| 期限 | {variant.term} |
| 年化 | {variant.estApr} |
| 结算 | {variant.liquidity} |
| 最短持有 | {variant.mhp 或 "—"} |
| 认购金额 | {subscriptionAmount} {currency} |

---

**请阅读以下协议**

按 get_fip_agreement 返回的 `agreements[]` 顺序（`sort` 升序）渲染为可点击链接：

- [{show_name_1}]({url_1})
- [{show_name_2}]({url_2})
- ...

---

请回复以下**完全一致**的英文内容以继续（此短语为 VERBATIM，不得翻译；`show_name` 来自本次 get_fip_agreement 返回，按 `sort` 顺序用「」包裹并以 & 连接）：

**I have read and agree to 「{show_name_1}」 & 「{show_name_2}」 ...**

（示例：上面协议列表里有 `Master Note Agreement` 和 `Note Certificate Schedule 2 Open Term (T+3)`，则短语为 `I have read and agree to 「Master Note Agreement」 & 「Note Certificate Schedule 2 Open Term (T+3)」`。）

任何其他回复都将取消本次认购。
```

### Forbidden STEP 5 renderings (any of these = defect, regenerate)

- A summary table without the agreement link list below it.
- A prompt ending in "Do you confirm this subscription?" / "确认认购?" / "确认本次认购?" / a thumbs-up · thumbs-down question.
- Accepting "yes" / "y" / "ok" / "是" / "好的" / "确认" / "同意" / 👍 / emoji in reply — the ONLY acceptance path is the exact `I have read and agree to 「…」 & 「…」` phrase built from `agreements[].show_name`.
- Rendering a summary with English column labels like `Product / Currency / Amount / APY / Term / Settlement` and NO agreement list + VERBATIM instruction. If your draft looks like that, you have left the template — restart from the `认购摘要` block above.
- Omitting the VERBATIM instruction in Chinese conversations "because the user speaks Chinese." The phrase stays fixed English regardless of conversation language — only surrounding prose is localized.

### Variable mapping

| Variable | Source |
|---|---|
| `productName` / `productType` / `productCode` | `get_fip_products` product-level |
| `currency` / `variant.term` / `variant.estApr` / `variant.liquidity` / `variant.mhp` | chosen `currencyItemList[j]` variant. Never show `termDays` directly — it may be `-1`/`-2`. `estApr` already contains `%`. |
| `subscriptionAmount` | user-supplied, validated in wealth.md STEP 4, displayed with thousands separators |
| `{show_name}` / `{url}` in agreement list + confirmation phrase | `get_fip_agreement.agreements[]` sorted by `sort` ascending. Use `show_name` as both the link text and the phrase slot; use `url` as the link target. |
| estimated return | ⚠ NOT derivable (product-level `estApr` may be a range; `termDays` negative for open-term). Omit the row entirely — do not guess. |

### Rules

- `subscriptionAmount` displayed with thousands separators (e.g. `10,000 USDC`); passed to `fip_subscribe` as plain string (`"10000"`).
- Agreement list rendered as Markdown links, one per `agreements[]` entry, sorted by `sort` ascending. Use `show_name` as link text, `url` as link target. Do NOT fetch, summarize, or paste PDF contents — just link to it.
- Confirmation phrase is built dynamically from `agreements[].show_name`, ordered by `sort`. Fixed English VERBATIM regardless of conversation language. Connectors (`I have read and agree to`, ` & `) and brackets `「」` are fixed; only `show_name` is substituted (verbatim from server, no translation, no case normalization).
- If `get_fip_agreement.agreements` is empty or missing, abort: output "无法获取协议信息，请稍后重试" (or its translation per LANGUAGE CONTRACT) and STOP. Never construct an empty-name confirmation phrase.
- Do NOT offer a "Yes / No" shortcut. The exact phrase is the only acceptance path.

### Pre-execution checklist (runs before `fip_subscribe` is called)

1. The user's latest message contains the literal substring `I have read and agree to 「`.
2. The `{show_name}` slots, in order, match the phrase rendered in the STEP 5 ask (built from the current `get_fip_agreement.agreements[]`, sorted by `sort`).
3. Casing is preserved for the fixed `I have read and agree to` and ` & ` portions; whitespace and half-width vs full-width brackets are tolerated.

Any check failing → output the cancellation message (below) and STOP. Do NOT re-prompt, do NOT auto-correct the user's reply, do NOT "interpret intent", do NOT proceed to `fip_subscribe`. The rule is substring-first, not intent-first.

---

## STEP 6 — Success Message

Display when `fip_subscribe` returns `success: true`.

```
✅ **认购成功**

| | |
|---|---|
| 产品 | {productName} |
| 币种 | {currency} |
| 期限 | {variant.term} |
| 认购金额 | {subscriptionAmount} {currency} |
| 年化 | {variant.estApr} |
| 参考编号 | {tradeCode 或响应中的认购编号} |
| 时间 | {响应中的时间，如有} |
```

### Rules

- The reference ID is the user's receipt — always displayed. Use whichever field the server returns (`tradeCode`, `subscriptionId`, `orderId`, etc.).
- Only fields actually present in the response are shown. Do not fabricate timestamps, maturity dates, or final rates.

---

## STEP 6 — Failure Message

Display when `fip_subscribe` returns `success: false`.

```
❌ **认购失败**

**原因：** {error_message}

{根据错误类型给出建议}
```

### Error-specific suggestions (canonical Chinese; translate for English users)

| Error type | Suggestion (中文 canonical) |
|---|---|
| 余额不足 Insufficient balance | "请先为 {currency} 账户充值后再试。" |
| 产品售罄 / 额度耗尽 Product sold out | "该产品当前已不可认购，是否换一款？" |
| 金额低于起购 / 无效 Amount invalid | "请调整金额后重试。" |
| 会话过期 Session expired | 展示 `authPageUrl` 登录链接（同 Token Guard，见 SKILL.md）。 |
| 资格变化 Eligibility changed | "您的认购资格可能已发生变化，请重新开始流程。" |
| 其他 / 未知 Unknown | "请稍后重试。如问题持续，请联系 metacomp.ai 客服。" |

### Rules

- Never expose raw error codes or stack traces.
- Map server error codes to user-friendly messages.
- Do NOT automatically retry `fip_subscribe` — the user must restart the flow.

---

## Cancellation Message

Display when the user replies with anything other than the exact confirmation phrase in STEP 5.

```
认购已取消，账户未发生任何变动。
```

### Rules

- Output once and STOP. Do not re-prompt for the phrase.
- To subscribe later, the user must re-trigger the skill from scratch — do not resume mid-flow from cached state.
