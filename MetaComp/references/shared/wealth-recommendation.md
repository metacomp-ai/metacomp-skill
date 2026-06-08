# Wealth Product Recommendation (Mandatory Evaluation, Non-blocking Render)

This file is referenced by the **deposit**, **withdraw**, and **swap** scenarios. It defines a **mandatory evaluation** that runs after every Account Overview render (deposit / withdraw) or at the swap scenario's STEP 3C no-intent reply. When the trigger evaluates TRUE, a recommendation block is rendered; when FALSE, nothing is rendered — but the **evaluation itself always happens**.

**Two different things, do not conflate them:**
- **Evaluation** (internal decision) → **mandatory**, always runs, never skippable.
- **Render** (the visible block) → **non-blocking**, appended content that never halts the primary flow; absent when evaluation returns FALSE.

Skipping the evaluation is a rule violation under the **Wealth Evaluation Gate** (see SKILL.md → Absolute Rules).

**Scope:** Used by the deposit / withdraw / swap scenarios. Never used by the **wealth** scenario (it IS the wealth flow).

---

## Trigger Condition: WEALTH_RECOMMENDATION_TRIGGER

The recommendation fires when **ALL** of the following are true:

1. Account Overview has been successfully displayed in the current response
2. The current scenario is NOT **wealth**
3. The recommendation has NOT already been shown in this conversation (one per conversation)
4. At least one account has `availableAmount > 0` (no point recommending to a user with no funds)
5. At least ONE of the following facts is true. Evaluate **in order 5a → 5b → 5c**; if any earlier clause fires, stop — condition 5 is satisfied.

   **5a. View-Only Mode has been entered (deterministic, highest priority).**
   - Deposit / Withdraw: STEP 1 Case C detected that the original trigger message contained asset-viewing keywords (e.g. "check balance", "查看资产", "看看余额", "check my asset status", "我的资产", "账户概览") without any deposit/withdraw/swap keywords, so the flow is in View-Only Mode.
   - Swap: at STEP 3C, the user's reply contains no currency, no amount, no exchange direction (i.e. the reply is a balance-curiosity / abandonment / exploration message).
   - **When 5a holds, condition 5 is automatically TRUE. Do NOT re-interpret the user's intent; the flow state already gives the answer.**

   **5b. The original skill-triggering message literally contains any of these substrings (case-insensitive, verbatim match — no paraphrasing).**
   - `查看余额` · `看看余额` · `看看资产` · `查看资产` · `我的资产` · `账户情况` · `账户余额` · `账户概览`
   - `check balance` · `check my balance` · `check my account` · `check my asset` · `check my asset status` · `view my assets` · `what's my balance` · `my balance` · `my assets` · `account overview`

   **5c. The original triggering message expresses flow abandonment or open exploration.** (This clause still involves judgment — use it only if 5a and 5b both fail.)
   - **Flow abandonment:** "算了", "不提了", "不换了", "不充了", "never mind", "I changed my mind", "cancel", "just looking", "我就看看"
   - **Open exploration:** "还有什么可以做的", "what else can I do", "any suggestions", "有什么推荐"
   - **Topic deviation:** user asks about something unrelated to the current scenario's main action

If the original triggering message contains a **clear business intent** (specific currency + amount + fiat/crypto choice or swap direction) AND none of 5a/5b/5c fire, the trigger evaluates to FALSE — skip the render and proceed with the normal flow. **Note: even in this case, the evaluation itself still happened; you just decided the answer was FALSE.**

> ⚠️ **Resumed-flow note:** If the flow was interrupted mid-execution (e.g. Token Guard session expiry) and the user resumed with a continuation phrase like "go on" / "continue" / "继续" / "已登录" / "I've logged in", evaluate condition 5 against the **original triggering intent**, NOT the continuation reply. A continuation reply is a flow-control signal, not a new intent — it neither satisfies nor cancels any sub-clause.

---

## MCP Call Sequence

When WEALTH_RECOMMENDATION_TRIGGER is TRUE:

### Step 1 — Eligibility check

Call `investor_precheck` (no parameters).

