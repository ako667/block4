# Defense presentation — review & corrected slide text

Review of: *Blockchain Technologies 2 — Final Term.pdf* (15 slides) vs. actual `prediction-market` codebase.

**Verdict:** Structure is good for a 10–15 min defense, but several slides describe features **not in the repo** or **incorrect tech**. Update before defense to match `FINAL_REPORT.md` and live demo.

---

## Slide-by-slide

| Slide | OK? | Issue | Action |
|-------|-----|-------|--------|
| 1 Title | ✅ | Team names match repo README | Keep |
| 2 Executive summary | ⚠️ | Says users bet with **PMT**; PMT is **governance only** (ERC20Votes). Trading uses **collateral** (USDC / WETH). | Use corrected text below |
| 3 Repository | ⚠️ | Missing `audit/`, `scripts/`, `docs/`; no `treasury/` folder | Fix tree |
| 4 Foundry | ✅ | 0.8.24, Base Sepolia, Infura — correct | Add: 117 tests, CI |
| 5 Local deploy | ✅ | `deploy-anvil.sh`, `.env` — correct | Mention `LocalMarketGovernor` |
| 6 Prediction market | ⚠️ | Generic; omits **CPMM**, **ERC-1155**, **factory**, **oracle**, **dispute** | Expand |
| 7 PMT token | ⚠️ | Implies betting with PMT | Clarify governance + delegation only |
| 8 Governor + Timelock | ✅ | Correct pattern | Add quorum/threshold numbers |
| 9 Treasury | ❌ | **No `Treasury.sol`** — fees in **LPVault** (ERC-4626), protocol via factory/governor | **Replace slide** with Vault + fees |
| 10 Frontend | ❌ | Says **Ethers.js**; project uses **Wagmi + Viem**. Says **market creation** in UI — UI does **trade + vote**, not `createMarket` | Fix stack + features |
| 11 Subgraph | ⚠️ | OK conceptually | Add **Goldsky** + `base-sepolia`; Studio optional |
| 12 Testing | ⚠️ | Vague | State **117 passed**, fuzz/invariant/audit |
| 13 Base Sepolia deploy | ❌ | Claims **successful deploy** — only valid after real `ONCHAIN SUCCESS` | Say *configured + pending* or show Basescan |
| 14 Challenges | ✅ | Reasonable | Add: fmt/CI, Graph start-block, wallet faucet |
| 15 Conclusion | ⚠️ | “Mainnet” vague | Prefer Base mainnet / more market types / Vercel |

---

## Corrected slide copy (paste into PowerPoint / Canva)

### Slide 2 — Executive summary

The project delivers an **on-chain binary prediction market (Option D)** on **Base Sepolia** (local: **Anvil**).

- Users trade **YES/NO outcome shares** via a custom **CPMM** (`x·y = k`, 0.3% fee) using **collateral** (mock USDC/WETH locally).
- **PMT** (`ERC20Votes`) powers **DAO governance** — propose, delegate, vote — not trading collateral.
- **Factory** deploys UUPS market proxies; **Chainlink adapter** + **48h dispute window** for resolution.
- **React + Wagmi** dApp, **Goldsky subgraph**, **Foundry** test suite (117+ tests), **CI** pipeline.

### Slide 3 — Repository

```
contracts/   — PredictionMarket, Factory, ERC-1155, LPVault, Oracle, Governor
tests/       — unit, fuzz, invariant, fork
scripts/     — Deploy.s.sol, deploy-anvil.sh, VerifyPostDeploy.s.sol
frontend/    — React 18 + Vite + Wagmi
subgraph/    — schema + mappings (base-sepolia)
audit/       — AUDIT.md + security case studies
docs/        — ARCHITECTURE.md, FINAL_REPORT.md, GAS.md
.github/     — ci.yml
```

Repo: **https://github.com/ako667/block4**

### Slide 6 — Prediction market (core)

