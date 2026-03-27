# metacomp-skill

Claude Code skills for Web3 security — powered by [MetaComp VisionX](https://www.metacomp.ai).

---

## Skills

### `metacomp-visionx-kyt`

A KYT (Know Your Transaction) skill that checks the security of Web3 wallets and transactions using the **MetaComp VisionX** MCP server. It aggregates risk signals from multiple on-chain analytics vendors and presents a structured, cross-vendor security report.

**Triggers automatically when you:**
- Paste a wallet address (`0x...`, Bitcoin address, Tron address)
- Paste a transaction hash
- Ask about Web3 security, scam risk, or suspicious on-chain activity

**Supported networks:** Ethereum · Bitcoin · Tron · *more coming soon*

**What you get:**
- **Wallet report** — risk score, exposure breakdown by category (scam, sanctions, mixing, etc.), transaction timeline, cross-vendor comparison, and a risk conclusion card
- **Transaction report** — transaction-level risk assessment + counterparty wallet report in one response

**MCP server required:** `metacomp-mcp` (`https://www.metacomp.ai/mcp`)

---

## Setup

### 1. Add the MCP connector

In the Claude web client:

**Sidebar → Customize → Connectors → + → Add custom connector**

| Field | Value |
|---|---|
| Name | `metacomp-visionx-kyt` |
| URL | `https://www.metacomp.ai/mcp` |

### 2. Authorize with your API key

Customize → Connectors → find **metacomp-visionx-kyt** → **Connect**

Enter your `sk-...` API key → **Allow**

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

### 3. Install the skill

Download `Metacomp-VisionX-KYT.zip` from this repository and import it into Claude Code. The skill file (`SKILL.md`) and its sub-skills (`subSkills/`) will be loaded automatically.

---

## File Structure

```
metacomp-skill/
├── Metacomp-VisionX-KYT.zip     # Skill package (SKILL.md + subSkills/)
│   ├── SKILL.md                 # Main skill definition
│   └── subSkills/
│       ├── wallet-report.md         # Wallet report layout spec
│       ├── wallet-exposure-tables.md # Exposure detail table spec
│       ├── wallet-risk-card.md      # Risk conclusion card widget
│       ├── transaction-report.md    # Transaction report layout spec
│       ├── visualization.md         # Widget & layout rules
│       └── chart-spec.md            # Spider chart rendering spec
└── README.md
```

---

## Tool Reference

The skill calls two MCP tools provided by the MetaComp VisionX server:

| Tool | Input | Purpose |
|---|---|---|
| `get_wallet_security` | network + wallet address | Analyze a wallet's risk profile |
| `get_transaction_security` | network + transaction details | Analyze a transaction's risk signals |

For a transaction query, both tools are called in parallel — `get_transaction_security` on the transaction and `get_wallet_security` on the counterparty wallet.

---

## License

MIT — see [LICENSE](./LICENSE)
