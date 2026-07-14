# Auth + KYC Gate + Server Setup (shared, money flows)

Shared by the **deposit**, **withdraw**, **swap**, **wealth** scenarios. This is the common STEP 1 prelude: probe the session with `get_account_summary`, branch on the response, and (on success) render the Account Overview from `./account-overview.md`.

---

## STEP 1 — Probe & Authenticate

Call `get_account_summary()` to verify the user's session, then evaluate the cases below **in order**.

### ⚠️ KYC gate — evaluate BEFORE Case A / B / C

If ANY of the following is true → show the **KYC Required** output, ⛔ **STOP**. Do NOT treat as a session/auth error even if `authPageUrl` is also present:
- `reason: "kyc_required"` is present in the response (structured field)
- Response is an error or `success: false` AND the message/error text contains `KYC not yet completed` or `kyc_required`

**KYC Required output** (`{metacompKycUrl}` from response — render in the user's language):

> ⚠️ **KYC verification not completed**
>
> Your MetaComp account hasn't finished identity verification (KYC) yet. Until KYC is approved, this account cannot use deposit, withdrawal, swap, or wealth services.
>
> **What you need to do:**
>
> 1. Go to [MetaComp to complete KYC]({metacompKycUrl}).
> 2. Submit the required documents (ID, proof of address, etc.) and wait for approval.
>
> Once your KYC is approved, come back and let me know — I'll pick up where we left off.

### Case A — Connection failure / raw 401 with **no** structured `authPageUrl`
Server not configured / not reachable (no structured response body). Show the **Server Setup Guide** (below), **STOP**. (If the response **does** carry `authPageUrl`, it is a session-expiry — skip to Case B, not Case A.)

### Case B — `success: false` with `authPageUrl`

Example response:
```json
{
  "success": false,
  "authPageUrl": "https://www.metacomp.ai/auth/metacomp/login",
  "msg": "Invalid token"
}
```

Output (render in the user's language):

> Your session has expired. Please log in to continue:
>
> [Log in to MetaComp]({authPageUrl})
>
> ---
>
> 👤 **Don't have a MetaComp account yet?** [Sign up here]({metacompSignUpUrl}) — it takes a few minutes. Once registered, come back and I'll pick up where we left off.
>
> Once logged in, come back here and let me know — I'll pick up where we left off.

⛔ **STOP.** Do not call any tool. Wait for the user to confirm they have logged in. When the user confirms → go back to STEP 1 (re-call the tool).

> 🔁 **Resume checklist (do not skip any step):** after the re-call succeeds on Case C, walk through the full post-overview sequence in order — **(1) Account Overview table → (2) Per-Currency Detail → (3) Wealth Evaluation Gate → (4) the scenario's next step**. A continuation reply like "go on" / "继续" / "I've logged in" is a flow-control signal; it does NOT override the **original triggering message** when evaluating WEALTH_RECOMMENDATION_TRIGGER condition 5. Anchor that evaluation to the user's original intent, not the continuation.

### Case C — Success (no `success: false` in response)

**Mandatory:** render the account overview, then continue. The display spec and the post-overview step are scenario-dependent:

- **deposit / withdraw / wealth** → render per `./account-overview.md` (5-row summary + fiat/crypto per-currency detail).
- **swap** → render per `../swap/account-display.md` instead (it adds currency pairs + all-5-productCode detail). Swap does not use `account-overview.md`.

After the overview:
- **deposit / withdraw / swap** → evaluate the **Wealth Evaluation Gate** (mandatory; see SKILL.md), then continue to the scenario's next step (or the View-Only closing).
- **wealth** → do NOT run the Wealth Evaluation Gate (it IS the wealth flow); go straight to STEP 2 in `../wealth/wealth.md`.

---

## MetaComp — Server Setup Guide

**No server added yet** → complete all 3 steps.
**Server added, no API key** → skip to Step 2.

### Step 1 — Add the Server
Sidebar → **Customize** → **Connectors** → **+** → **Add custom connector**
- Name: `metacomp-mcp`
- URL: `https://www.metacomp.ai/mcp`

### Step 2 — Connect and Authorize
Customize → Connectors → find **metacomp-mcp** → **Connect**
Enter your `sk-...` API key → **Allow**

> No API key? Apply at [metacomp.ai](https://www.metacomp.ai)

### Step 3 — Re-send your request
**401 after connecting?** Re-authorize or apply for a new key at metacomp.ai.
