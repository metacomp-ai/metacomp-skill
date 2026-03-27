# metacomp-skill

AI skills for the [MetaComp](https://www.metacomp.ai) platform.

Works with any MCP-compatible AI client. **Optimized for Claude.**

---

## About MetaComp

MetaComp holds a **Major Payment Institution (MPI) license** issued by the Monetary Authority of Singapore (MAS). Our mission is to build the full-stack infrastructure for compliant, intelligent payments — from on-chain risk and KYT, to payment execution, settlement, and compliance across both Web3 and traditional finance rails.

The skills in this repository bring MetaComp's capabilities directly into the AI tools developers and analysts already use. As our services grow, more skills will be added here.

---

## Skills

### `metacomp-visionx-kyt`

A KYT (Know Your Transaction) skill powered by **MetaComp VisionX**, our Web3 security service. It checks the risk of wallets and transactions by aggregating signals from multiple on-chain analytics vendors and presenting a structured, cross-vendor security report.

**Triggers automatically when you:**
- Paste a wallet address (`0x...`, Bitcoin address, Tron address)
- Paste a transaction hash
- Ask about Web3 security, scam risk, or suspicious on-chain activity

**Supported networks:** Ethereum · Bitcoin · Tron · *more coming soon*

**What you get:**
- **Wallet report** — risk score, exposure breakdown by category (scam, sanctions, mixing, etc.), transaction timeline, cross-vendor comparison, and a risk conclusion card
- **Transaction report** — transaction-level risk assessment + counterparty wallet report in one response

---

## Platform Support

| Platform | Support | Notes |
|---|---|---|
| Claude (web / Claude Code) | Best | Native skill format with full report rendering |
| Cursor / Windsurf / Cline | Good | Load `SKILL.md` as system prompt + connect MCP server |
| Other MCP-compatible clients | Basic | Connect MCP server; manual prompt guidance may be needed |

---

## Setup

### Step 1 — Connect the MCP server

Add `https://www.metacomp.ai/mcp` as a custom MCP server in your AI client and authorize with your `sk-...` API key.

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

**For Claude web client:**

Sidebar → **Customize** → **Connectors** → **+** → **Add custom connector**

| Field | Value |
|---|---|
| Name | `metacomp-visionx-kyt` |
| URL | `https://www.metacomp.ai/mcp` |

Then: Connectors → find **metacomp-visionx-kyt** → **Connect** → enter API key → **Allow**

### Step 2 — Load the skill

Download `Metacomp-VisionX-KYT.zip` from this repository.

- **Claude Code** — import the zip directly; the skill activates automatically
- **Other clients** — paste the contents of `SKILL.md` into your system prompt or custom instructions

---

## File Structure

```
metacomp-skill/
├── Metacomp-VisionX-KYT.zip     # Skill package
│   ├── SKILL.md                 # Main skill definition
│   └── subSkills/               # Report layout & rendering specs
└── README.md
```

---

## Tool Reference

The skill calls two MCP tools exposed by the MetaComp platform:

| Tool | Input | Purpose |
|---|---|---|
| `get_wallet_security` | network + wallet address | Analyze a wallet's risk profile |
| `get_transaction_security` | network + transaction details | Analyze a transaction's risk signals |

For a transaction query, both tools are called in parallel — `get_transaction_security` on the transaction and `get_wallet_security` on the counterparty wallet.

---

## License

MIT — see [LICENSE](./LICENSE)
