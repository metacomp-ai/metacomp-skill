# StableX

**MetaComp's proprietary FX and settlement engine — bridging fiat and digital rails for instant, compliant cross-border settlement.**

---

## What is StableX?

Cross-border settlement is broken. SWIFT moves slowly, correspondent banking is expensive, and stablecoin rails — while fast — remain siloed from the traditional financial system. StableX exists to fix this.

StableX is MetaComp's proprietary FX and settlement engine. It handles the full conversion and delivery of value across any combination of fiat and digital assets, routing each transaction through the most efficient path available — whether that's SWIFT, a stablecoin network, or a hybrid of both. The result is settlement that is faster, cheaper, and inherently compliant.

---

## Conversion Coverage

StableX handles the full conversion matrix:

| From | To | Example |
|---|---|---|
| Fiat | Fiat | USD → SGD, EUR → GBP |
| Fiat | Stablecoin | USD → USDT, EUR → USDC |
| Stablecoin | Fiat | USDT → SGD, USDC → HKD |
| Stablecoin | Stablecoin | USDT → USDC, USDC → FDUSD |

No matter where value starts or where it needs to land, StableX finds a path.

---

## Smart Routing

Not every payment should take the same route. StableX continuously evaluates available rails and selects the optimal path based on:

- **Speed** — stablecoin rails for near-instant finality when time is critical
- **Cost** — minimize FX spread and network fees across competing routes
- **Compliance** — route only through corridors that meet the regulatory requirements of both the sending and receiving jurisdiction
- **Liquidity** — real-time liquidity awareness to avoid slippage on larger flows

The routing decision happens automatically, in the background — the sender specifies what they want to send and where it needs to arrive; StableX handles the rest.

---

## Rail Support

| Rail | Characteristics |
|---|---|
| **SWIFT** | Global reach, established correspondent relationships, regulatory familiarity |
| **Stablecoin networks** | Near-instant settlement, 24/7 operation, low cost |
| **Hybrid routes** | Fiat on one end, stablecoin in transit — best of both worlds for speed and reach |

StableX treats stablecoins not as an alternative to traditional finance, but as a settlement layer that extends it — filling the gaps where SWIFT is too slow or too expensive.

---

## Compliance Built In

StableX operates within MetaComp's **Major Payment Institution (MPI)** licensed infrastructure under the Monetary Authority of Singapore (MAS). Every conversion and settlement flow is designed to meet the regulatory requirements of the relevant corridors — FX handling, fund movement, and reporting included.

For deeper transaction-level compliance screening, StableX integrates directly with **VisionX**, MetaComp's KYT engine, as part of the PayX orchestration layer.

---

## Get Started

StableX is currently in development. API documentation and integration guides will be published here when available.

> Interested in early access or a liquidity partnership? Reach out at [metacomp.ai](https://www.metacomp.ai)

---

## License

MIT — see [LICENSE](../LICENSE)
