# MetaComp Agent Skills

MCP-powered skills that expose MetaComp's Deposit, Withdrawal, Swap, Wealth, and VisionX products to Claude and other MCP-compatible clients. Each skill is a self-contained folder containing a `SKILL.md` entry point, supporting `subSkills/`, and any references the agent loads at runtime.

---

## Download

Skills are released as **one bundle per backend environment**. Each bundle contains six skill `.zip`s pre-configured to talk to the matching MetaComp environment (`dev`, `demo`, `uat`, or `www` / production).

→ **[Latest release](https://github.com/metacomp-ai/metacomp-skill/releases/latest)** &nbsp;·&nbsp; **[All releases](https://github.com/metacomp-ai/metacomp-skill/releases)**

| Outer bundle | Backend it points to |
|---|---|
| `metacomp-skills-dev.zip`  | `https://dev.metacomp.ai`  |
| `metacomp-skills-demo.zip` | `https://demo.metacomp.ai` |
| `metacomp-skills-uat.zip`  | `https://uat.metacomp.ai`  |
| `metacomp-skills-www.zip`  | `https://www.metacomp.ai` (production) |

Each outer bundle contains six per-skill zips with the version baked into the filename:

```
metacomp-skills-demo.zip
├── MetaComp-Deposit-demo-0.5.3.zip
├── MetaComp-Withdrawal-demo-0.4.1.zip
├── MetaComp-Swap-demo-0.5.2.zip
├── MetaComp-Wealth-demo-0.6.0.zip
└── MetaComp-VisionX-demo-1.3.0.zip
```

### Install

1. Download the bundle for your target environment from the release page above.
2. Unzip the outer bundle, then unzip the individual skill(s) you want.
3. Upload the resulting folder to Claude through *Customize → Skills*.
4. Set up the MCP connector — see [Connecting the MCP servers](#connecting-the-mcp-servers) below.

---

## Skills at a glance

| Skill | Version | Purpose |
|---|---|---|
| [MetaComp-Deposit](./MetaComp-Deposit) | 0.5.3 | Deposit fiat or crypto into a MetaComp account; also serves balance / portfolio queries |
| [MetaComp-Withdrawal](./MetaComp-Withdrawal) | 0.4.1 | Withdraw fiat or crypto, distinguishing first-party and third-party destinations |
| [MetaComp-Swap](./MetaComp-Swap) | 0.5.2 | Currency exchange across the supported fiat and crypto pair matrix |
| [MetaComp-Wealth](./MetaComp-Wealth) | 0.6.0 | Browse and subscribe to MetaComp Fixed Income Products (FIP) |
| [MetaComp-VisionX](./MetaComp-VisionX) | 1.3.0 | Risk screening for Web3 wallets and transactions |

---

## Skill descriptions

### MetaComp-Deposit
Handles fiat and crypto deposits into a MetaComp account. For fiat the skill returns wire-transfer instructions for the selected currency. For crypto it returns the network-specific wallet address as inline text plus an HTML QR-code artifact. The same entry point also serves pure balance queries: it renders a 5-account portfolio overview (Fiat, Crypto, Investment Fiat, Quarantine Portfolio, Investment Product) and per-currency detail, then exits without entering the deposit flow.

### MetaComp-Withdrawal
Handles outbound transfers of fiat and crypto. The skill differentiates **first-party** (the user's own bank account or wallet) from **third-party** (a beneficiary other than the user) withdrawals at the start of the flow, since each has different regulatory requirements. Third-party crypto sends attach the required compliance document IDs internally. The skill collects destination, amount, and any memo or reference fields, then renders a confirmation summary before submitting the transaction.

### MetaComp-Swap
Performs currency exchange across supported fiat-fiat, fiat-crypto, and crypto-crypto pairs. The skill fetches the user's currency pair matrix and account summary in parallel, validates the requested source/target/amount against available balance, and obtains a quote. The quote (source amount, target amount, rate, fee) is shown to the user and is valid for 60 seconds; on confirmation within the window the trade executes against the quoted rate, otherwise it is re-quoted at execution time.

### MetaComp-Wealth
Subscribes the user to MetaComp Fixed Income Products. The flow runs an investor pre-check (eligibility, risk tier, jurisdiction), then renders the catalog of products the user qualifies for with APY, term, liquidity terms, and minimum holding period. Subscription requires the user to repeat a verbatim agreement-acceptance phrase generated from the product's legal documents; only an exact match is treated as consent before the subscription call is made.

### MetaComp-VisionX
Returns a structured risk report for a Web3 wallet address or transaction hash. The wallet report includes entity identification, risk-source breakdown by category (sanctions, scam, mixer exposure, illicit counterparty, and others), and a comprehensive summary; the transaction report additionally distinguishes sender and recipient sides and flags exposure direction. Underlying data is aggregated across multiple on-chain analytics vendors. Uses the `metacomp-mcp` connector. See [`MetaComp-VisionX/README.md`](./MetaComp-VisionX/README.md) for the broader VisionX product context.

---

## Connecting the MCP servers

MetaComp-Deposit, MetaComp-Withdrawal, MetaComp-Swap, and MetaComp-Wealth all use the **`metacomp mcp`** connector:

1. In Claude, open *Customize → Connectors → +* and add a custom connector named `metacomp mcp` with URL `https://demo.metacomp.ai/mcp`.
2. Connect and authorize with an `sk-...` API key. Keys are issued at [metacomp.ai](https://demo.metacomp.ai).
3. Re-send the request. A 401 after connecting indicates the key must be re-authorized or reissued.

MetaComp-VisionX uses the **`metacomp-mcp`** connector (note the hyphen — different from the connector above).

---

## Repository layout

```
.
├── MetaComp-Deposit/      SKILL.md + subSkills/
├── MetaComp-Withdrawal/   SKILL.md + subSkills/
├── MetaComp-Swap/         SKILL.md + subSkills/
├── MetaComp-Wealth/       SKILL.md + subSkills/
└── MetaComp-VisionX/      SKILL.md + subSkills/ + README.md
```

Each `SKILL.md` carries YAML frontmatter (name, version, description, MCP server) followed by a numbered step protocol and absolute rules. Files under `subSkills/` are loaded by the entry point before any tool call.

---

## Contributing

When editing a skill:

- Bump `version:` in the affected `SKILL.md` frontmatter.
- Keep the STEP ZERO sub-skill list and its confirmation line in sync — every file listed in Step A must appear in the confirmation in Step B.
- Do not loosen Token Guard, the Wealth Evaluation Gate, or the QR Artifact Gate without an explicit design discussion; they are safety rails, not stylistic choices.
- Trigger phrases (including bilingual variants) belong in the `description:` field of the frontmatter, not in the step prose.
