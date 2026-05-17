# On-Chain Prediction Market

**Blockchain Technologies 2 — Final Project · Option D**

Decentralized binary prediction market: traders buy **YES/NO** outcome shares priced by a custom **CPMM** (`x·y=k`, 0.3% fee). Collateral is USDC; liquidity providers receive **pmLP** (ERC-4626). Planned extensions include **Chainlink** resolution with staleness checks, a **48h dispute window**, **DAO governance** (Governor + Timelock), **UUPS** upgrades, **The Graph** indexing, and a **React + Wagmi** dApp on **Arbitrum Sepolia**.

---

## Current scope

The repository currently contains the **protocol foundation**: math libraries, token standards, vaults, interfaces, mocks, proxy shell, test harness, and CI. The market engine, oracle integration, governance, subgraph, and full frontend are **in progress**.

| Area | Status |
|------|--------|
| CPMM math (Yul `mulDiv`, 0.3% fee) | Implemented |
| ERC-1155 outcome shares (global IDs per market) | Implemented |
| ERC-4626 LP / fee vault (`pmLP`) | Implemented |
| UUPS proxy wrapper | Scaffold |
| Interfaces & mocks (USDC, oracle stub) | Implemented |
| Unit tests (CPMM, ERC-1155, gas benchmark) | Implemented |
| CI (`forge build` + tests) | Implemented |
| Prediction market engine & factory | Planned |
| Chainlink oracle & settlement | Planned |
| Governance (ERC20Votes + Governor + Timelock) | Planned |
| Subgraph & dApp | Planned |

---

## Architecture (target)

```text
                    ┌──────────────┐
                    │   Traders    │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐   ┌──────────┐  ┌─────────┐
         │  dApp  │   │ Governor │  │ Chainlink│
         └────┬───┘   └────┬─────┘  └────┬────┘
              │            │             │
              └────────────┼─────────────┘
                           ▼
              ┌────────────────────────┐
              │  PredictionMarket      │
              │  (UUPS) + Factory      │
              └───────────┬────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
  GlobalOutcomeShares  LPVault      CPMMath
  (ERC-1155 YES/NO)    (ERC-4626)
```

---

## Repository layout

```text
contracts/
├── interfaces/     IChainlinkAdapter, IPredictionMarket
├── libraries/      CPMMath (Yul), CPMMathPure
├── mocks/          MockERC20, MockV3Aggregator, MockOracleAdapter
├── tokens/         GlobalOutcomeShares, OutcomeShares
├── vault/          LPVault, FeeVault
└── proxy/          MarketProxy (ERC-1967)

tests/
├── helpers/        BaseSetup.sol
├── unit/           CPMMath.t.sol, OutcomeShares.t.sol
└── benchmark/      YulBenchmark.t.sol

frontend/.env.example
.github/workflows/ci.yml
CHECKLIST.md
```

### Outcome token IDs

One **GlobalOutcomeShares** contract serves all markets:

| Market | YES | NO |
|--------|-----|-----|
| 1 | `1` | `2` |
| 2 | `3` | `4` |
| *n* | `2n−1` | `2n` |

Only addresses granted `MINTER_ROLE` / `BURNER_ROLE` (future market engine) can mint or burn shares.

---

## Quick start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Install & build

```bash
git clone <repository-url>
cd prediction-market
forge install
forge build
```

### Tests

```bash
forge test --match-path tests/unit/CPMMath.t.sol
forge test --match-path tests/unit/OutcomeShares.t.sol
forge test --match-path tests/benchmark/YulBenchmark.t.sol
```

### Lint / CI

```bash
forge fmt --check
```

GitHub Actions runs `forge build` and the test suite on every push and pull request.

---

## Key components

### CPMMath

Constant-product swap with **0.3% fee**. Core arithmetic uses **Yul `mulDiv`**; `CPMMathPure` provides a Solidity reference for gas comparison (`tests/benchmark/YulBenchmark.t.sol`).

### GlobalOutcomeShares (ERC-1155)

Binary outcome shares for all markets in a single contract. Reduces deployment cost and simplifies indexing.

### LPVault / FeeVault (ERC-4626)

Token symbol **pmLP**. LPs deposit USDC; the vault also accepts protocol swap fees via `depositFees` (restricted to approved collectors).

### MarketProxy

ERC-1967 proxy used when the **PredictionMarket** implementation is deployed (upcoming). Supports **UUPS** upgrades.

### Mocks

- **MockERC20** — 6-decimal USDC stand-in  
- **MockV3Aggregator** — Chainlink-style price feed for tests  
- **MockOracleAdapter** — temporary oracle interface implementation until the real adapter is integrated  

---

## Configuration

| File | Purpose |
|------|---------|
| `foundry.toml` | Solidity 0.8.24, optimizer, fuzz/invariant profiles |
| `remappings.txt` | OpenZeppelin & forge-std paths |
| `slither.config.json` | Static analysis (Slither) |
| `frontend/.env.example` | Template for dApp contract addresses (future) |

Dependencies are managed via **git submodules** (`.gitmodules`). Run `forge install` after cloning.

---

## Requirements checklist

Course deliverables and progress tracking: [CHECKLIST.md](CHECKLIST.md).

---

## License

MIT