- **PredictionMarketFactory** — `createMarket` / `CREATE2` deterministic addresses
- **PredictionMarket** (UUPS proxy) — reserves `reserveYes` / `reserveNo`, `buyOutcome` / `sellOutcome`
- **GlobalOutcomeShares** — ERC-1155 YES/NO per market ID
- **LPVault** — ERC-4626 **pmLP** liquidity + fee collection
- **MarketOracle** + **ChainlinkAdapter** — staleness guard (3600s)
- **Dispute window** — 48 hours before final resolution

### Slide 7 — PMT token

- **GovernanceToken (PMT)** — 1M supply, `ERC20Votes` + `Permit`
- Used for **voting power** (`delegate` → `castVote` on **MarketGovernor**)
- **Not** the trading currency — collateral is USDC (testnet mock) / WETH on local demo

### Slide 9 — Replace “Treasury” → **Vaults & protocol fees**

- **LPVault (ERC-4626)** — LPs deposit collateral, receive pmLP shares; protocol fees via `depositFees`
- **TimelockController** — 2-day delay on executed governance actions
- Parameter changes (e.g. swap fee) via **governor proposals**, not a separate treasury contract

### Slide 10 — Frontend dApp

- **Stack:** React 18, **Vite**, **Wagmi**, **Viem** (not Ethers.js)
- **Features:** MetaMask connect, Anvil / network switch, ETH or USDC **Buy YES**, **Delegate PMT**, **Vote FOR** proposal, **Markets (Graph)** from subgraph
- Local: `http://localhost:5173` + Anvil `8545`

### Slide 11 — Subgraph

- Indexes `MarketCreated`, trades, liquidity, resolution on **base-sepolia**
- Hosted on **Goldsky** (GraphQL-compatible); The Graph schema/mappings in `subgraph/`
- Endpoint: see cover table in `FINAL_REPORT.md`

### Slide 12 — Testing & security

- `forge test` — **117 passed**, 0 failed, 3 fork skipped (offline RPC)
- **Fuzz** (AMM, governance), **invariants** (CPMM *k*), **GovernanceTest** E2E
- **audit/AUDIT.md**, Slither in CI, intentional vulnerable contracts for teaching

### Slide 13 — Base Sepolia (honest wording)

**If not yet deployed on-chain:**

> Base Sepolia **infrastructure is configured** (Infura RPC, `Deploy.s.sol`, subgraph manifest). **Live verified addresses pending** funded-wallet broadcast. Local **Anvil** + **Goldsky** demonstrate full stack.

**After successful deploy:**

> Contracts broadcast to Base Sepolia; Factory verified on Basescan; subgraph synced on Goldsky; addresses in `deployments/base-sepolia.env`.

---

## What to add (missing from PDF)

1. **CPMM / AMM** — core course requirement  
2. **ERC-1155** global outcome shares  
3. **ERC-4626** LP vault  
4. **UUPS upgrades** + factory CREATE2  
5. **Security audit** + Slither + case studies  
6. **CI/CD** (`ci.yml` or terminal 117 passed)  
7. **Live demo plan:** Anvil trade + vote + (optional) Graph on testnet  
8. **Environment matrix** — slide or appendix from `FINAL_REPORT.md` §22  

---

## Demo script (1 slide or speaker notes)

1. `anvil` → `./scripts/deploy-anvil.sh` → `cd frontend && npm run dev`  
2. Connect MetaMask → Buy YES (ETH) → show balance change  
3. Delegate PMT → Vote FOR (proposal Active)  
4. (Optional) Goldsky Playground `{ markets { id question } }` after testnet deploy  

---

## Cover slide metadata (optional)

- **Course:** Blockchain Technologies 2 — Final Term  
- **Scenario:** Option D — On-Chain Prediction Market  
- **Network:** Base Sepolia (primary), Anvil (local)  
- **Team:** Aktoty Omar, Daniyal Sadykov, Akerke Kuan — SE-2432  