**Token Guard exception:** If `investor_precheck` returns `success: false` with `authPageUrl`, **silently skip the entire recommendation**. Do NOT show a login link, do NOT interrupt the primary flow. This is the only context where Token Guard errors are swallowed — the recommendation is advisory and must never disrupt the user's current flow.

### Step 2 — Branch on result

- **All values `true`** → proceed to Step 3 (rich recommendation)
- **Any value `false`** → render the **DATA-BOUND Generic Teaser** below, listing the exact `false` items, then return to the primary flow
- **Error / Token Guard / `investor_precheck` was NOT called this turn** → render NOTHING (silent skip), return to the primary flow

> ⛔ There is exactly ONE no-render path and ONE teaser path: teaser requires a real `investor_precheck` result with ≥1 `false` item. If you cannot point to such a result this turn, the only legal outcome is **silent skip** — never a teaser "by default".

### Step 3 — Fetch product summary

Call `get_fip_products` (no parameters).

- **Token Guard error** → silently skip, return to primary flow
- **Empty `data` or all products have empty `currencyItemList`** → skip recommendation, return to primary flow
- **Success** → render the **Rich Recommendation** template below, then return to the primary flow

---

## Rich Recommendation Template (precheck passed, products available)

When the trigger fires AND `investor_precheck` returns all true AND `get_fip_products` returns non-empty `data`, render the **full product catalog** in the same format used by the wealth scenario. The canonical spec is in `../wealth/product-display.md`; the recommendation reuses that format **verbatim**, with one adaptation to the closing line (CTA references the user's actual holdings).

### Format summary (must match ../wealth/product-display.md)

- Iterate over `data[]` ordered by `sort` ascending. For each product, render one section.
- **Section heading:** `### {productName}（{productType} / {productCode}）`
- **Sub-line below heading:** 
  - CN: `产品综合年化：{product.estApr}`
  - EN: `Product-level APY: {product.estApr}`
- **Variant table** from `currencyItemList[]`:
  - **Fixed-term** (`product.termType === 2`, e.g. FIP_30Days/60Days/90Days) → **6 columns**, no MHP:
    `# | 币种 | 期限 | 年化 | 起购 | 结算`
  - **Open-term** (`product.termType === 1`, e.g. FIP_OpenTerm_T+1) → **7 columns**, with MHP:
    `# | 币种 | 期限 | 年化 | 起购 | 结算 | 最短持有`
- **Per-currency `起购 / Min` defaults:** USD/USDT/USDC → `10,000`; BTC → `1`; ETH → `10`
- **Term column:** use variant's `term` string; for fixed-term, localize per language (CN `30 天`/`60 天`/`90 天`, EN `30 Days`/`60 Days`/`90 Days`); for open-term, keep `Flexible` as-is in all languages.
- **APY column:** variant's `estApr` verbatim (already contains `%`).
- **Settlement column:** variant's `liquidity` verbatim (e.g. `(T + 1 Settlement)`).
- **MHP column** (open-term only): variant's `mhp` verbatim; empty → `—`.
- **Row numbering** (`#`) is local to each product table, starting at 1.
- **Do NOT** render any 💡 / 标语 header above the catalog. The product tables ARE the recommendation. No transition sentence is needed.

### Canonical example (Chinese — fixed-term)

```
### Fixed Income Products - 30 Days（FIP / FIP_30Days）

产品综合年化：10.00%

| # | 币种 | 期限 | 年化 | 起购 | 结算 |
|---|------|------|------|------|------|
| 1 | USD  | 30 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 2 | USDT | 30 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 3 | USDC | 30 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 4 | BTC  | 30 天 | 10.00% | 1      | (T + 1 Settlement) |
| 5 | ETH  | 30 天 | 10.00% | 10     | (T + 1 Settlement) |

### Fixed Income Products - 60 Days（FIP / FIP_60Days）

产品综合年化：10.00%

| # | 币种 | 期限 | 年化 | 起购 | 结算 |
|---|------|------|------|------|------|
| 1 | USD  | 60 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 2 | USDT | 60 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 3 | USDC | 60 天 | 10.00% | 10,000 | (T + 1 Settlement) |
| 4 | BTC  | 60 天 | 10.00% | 1      | (T + 1 Settlement) |
| 5 | ETH  | 60 天 | 10.00% | 10     | (T + 1 Settlement) |

(... one section per product, sorted by sort ASC)
```

### Canonical example (English — open-term)

```
### Fixed Income Products - Open Term T+3（FIP / FIP_OpenTerm_T+3）

Product-level APY: 10.00%-11.11%

| # | Currency | Term | APY | Min | Settlement | MHP |
|---|----------|------|-----|-----|------------|-----|
| 1 | USD  | Flexible | 10.00% | 10,000 | (T + 3 Settlement) | Minimum Holding Period: 14 Days |
| 2 | USDT | Flexible | 10.00% | 10,000 | (T + 3 Settlement) | — |
| 3 | USDC | Flexible | 10.00% | 10,000 | (T + 3 Settlement) | — |
| 4 | BTC  | Flexible | 10.00% | 1      | (T + 3 Settlement) | — |
| 5 | ETH  | Flexible | 11.11% | 10     | (T + 3 Settlement) | — |
```

### Closing line — adapted for recommendation context

After the LAST product section, append exactly ONE closing line. This line **differs** from the wealth scenario STEP 3A's closing — it references the user's actual available holdings to make the recommendation feel personalized.

**Chinese:**

> 您有大量 {user_held_currencies} 可用于认购。请问您想认购哪一款？请告诉我**产品名称**和**币种**。（期限由产品决定，无需指定）

**English:**

> You have ample {user_held_currencies} available to subscribe. Which product would you like? Please tell me the **product name** and **currency**. (Term is determined by the product — no need to specify.)

#### `{user_held_currencies}` derivation

1. **Set A** = union of `currencyItemList[j].currency` across all products in `get_fip_products` `data`
2. **Set B** = currencies from the user's `get_account_detail` responses (`fiat` + `crypto` `instrumentInfoMap`) where `availableAmount > 0`
3. **Intersection** = A ∩ B
4. **Order** the intersection as: USD → USDT → USDC → BTC → ETH (drop currencies not in the intersection)
5. **Join:** Chinese uses `、`; English uses `, ` between items and `, and ` before the last
6. **Empty intersection fallback** (user holds zero of the product currencies — rare): use the wealth-scenario-standard closing instead, dropping the holdings reference:
   - CN: `请问您想认购哪一款？请告诉我**产品名称**和**币种**。（期限由产品决定，无需指定）`
   - EN: `Which product would you like? Please tell me the **product name** and **currency**. (Term is determined by the product — no need to specify.)`

### Display rules

- **No header / 标语 / 💡 emoji line above the product sections.** The image-spec rendering starts directly with the first `### Fixed Income Products - ...` heading.
- **No collapsing / summarizing** — every product returned by the server is rendered as its own section with its full variant table. Do NOT merge multiple products into a single summary table.
- **No financial advice in the closing line** — the holdings reference is FACTUAL ("you have these currencies available"), not advisory ("you should buy XYZ"). Do NOT add commentary like "建议您选择 30 Days 产品" / "we recommend the 30 Days product".
- **`estApr`, `liquidity`, `mhp`, `term` (open-term)** — render server-returned strings verbatim. Do NOT translate, paraphrase, or reformat.
- **Term (fixed-term only)** — localize per LANGUAGE CONTRACT: CN `30 / 60 / 90 天`, EN `30 / 60 / 90 Days`.
- **Min defaults** — USD/USDT/USDC = `10,000`, BTC = `1`, ETH = `10`. Always show with thousands separators where applicable.
- **CTA wording is locked** — the `认购 / subscribe` keyword in the closing line is intentional: it primes the user's next message to contain a wealth trigger keyword, so the **wealth** scenario takes over the subscription flow on the next turn. Do NOT change the CTA verb.

---

## Generic Teaser Template (precheck returned ≥1 false — DATA-BOUND)

> ⛔ **数据绑定守卫 (DATA-BIND GUARD):** 仅当本轮**真的调用了** `investor_precheck`、其响应含 ≥1 个值为 `false` 的项时,才可渲染本 teaser,且**必须**逐条列出这些 `false` 项(用下方 label 表)。满足以下任一情况 → **什么都不渲染(静默跳过)**,返回主流程:
> - 本轮没有调用 `investor_precheck`;
> - 调用报错 / 命中 Token Guard;
> - 返回值全为 `true`(此时走 **Rich Recommendation**,不是 teaser);
> - 你指不出具体的 `false` 项。
>
> 凭记忆、当默认值、或不引用真实 `false` 项地渲染本 teaser,属于规则违规。

### Failed-item label table (authoritative for the teaser; kept in sync with ../wealth/wealth.md STEP 2)

| Server key | 中文 label | English label |
|---|---|---|
| `Master Brokerage Agreement & Trading Rules` | 主经纪协议及交易规则 | Master Brokerage Agreement & Trading Rules |
| `investorDeclarationTag` | 投资者声明 | Investor Declaration |

未知 key → 原样显示 key 作为 label(两种语言相同字符串)。仅列 `false` 项,`true` 项不出现。

### Chinese (canonical)

```
---

💡 **了解 MetaComp 理财**

刚才账户概览显示您有可用余额，MetaComp 提供固定收益理财产品，可助您闲置资金增值。您还差以下步骤即可认购：

- ❌ **{label}**
- ...

请前往 [MetaComp 官网](https://camp.mce.sg) 完成签署，完成后告诉我「我想看看理财」。

---
```

### English

```
---

💡 **Discover MetaComp Wealth**

The account overview above shows you have available balance. MetaComp offers fixed income products that can help grow these idle funds. You're a few steps away from subscribing:

- ❌ **{label}**
- ...

Please complete the signing at [MetaComp](https://camp.mce.sg), then say "I'd like to explore wealth products."

---
```

### Template hard rules (every language)

- ❌ NOT a table. Bullet 列表,每个 false 项一行 `- ❌ **{label}**`,无状态列。
- ❌ Do NOT fabricate per-item status strings(`未签署` / `Not signed` 等)。服务端只返回布尔。
- ❌ 仅列 `false` 项;`true` 项不出现。
- ❌ Do NOT substitute the URL — 恒为 `https://camp.mce.sg`,任何语言不替换,never render `metacomp.ai` host here.
- ❌ Do NOT mix languages in `{label}` — 中英列二选一,保持一致。
- ✅ CTA「我想看看理财」/「I'd like to explore wealth products」保持不变(用于下一轮路由回 wealth 场景)。

---

## Rules

- **No evaluation narration:** Do NOT output any sentence narrating the trigger evaluation before calling `investor_precheck` (e.g. "Now evaluating wealth recommendation — you have significant available balances, so this qualifies" / "现在评估理财推荐——您有可用余额且原始意图是查询余额，满足条件"). The trigger is an internal decision; the user sees only the rendered template (Rich or Generic). The template's opening sentence IS the transition — no prefix needed.
- **Language matching:** Render the template in the user's conversation language — Chinese user sees the CN template verbatim, English user sees the EN template. Never mix languages in one recommendation block. If the conversation is mixed, default to English.
- **Non-blocking:** After showing the recommendation (rich or generic), always continue to the primary flow's next step. The recommendation is appended content, not a replacement.
- **One per conversation:** If the recommendation (either template) has already been displayed in this conversation, do not display it again.
- **No product specifics in teaser:** When the teaser is rendered (precheck returned ≥1 `false` item), it must NOT contain any product names, codes, APYs, currencies, or term details. This respects the wealth scenario's Absolute Rule that the product catalog is gated behind eligibility.
- **No financial advice:** The recommendation presents factual product information (APY, currencies, terms). Do NOT add commentary like "your assets are concentrated in BTC, consider diversifying" or "you should subscribe." This handles recommendation mechanics only.
- **Call to action phrasing:** The CTA "我想看看理财" / "I'd like to explore wealth products" is chosen to match the wealth scenario's trigger words, so it naturally routes to the wealth scenario in the next turn.
- **Language:** Follow the user's conversation language. Templates above are canonical in Chinese; translate prose/headers for English users. Server-returned strings (`estApr`, `Flexible`) are verbatim.
