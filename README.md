# MetaComp Agent Skill

A single MCP-powered skill that exposes MetaComp's account and Web3-security
capabilities to Claude and other MCP-compatible clients. One `SKILL.md` entry
point routes the request to the matching scenario — withdrawal, currency swap,
wealth (Fixed Income Products), balance / portfolio overview, or VisionX Web3
risk screening — loading the relevant files under `references/` at runtime.

---

## Download

The skill is released as **one zip per backend environment**, each pre-configured
to talk to the matching MetaComp environment.

→ **[Latest release](https://github.com/metacomp-ai/metacomp-skill/releases/latest)** &nbsp;·&nbsp; **[All releases](https://github.com/metacomp-ai/metacomp-skill/releases)**

| Zip | Backend it points to |
|---|---|
| `MetaComp-demo-<version>.zip`    | `https://demo.metacomp.ai` |
| `MetaComp-sandbox-<version>.zip` | `https://sandbox.metacomp.ai` |
| `MetaComp-prod-<version>.zip`    | `https://www.metacomp.ai` (production) |

### Install

1. Download the zip for your target environment from the release page above.
2. Unzip it — you get a single `MetaComp/` folder.
3. Upload that folder to Claude through *Customize → Skills*.
4. Set up the MCP connector — see [Connecting the MCP server](#connecting-the-mcp-server) below.

---

## What it does

| Capability | Summary |
|---|---|
| Balance / portfolio overview | Renders the multi-account portfolio overview and per-currency detail. |
| Withdrawal | Outbound fiat and crypto transfers, distinguishing first-party from third-party destinations and their differing compliance requirements. |
| Swap | Currency exchange across supported fiat–fiat, fiat–crypto, and crypto–crypto pairs, with a time-boxed quote shown before execution. |
| Wealth (FIP) | Investor pre-check, then browse and subscribe to MetaComp Fixed Income Products with an explicit agreement-acceptance step. |
| VisionX (Web3 security) | Structured risk reports for a wallet address or transaction hash — entity identification, risk-source breakdown, and exposure direction, aggregated across multiple on-chain analytics vendors. |

The skill routes by intent: describe what you want (e.g. "withdraw 500 USDC",
"swap 100k USDT to SGD", "check my balance", or paste a wallet address) and the
entry point dispatches to the matching scenario.

---

## Connecting the MCP server

The skill uses the **`metacomp-mcp`** connector.

1. In Claude, open *Customize → Connectors → +* and add a custom connector named
   `metacomp-mcp`, using the `/mcp` URL for the environment your downloaded zip
   targets — for production that is `https://www.metacomp.ai/mcp`.
2. Connect and authorize with an `sk-...` API key issued for that environment.
3. Re-send the request. A 401 after connecting means the key must be
   re-authorized or reissued.

The connector environment must match the zip you installed (a production zip
talks to the production backend, a `uat` zip to UAT, and so on).

---

## Repository layout

```
.
├── MetaComp/
│   ├── SKILL.md          entry point: routing + per-scenario step protocol
│   └── references/       shared/ swap/ visionx/ wealth/ withdraw/
├── build.sh              per-environment URL rewrite + zip
└── .github/workflows/    bundle build workflow
```

`SKILL.md` carries YAML frontmatter (name, version, description, MCP server)
followed by the router and per-scenario step protocols. Files under
`references/` are loaded by the entry point as each scenario requires.

---

## Contributing

When editing the skill:

- Bump `version:` in `MetaComp/SKILL.md` frontmatter.
- Keep the router (STEP ZERO) and each scenario's sub-skill list in sync with the
  files actually under `references/`.
- Do not loosen the Token Guard, the Wealth Evaluation Gate, or the Funds-First Gate without an explicit design discussion; they are safety rails, not stylistic choices.
- Trigger phrases (including bilingual variants) belong in the `description:`
  field of the frontmatter, not in the step prose.
