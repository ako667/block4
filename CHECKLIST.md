# Final Checklist — Prediction Market (Option D)

## Repository structure

- [x] `contracts/` — core, governance, interfaces, libraries, proxy
- [x] `tests/` — unit, fuzz, invariant, fork
- [x] `scripts/` — deploy, verify, timelock transfer
- [x] `subgraph/` — schema, mappings, queries
- [x] `frontend/` — React dApp (Wagmi); Next.js pages in `frontend-next/` optional scaffold
- [x] `audit/` — security report
- [x] `docs/` — architecture, gas
- [x] `.github/workflows/` — CI

## Smart contracts

| Item | Status | Location |
|------|--------|----------|
| Global ERC-1155 (ID 1/2 market 1, 3/4 market 2) | ✅ | `contracts/tokens/GlobalOutcomeShares.sol` |
| CPMM `swap()` + 0.3% fee | ✅ | `contracts/core/PredictionMarket.sol` |
| Yul `mulDiv` | ✅ | `contracts/libraries/CPMMath.sol` |
| ERC-4626 pmLP vault | ✅ | `contracts/vault/LPVault.sol` |
| Chainlink + staleness 3600s | ✅ | `contracts/oracle/ChainlinkAdapter.sol` |
| `resolveMarket(marketId)` | ✅ | `contracts/oracle/MarketOracle.sol` |
| Dispute window 48h | ✅ | `PredictionMarket.DISPUTE_WINDOW` |
| UUPS + V2 | ✅ | `PredictionMarket` / `PredictionMarketV2` |
| CREATE + CREATE2 | ✅ | `PredictionMarketFactory` |
| GovernanceToken (Votes+Permit) | ✅ | `contracts/governance/GovernanceToken.sol` |
| MarketGovernor + Timelock 2d | ✅ | `MarketGovernor` + OZ Timelock |

## Tests (80+)

```bash
forge test
```

Named plan tests: `tests/unit/PlanChecklist.t.sol`

## Frontend

- [x] MetaMask connect
- [x] Wrong network prompt
- [x] Readable errors
- [x] Subgraph section
- [x] Swap + vote writes

## Documentation

- [x] `docs/ARCHITECTURE.md` (6+ pages)
- [x] `audit/AUDIT.md` (8+ pages)
- [x] `docs/GAS.md`

## Before defense

1. Deploy Arbitrum Sepolia + verify
2. Update `frontend/.env`
3. Deploy subgraph with factory address
4. Run `slither . --config-file slither.config.json`
