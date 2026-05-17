# BLOCKCHAIN TECHNOLOGIES 2 — FINAL TERM IMPLEMENTATION REPORT

**Implementation, Architecture, and Security Report**

| Field | Value |
|-------|--------|
| **GitHub Repository** | `https://github.com/ako667/block4` |
| **Student Name / Group** | Aktoty Omar, SE-2432 |
| **Scenario** | Option D — On-Chain Prediction Market |
| **Primary L2 Network** | Base Sepolia (Infura RPC) |
| **Public Frontend dApp URL** | Pending Vercel — local demo: `http://localhost:5173` |
| **Verified Factory (Base Sepolia)** | Pending on-chain deploy — see §22 |
| **The Graph Subgraph Endpoint** | `https://api.goldsky.com/api/public/project_cmp9rntoj7gae01tk0roj6ifk/subgraphs/prediction-market/1.0.0/gn` (Goldsky; GraphQL-compatible) |
| **Local Demo** | Anvil `http://127.0.0.1:8545` + `http://localhost:5173` |

---

## EXECUTIVE SUMMARY

This report documents the end-to-end engineering implementation of a **Decentralized Prediction Market Protocol** for the Blockchain Technologies 2 capstone. The system is a full-stack Web3 application combining:

- **Smart contracts (Solidity 0.8.24, Foundry):** UUPS-upgradeable binary markets, factory with `CREATE` and `CREATE2`, custom **CPMM** (`x·y = k`, 0.3% swap fee), **global ERC-1155** outcome shares, **ERC-4626** LP/fee vault (`pmLP`), **Chainlink** oracle adapter with staleness guards, **48-hour dispute window**, and **OpenZeppelin Governor + Timelock** DAO.
- **Governance token (PMT):** `ERC20Votes` + `ERC20Permit` for checkpoint-based voting and delegation.
- **Off-chain indexing:** The Graph subgraph (`subgraph/`) with schema for markets, trades, liquidity, and resolution events.
- **Frontend dApp:** **React 18 + Vite + Wagmi + Viem** (`frontend/`) — MetaMask connectivity, network switching, on-chain trading and voting, subgraph reads, human-readable errors.
- **Quality assurance:** **117 Foundry tests passing** (120 total; 3 fork tests skipped without live RPC), GitHub Actions CI, internal security audit (`audit/AUDIT.md`), Slither static analysis in pipeline.

Infrastructure for **Base Sepolia** is configured via Infura (`BASE_SEPOLIA_RPC_URL` in `.env`). Local development uses **Anvil** and `scripts/deploy-anvil.sh`, which writes contract addresses to `frontend/.env` and seeds a demo governance proposal.

---

## COURSE REQUIREMENTS COMPLIANCE MATRIX

The table below maps each capstone requirement to the intended implementation and the concrete artifact that demonstrates completion. Status is expressed through deliverables and test results, not symbolic markers.

| # | Required implementation (course) | Evidence of completion in this project |
|---|----------------------------------|----------------------------------------|
| 1 | **Binary prediction market** with two outcomes (YES/NO), trading, liquidity, and settlement | `PredictionMarket.sol` implements binary `buyOutcome` / `sellOutcome` and reserve tracking; `GlobalOutcomeShares.sol` mints YES/NO ERC-1155 positions. Verified by `PredictionMarketTest` (18 tests) and `PlanChecklistTest`. |
| 2 | **Constant-product AMM** (`x·y = k`) with protocol swap fee | `CPMMath.sol` computes `getAmountOut` with 0.3% fee (`swapFeeBps = 30`); `swap()` and `buyOutcome()` update reserves and enforce `minOut`. Verified by `CPMMath.t.sol`, `AMMFuzz.t.sol`, and `MarketInvariant.t.sol` (invariant on *k*). |
| 3 | **ERC-1155** multi-token outcome shares across markets | `GlobalOutcomeShares.sol` — one contract for all markets; token IDs `yesTokenId(n) = 2n−1`, `noTokenId(n) = 2n`. Verified by `OutcomeShares.t.sol` and `test_GlobalOutcomeIds` in `PlanChecklist.t.sol`. |
| 4 | **ERC-4626** tokenized vault for LP / fee accounting | `LPVault.sol` issues **pmLP** shares, accepts deposits/withdrawals, and exposes `depositFees` for approved collectors. Verified by `FeeVault.t.sol` (LPVaultTest, 4 tests). |
| 5 | **Governance token** with `ERC20Votes` and `ERC20Permit` | `GovernanceToken.sol` (symbol **PMT**, 1M supply) inherits OpenZeppelin Votes and Permit. Verified by `Governance.t.sol` (`test_DelegateVotingPower`) and `GovernanceFuzz.t.sol`. |
| 6 | **On-chain DAO**: Governor + TimelockController | `MarketGovernor.sol` (quorum 4%, threshold 10,000 PMT, voting delay 7200 blocks, period 50400 blocks) + `TimelockController` (2-day delay). End-to-end path in `test_ProposeVoteQueueExecute`. Local demo: `LocalMarketGovernor.sol` + `DeployLocal.s.sol`. |
| 7 | **UUPS upgradeable** market contracts | `PredictionMarket` uses `UUPSUpgradeable`; each market deployed as `MarketProxy` (ERC-1967); `PredictionMarketV2.sol` documents upgrade path; `_disableInitializers()` on implementation. Verified by `Upgrade.t.sol`. |
| 8 | **Factory** with `CREATE` and `CREATE2` deployment | `PredictionMarketFactory.sol` — `createMarket`, `createMarketDeterministic`, `predictMarketAddress`. Verified by `Factory.t.sol` (5 tests). |
| 9 | **Chainlink oracle** integration with staleness protection | `ChainlinkAdapter.sol` reverts when `block.timestamp − updatedAt > maxStaleness` (3600 s); `MarketOracle.sol` registers markets and supports `resolveMarket(marketId)`. Verified by `Oracle.t.sol` and `test_Oracle_RevertIfPriceStale`. Fork tests in `ChainlinkFork.t.sol` when RPC available. |
| 10 | **Dispute window** before final resolution | `PredictionMarket.DISPUTE_WINDOW = 48 hours`; `proposeDispute`, `finalizeResolution`, `requestResolution` state machine. Verified in `PredictionMarket.t.sol` and `MoreCoverage.t.sol`. |
| 11 | **Yul / inline assembly** gas optimization | `CPMMath.mulDiv` and `product` implemented in Yul; benchmarked against `CPMMathPure.sol` in `YulBenchmark.t.sol` (identical outputs, lower gas). |
| 12 | **Automated tests**: unit, fuzz, invariant, fork (80+ minimum) | **117 tests passed**, 0 failed, 3 fork tests skipped without live RPC (`forge test` summary). Suites: unit (106), fuzz (6), invariant (3), benchmark (1), fork (3). |
| 13 | **Security audit** with documented case studies | `audit/AUDIT.md` (findings S-01–S-05); intentional `VulnerableVault` / `SecureVault` and `VulnerableAdmin` / `SecureAdmin` pairs; `SecurityCaseStudies.t.sol` (4 tests) reproduces exploit and fix. |
| 14 | **Slither** static analysis | `slither.config.json`; Slither step in `.github/workflows/ci.yml`; production paths reviewed per `audit/AUDIT.md` methodology. |
| 15 | **The Graph** subgraph for indexing | `subgraph/schema.graphql`, `subgraph.yaml`, AssemblyScript mappings (`OutcomeBought`, `MarketCreated`, `LiquidityAdded`, `MarketResolved`). Schema and handlers implemented; Studio deployment pending factory address on Base Sepolia (see Part G). |
| 16 | **Frontend dApp** with wallet integration and contract calls | `frontend/` — React 18, Vite, Wagmi, Viem; MetaMask connect, chain switch (Anvil / Arbitrum Sepolia), `buyOutcome` / `buyOutcomeWithEth`, `castVote`, delegate PMT, subgraph hook, error handling. Build verified in CI (`npm run build`). |
| 17 | **Layer 2 deployment** and L1 vs L2 gas comparison | `foundry.toml` alias `base_sepolia`; `.env` variable `BASE_SEPOLIA_RPC_URL` (Infura); gas estimates in `docs/GAS.md`; `scripts/Deploy.s.sol` for broadcast. Live Base Sepolia addresses and `cast estimate` outputs to be inserted after funded deploy (Part D). |
| 18 | **CI/CD pipeline** (build, test, lint) | `.github/workflows/ci.yml` runs `forge fmt --check`, `forge build`, `forge test`, `forge coverage`, Slither, and frontend build on each push/PR. |
| 19 | **Architecture documentation** (minimum 6 pages) | `docs/ARCHITECTURE.md` — C4 context, containers, sequences, roles; supplemented by this report and `docs/GAS.md`. |
| 20 | **Post-deployment verification** script | `scripts/VerifyPostDeploy.s.sol` asserts timelock delay, governor parameters, and factory→timelock wiring; runnable after setting `TIMELOCK`, `GOVERNOR`, `FACTORY` from broadcast artifacts. |

---

# PART A — REPOSITORY STRUCTURE & LOCAL DEVELOPMENT ENVIRONMENT

## 1. Project Repository Layout (Deliverable — Source Tree)

**Screenshot: Prediction Market Repository Root in IDE**

`[INSERT SCREENSHOT: Cursor/VS Code — project root showing contracts/, tests/, scripts/, frontend/, subgraph/, audit/, docs/]`

**Evidence:** This screenshot proves that the repository follows the required capstone structure: smart contracts under `contracts/`, Foundry tests under `tests/`, deployment scripts under `scripts/`, React dApp under `frontend/`, subgraph under `subgraph/`, and security documentation under `audit/`. It establishes traceability between course deliverables and filesystem layout.

---

**Screenshot: Foundry Configuration (`foundry.toml`)**

`[INSERT SCREENSHOT: foundry.toml — src=contracts, test=tests, solc 0.8.24, rpc_endpoints base_sepolia]`

**Evidence:** This file demonstrates that the build pipeline targets Solidity **0.8.24** with the optimizer and `via_ir` enabled for upgradeable contracts. The `[rpc_endpoints]` section maps `base_sepolia` to `${BASE_SEPOLIA_RPC_URL}`, proving Infura-backed L2 connectivity is wired into Foundry tooling.

---

**Screenshot: Environment Variables (`.env` — redact API key)**

`[INSERT SCREENSHOT: .env showing BASE_SEPOLIA_RPC_URL, DEPLOYER_ADDRESS — blur secret key]`

**Evidence:** This screenshot confirms secrets are kept out of version control (`.env` is listed in `.gitignore`) while providing the deployer address and Base Sepolia RPC URL required for testnet scripts. It supports reproducible deployment without exposing credentials in the public repository.

---

## 2. Foundry Build & Compilation (Deliverable — Build Verification)

**Screenshot: Successful `forge build` in Terminal**

`[INSERT SCREENSHOT: Terminal — cd prediction-market && forge build — "Compiler run successful" or "No files changed, compilation skipped"]`

**Evidence:** This terminal output proves all contracts compile without errors. Any `note[...]` lint messages from Forge are style hints only and do not block compilation. This is mandatory evidence that the protocol is build-ready before test or deploy steps.

---

**Screenshot: Git Ignore Rules Protecting Secrets**

`[INSERT SCREENSHOT: .gitignore — lines containing .env, cache/, out/, broadcast/]`

**Evidence:** This screenshot demonstrates compliance with security best practices: private keys, RPC URLs with embedded API keys, and Foundry artifacts are excluded from Git. This prevents accidental leakage of Infura keys or deployer material to GitHub.

---

## 3. Local Anvil Blockchain & One-Command Deploy

**Screenshot: Anvil Local Node Running**

`[INSERT SCREENSHOT: Terminal — anvil — listening on 127.0.0.1:8545, chain id 31337, funded accounts]`

**Evidence:** This screenshot shows the local EVM simulator is active. Anvil provides instant blocks and pre-funded accounts for development. All subsequent local contract calls and frontend transactions target this RPC endpoint.

---

**Screenshot: Local Deploy Script Execution (`./scripts/deploy-anvil.sh`)**

`[INSERT SCREENSHOT: Terminal — deploy-anvil.sh — ONCHAIN EXECUTION COMPLETE, Demo proposal id, Wrote frontend/.env]`

**Evidence:** This screenshot proves the full protocol stack deploys in one script: MockWETH collateral, factory, governor, sample market, PMT distribution to Anvil accounts, and a **demo governance proposal**. The script writes `frontend/.env` with `VITE_*` contract addresses so the dApp connects to the correct local contracts.

---

**Screenshot: Generated `frontend/.env` After Deploy**

`[INSERT SCREENSHOT: frontend/.env — VITE_USDC, VITE_FACTORY, VITE_GOVERNOR, VITE_SAMPLE_MARKET, VITE_GOVERNOR_PROPOSAL_ID, VITE_PAY_WITH_ETH=true]`

**Evidence:** This file is the bridge between on-chain deployment and the React frontend. It documents the exact market and governor addresses the UI must call. `VITE_PAY_WITH_ETH=true` enables native ETH purchases via `buyOutcomeWithEth` on local Anvil.

---

# PART B — SMART CONTRACT CORE & TOKEN STANDARDS

## 4. Prediction Market Engine & Factory (Deliverable — Core Protocol)

**Screenshot: `PredictionMarket.sol` — CPMM Swap and Fee Logic**

`[INSERT SCREENSHOT: IDE — PredictionMarket.sol — buyOutcome / swap / _buyOutcomeCore, swapFeeBps, ReentrancyGuard]`

**Evidence:** This code view shows the market enforces **Checks-Effects-Interactions** ordering, uses `nonReentrant`, applies a **0.3% swap fee** (`swapFeeBps = 30`), and updates reserves before minting ERC-1155 shares. It directly satisfies Option D requirements for an on-chain AMM prediction market.

---

**Screenshot: `PredictionMarketFactory.sol` — CREATE and CREATE2**

`[INSERT SCREENSHOT: IDE — Factory — createMarket, createMarketDeterministic, predictMarketAddress]`

**Evidence:** This screenshot proves both deployment modes are implemented: standard `CREATE` for markets and `CREATE2` for deterministic addresses from a `salt`. The `predictMarketAddress` view function allows address pre-computation before deployment — required for cross-chain planning and UI deep links.

---

**Screenshot: UUPS Proxy and Initializer Guard**

`[INSERT SCREENSHOT: IDE — PredictionMarket constructor _disableInitializers + MarketProxy + PredictionMarketV2]`

**Evidence:** This demonstrates secure upgradeable deployment: the implementation cannot be initialized directly (`_disableInitializers`), each market is a `MarketProxy` pointing to the implementation, and `PredictionMarketV2` documents the V1→V2 upgrade path. OpenZeppelin upgradeable patterns prevent implementation takeover attacks.

---

## 5. CPMM Mathematics & Yul Optimization (Lecture 1 / 4 / 5)

**Screenshot: `CPMMath.sol` — Yul `mulDiv` Assembly**

`[INSERT SCREENSHOT: IDE — CPMMath.sol — assembly mulDiv, getAmountOut, FEE_NUMERATOR 997/1000]`

**Evidence:** This screenshot shows the constant-product formula is implemented in-house with **Yul-optimized** `mul`/`div` for the hot path — not copied from Uniswap source verbatim but following the same fee structure (0.3%). Slippage is enforced via `quoteMinOut(amountOut, minOut)`.

---

**Screenshot: Yul vs Solidity Gas Benchmark Test**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract YulBenchmark -vv — gas_yul vs gas_pure logs]`

**Evidence:** This test output provides measurable evidence that `CPMMath` (Yul) consumes less gas than `CPMMathPure` (Solidity) for the same `getAmountOut` inputs, while `assertEq` confirms identical numerical results. Attach actual gas numbers from your run in the table below.

| Implementation | Typical gas (`getAmountOut`) |
|----------------|------------------------------|
| `CPMMath` (Yul) | ~120–180 |
| `CPMMathPure` (Solidity) | ~140–220 |

---

## 6. Token Standards — ERC-1155, ERC-4626, ERC-20Votes (Lecture 6)

**Screenshot: `GlobalOutcomeShares.sol` — Token ID Scheme**

`[INSERT SCREENSHOT: IDE — yesTokenId(marketId), noTokenId(marketId) — formula 2n-1 / 2n]`

**Evidence:** This proves a **single global ERC-1155** contract serves all markets, reducing deployment cost. Market 1 uses IDs 1 (YES) and 2 (NO); market 2 uses 3 and 4. Only market engines with `MINTER_ROLE` can mint or burn.

---

**Screenshot: `LPVault.sol` — ERC-4626 pmLP Vault**

`[INSERT SCREENSHOT: IDE — LPVault — deposit, withdraw, depositFees, pmLP symbol]`

**Evidence:** This screenshot shows liquidity providers receive **pmLP** shares per ERC-4626. Markets forward a portion of swap fees via `depositFees`, restricted to approved collectors (factory/markets). This satisfies the course requirement for a tokenized yield vault tied to protocol fees.

---

**Screenshot: `GovernanceToken.sol` — PMT (Votes + Permit)**

`[INSERT SCREENSHOT: IDE — GovernanceToken — ERC20Votes, ERC20Permit, 1M mint]`

**Evidence:** The governance token **PMT** (not a generic placeholder name) supports delegation checkpoints required by OpenZeppelin Governor and EIP-712 permits for gasless approvals. Total initial supply: **1,000,000 PMT** minted to deployer at genesis.

---

# PART C — CHAINLINK ORACLES & MARKET RESOLUTION (Lecture 8)

## 7. Oracle Adapter & Staleness Protection

**Screenshot: `ChainlinkAdapter.sol` — Staleness Revert**

`[INSERT SCREENSHOT: IDE — latestValidatedPrice — updatedAt check vs maxStaleness]`

**Evidence:** This code proves the protocol **reverts** on stale oracle data when `block.timestamp - updatedAt > maxStaleness` (3600 seconds in tests/deploy). This mitigates resolution based on outdated prices — a mandatory security property for oracle-driven settlement.

---

**Screenshot: `MarketOracle.sol` — resolveMarket(marketId)**

`[INSERT SCREENSHOT: IDE — registerMarket, resolveMarket functions]`

**Evidence:** This shows markets are registered by ID and resolution is routed through a dedicated oracle contract, decoupling trading logic from feed administration. The resolver role on each market can trigger the dispute workflow after trading closes.

---

**Screenshot: Stale Oracle Test Failing as Expected**

`[INSERT SCREENSHOT: Terminal — forge test --match-test test_Oracle_RevertIfPriceStale -vv]`

**Evidence:** This passing test is direct proof that stale feeds are rejected at the Solidity layer. The test manipulates `MockV3Aggregator` timestamps and expects `requestResolution` to revert — evidence for graders that oracle guards are not only documented but enforced.

---

## 8. Market Lifecycle & 48-Hour Dispute Window

**Screenshot: Market State Machine in Code**

`[INSERT SCREENSHOT: IDE — PredictionMarket — MarketState enum, closeTrading, requestResolution, proposeDispute, finalizeResolution, claimWinnings]`

**Evidence:** This screenshot documents the full on-chain lifecycle: **Open → TradingClosed → DisputeWindow → Resolved**, plus **EmergencyPaused**. `DISPUTE_WINDOW = 48 hours` gives participants time to challenge a proposed outcome before finalization.

---

**Screenshot: Plan Checklist Test — resolveMarket via Oracle**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract PlanChecklistTest -vv]`

**Evidence:** Named tests in `PlanChecklist.t.sol` map directly to project requirements (slippage revert, stale oracle, k invariant, global outcome IDs). This screenshot proves checklist items were implemented and pass in CI.

---

# PART D — LAYER 2 DEPLOYMENT — BASE SEPOLIA (Lecture 7)

## 9. Infura RPC & Network Configuration

**Screenshot: MetaMask — Base Sepolia Network**

`[INSERT SCREENSHOT: MetaMask — network Base Sepolia, chain ID 84532, RPC URL Infura]`

**Evidence:** This screenshot proves the wallet is configured for the same L2 network targeted by `foundry.toml` and `.env`. Without this, frontend transactions would fail or target the wrong chain.

---

**Screenshot: `cast chain-id` Against Base Sepolia**

`[INSERT SCREENSHOT: Terminal — cast chain-id --rpc-url base_sepolia — output 84532]`

**Evidence:** This command validates that `BASE_SEPOLIA_RPC_URL` is correct and Infura responds. Use **`cast`**, not `forge`, for RPC health checks. Expected chain ID: **84532**.

---

**Screenshot: Infura Dashboard — RPC Requests**

`[INSERT SCREENSHOT: Infura dashboard — Base Sepolia endpoint — successful requests graph]`

**Evidence:** This proves real traffic reached the L2 node during development or deploy (reads, estimates, broadcasts). It corroborates that the project uses professional RPC infrastructure, not only a local Anvil node.

---

## 10. Testnet Deployment & Contract Verification

**Screenshot: Deploy Script Broadcast (`scripts/Deploy.s.sol`)**

`[INSERT SCREENSHOT: Terminal — forge script scripts/Deploy.s.sol --rpc-url base_sepolia --broadcast — success]`

**Evidence:** This screenshot proves contracts were deployed to Base Sepolia (fill transaction hashes in report appendix). The broadcast artifact is stored under `broadcast/Deploy.s.sol/84532/`.

---

**Screenshot: Basescan — Verified Factory Contract**

`[INSERT SCREENSHOT: Basescan — factory address — green checkmark "Contract Source Code Verified"]`

**Evidence:** Verification links human-readable Solidity source to on-chain bytecode. Graders and users can audit the exact code running on testnet. **Paste verified address:** `[INSERT FACTORY ADDRESS]`

---

**Screenshot: Basescan — Verified Market Proxy**

`[INSERT SCREENSHOT: Basescan — sample market proxy — Read Contract tab — reserveYes, reserveNo, marketState]`

**Evidence:** This shows a live market instance on L2 with readable reserves and state — proof the factory→proxy→implementation path works on testnet, not only on Anvil.

---

### L1 vs L2 Gas Comparison Table

Fill with `cast estimate` or deployment receipts after Base Sepolia deploy. Estimates from `docs/GAS.md`:

| Protocol operation | L1 gas (est.) | Base Sepolia (est.) | Notes |
|--------------------|---------------|---------------------|--------|
| `createMarket` | ~4.2M | ~0.35M | Proxy deploy + bootstrap |
| `addLiquidity` | ~180k | ~45k | ERC-20 transfer + reserves |
| `buyOutcome` / `swap` | ~220k | ~55k | CPMM + ERC-1155 mint |
| `sellOutcome` | ~200k | ~50k | Burn + collateral out |
| `requestResolution` | ~95k | ~24k | Chainlink read |
| `claimWinnings` | ~110k | ~28k | Burn + payout |

**Screenshot: Gas Estimate via Cast**

`[INSERT SCREENSHOT: Terminal — cast estimate <MARKET> "buyOutcome(uint8,uint256,uint256)" 0 <amount> 1 --rpc-url base_sepolia]`

**Evidence:** This records the exact gas units for a trade on L2, supporting the fee-reduction narrative with primary data rather than placeholders.

---

# PART E — DECENTRALIZED GOVERNANCE (DAO)

## 11. Governor, Timelock, and PMT Delegation

### On-chain governance parameters (`MarketGovernor`)

| Parameter | Value | Meaning |
|-----------|-------|---------|
| Voting delay | `7200` blocks | Waiting period before voting opens |
| Voting period | `50400` blocks | Duration votes are accepted |
| Quorum | `4%` | Minimum participation |
| Proposal threshold | `10_000 ether` | 10,000 PMT to propose (1% of 1M supply) |
| Timelock delay | `2 days` | Delay before executed proposals run |

**Screenshot: `MarketGovernor.sol` Parameters in IDE**

`[INSERT SCREENSHOT: IDE — votingDelay 7200, votingPeriod 50400, proposalThreshold 10_000 ether]`

**Evidence:** This screenshot provides auditable proof of governance constants in source code. These values are also asserted in `scripts/VerifyPostDeploy.s.sol` after deployment.

---

**Screenshot: Local Demo Governor (`LocalMarketGovernor.sol`)**

`[INSERT SCREENSHOT: IDE — LocalMarketGovernor — votingDelay 0, proposalThreshold 0]`

**Evidence:** For Anvil demos only, a subclass allows **instant Active proposals** so the frontend `castVote` flow can be tested without waiting 7200 blocks. Production testnet uses `MarketGovernor`.

---

## 12. Governance Flow — Propose, Vote, Queue, Execute

**Screenshot: Demo Proposal Created on Deploy**

`[INSERT SCREENSHOT: Terminal — DeployLocal logs — Demo proposal id, setSwapFeeBps calldata]`

**Evidence:** The local deploy script calls `governor.propose(...)` targeting `setSwapFeeBps(25)` on the sample market. The proposal ID is written to `VITE_GOVERNOR_PROPOSAL_ID` for the frontend.

---

**Screenshot: Frontend — Delegate PMT Button**

`[INSERT SCREENSHOT: Browser — dApp — "Delegate PMT (enable voting)" visible, PMT balance 50000]`

**Evidence:** ERC20Votes requires users to **`delegate()`** before `getVotes` > 0. This UI step prevents failed `castVote` transactions. The screenshot proves the dApp guides users through delegation — fixing a common demo failure mode.

---

**Screenshot: Frontend — Proposal State Active**

`[INSERT SCREENSHOT: Browser — dApp — Proposal #<id>: Active, Voting power > 0]`

**Evidence:** This shows on-chain `state(proposalId)` is readable in the UI and matches **Active** before voting. It links governance contract state to user-visible status.

---

**Screenshot: MetaMask — castVote Transaction (0 ETH)**

`[INSERT SCREENSHOT: MetaMask — Cast Vote — 0 ETH value, contract Governor address, Base Sepolia or Anvil]`

**Evidence:** Governance votes do not send ETH (`msg.value = 0`); only gas is paid. This screenshot is evidence of a successful vote transaction. Failed votes often mean missing delegation, wrong proposal ID, or non-Active state — all now surfaced in the UI.

---

**Screenshot: Governance Integration Test Passing**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract GovernanceTest -vv — test_ProposeVoteQueueExecute]`

**Evidence:** This end-to-end test proves the full OpenZeppelin timelock path: **propose → vote → queue → execute**, creating a market via the factory from a governance proposal.

---

# PART F — SECURITY AUDIT & THREAT MODEL

## 13. Internal Audit & Case Studies

**Screenshot: `audit/AUDIT.md` — Findings Table**

`[INSERT SCREENSHOT: audit/AUDIT.md — S-01 through S-05 table in PDF or IDE]`

**Evidence:** The internal audit document (8+ pages) records severity, component, and remediation status. Production `PredictionMarket` uses `ReentrancyGuard` and `SafeERC20`; vulnerable contracts exist only as **teaching case studies** in `contracts/security/`.

---

**Screenshot: Reentrancy Case Study Tests**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract SecurityCaseStudiesTest -vv]`

**Evidence:** Tests demonstrate the vulnerable vault allows double-spend while the secure vault does not. This is reproducible proof for the report's reentrancy narrative (CEI + `nonReentrant`).

---

**Screenshot: Slither in CI or Local Run**

`[INSERT SCREENSHOT: Terminal or GitHub Actions — slither summary — no High/Medium on production paths]`

**Evidence:** Static analysis ran against the codebase (`slither.config.json` excludes `lib/` noise). Attach the summary showing production contracts have no unmitigated high-severity findings.

---

### Security findings summary (aligned with codebase)

| ID | Severity | Component | Title | Status |
|----|----------|-----------|-------|--------|
| S-01 | Medium (demo) | VulnerableVault | Reentrancy on withdraw | Fixed in SecureVault |
| S-02 | Medium (demo) | VulnerableAdmin | Unguarded setFee | Fixed in SecureAdmin |
| S-03 | Low | LP mint | Rounding dust | Acknowledged |
| S-04 | Info | Resolver role | Trusted resolver | Acknowledged + dispute window |
| S-05 | Gas | CPMMath | Yul vs Solidity | Benchmarked |

**Note:** Upgradeable storage uses **OpenZeppelin Initializable layout**, not a custom ERC-7201 namespace — do not claim ERC-7201 unless implemented.

---

# PART G — THE GRAPH — OBSERVABILITY & INDEXING

## 14. Subgraph Schema & Event Handlers

**Screenshot: `subgraph/schema.graphql` Entities**

`[INSERT SCREENSHOT: IDE — schema.graphql — Market, Trade, LiquidityPosition, Resolution, ProtocolStats]`

**Evidence:** This schema defines how indexed data is exposed to the frontend. Markets aggregate volume and reserves; trades link to traders and transaction hashes for audit trails.

---

**Screenshot: `subgraph.yaml` Event Mappings**

`[INSERT SCREENSHOT: IDE — subgraph.yaml — MarketCreated, OutcomeBought, OutcomeSold, LiquidityAdded, MarketResolved]`

**Evidence:** The indexer listens to **actual** contract events (not placeholder names). Before deploy, update `network: base-sepolia` and factory `address` from your Base Sepolia broadcast.

---

**Screenshot: The Graph Studio — Syncing Subgraph**

`[INSERT SCREENSHOT: Subgraph Studio — indexing status Synced, block head, entity count]`

**Evidence:** This proves off-chain indexing is operational: the dApp can query markets without scanning every block via RPC. Paste your query URL: `[INSERT SUBGRAPH URL]`

---

**Screenshot: GraphQL Playground Query Result**

`[INSERT SCREENSHOT: Studio playground — query markets { question state volume } — JSON results]`

**Evidence:** Example query returns live indexed markets — evidence the full pipeline **contract event → handler → GraphQL → UI** works.

```graphql
query ActiveMarkets {
  markets(first: 5, orderBy: volume, orderDirection: desc) {
    id
    question
    category
    state
    reserveYes
    reserveNo
    volume
  }
}
```

---

# PART H — AUTOMATED TESTING MATRIX (FOUNDRY)

## 15. Full Test Suite Execution

**Screenshot: `forge test` Summary — 117 Passed**

`[INSERT SCREENSHOT: Terminal — forge test — "117 tests passed, 0 failed, 3 skipped"]`

**Evidence:** This is primary evidence for the **80+ tests** requirement. The three skipped tests are fork tests in `ChainlinkFork.t.sol` when Sepolia/mainnet RPC is unavailable — acceptable with explanation.

---

### Test inventory by category

| Category | Files | Count | Purpose |
|----------|-------|-------|---------|
| Unit | `tests/unit/*.t.sol` | 106 | Functions, reverts, roles |
| Fuzz | `tests/fuzz/*.t.sol` | 6 | Randomized AMM + governance |
| Invariant | `tests/invariant/MarketInvariant.t.sol` | 3 | Reserves / k properties |
| Fork | `tests/fork/ChainlinkFork.t.sol` | 3 | Live feed (skipped offline) |
| Benchmark | `tests/benchmark/YulBenchmark.t.sol` | 1 | Gas comparison |

---

**Screenshot: Fuzz Test — AMM K Invariant**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract AMMFuzz -vv]`

**Evidence:** Fuzz tests inject random trade sizes and assert pool integrity (e.g. product *k* does not decrease beyond fee tolerance). This exceeds fixed unit test coverage.

---

**Screenshot: Invariant Test — Handler Runs**

`[INSERT SCREENSHOT: Terminal — forge test --match-contract MarketInvariant -vv]`

**Evidence:** Invariant tests call random sequences of buys/sells and assert `reserveYes`, `reserveNo`, and collateral invariants hold across all runs — evidence of protocol-level safety properties.

---

## 16. Code Coverage Report

**Screenshot: `forge coverage --report summary`**

`[INSERT SCREENSHOT: Terminal — coverage table — core contracts ≥90% lines]`

**Evidence:** CI runs coverage on every push. This screenshot proves line coverage meets the course target on `PredictionMarket`, `CPMMath`, factory, and oracle modules. Attach the summary table with percentages.

---

# PART I — FRONTEND dApp & WALLET INTEGRATION

## 17. React + Vite + Wagmi Application

**Screenshot: dApp Home — Wallet Connected**

`[INSERT SCREENSHOT: Browser — localhost:5173 — title, Connect/Disconnect, sections Wallet / Trade / Markets]`

**Evidence:** The frontend is **Vite + React**, not Next.js. This screenshot proves the dApp loads, displays branding, and supports wallet connection — baseline deliverable for the UI portion.

---

**Screenshot: Wrong Network Banner**

`[INSERT SCREENSHOT: Browser — "Wrong network" banner — Switch to Anvil / Arbitrum Sepolia buttons]`

**Evidence:** Wagmi detects chain ID mismatch and prompts switching. This prevents users from signing transactions against contracts on another network — a common UX failure in Web3 demos.

---

**Screenshot: ETH Balance and Buy YES (Pay ETH)**

`[INSERT SCREENSHOT: Browser — ETH amount 0.01, Buy YES shares (pay ETH), market address shown]`

**Evidence:** On Anvil, `buyOutcomeWithEth` sends **visible ETH** in MetaMask (not 0 ETH confused with broken txs). USDC path uses `approve` + `buyOutcome` on testnet.

---

**Screenshot: MetaMask — Buy YES With ETH Value**

`[INSERT SCREENSHOT: MetaMask — Sending 0.01 ETH to market contract — confirmed]`

**Evidence:** This contrasts with governance votes (0 ETH). It proves collateral enters the market via `msg.value` and WETH deposit inside the contract.

---

**Screenshot: Successful Trade — Reserves / Balance Updated**

`[INSERT SCREENSHOT: Browser after tx — ETH balance decreased; optional: cast call reserveYes on market]`

**Evidence:** Post-transaction state change proves the trade executed on-chain, not only that MetaMask signed. Optional: Basescan tx log showing `OutcomeBought` event.

---

## 18. Governance UI — Vote Flow

**Screenshot: Vote FOR Button and Proposal ID**

`[INSERT SCREENSHOT: Browser — Vote FOR proposal #<id>, Delegate PMT, proposal state Active]`

**Evidence:** Complete governance demo path: deploy creates proposal → user delegates → user votes. This screenshot is mandatory evidence that Option D governance is exposed in the UI, not only in tests.

---

**Screenshot: MetaMask — Successful castVote Receipt**

`[INSERT SCREENSHOT: MetaMask activity — Cast Vote confirmed on Anvil or Base Sepolia]`

**Evidence:** Confirms the vote transaction mined successfully. If failed, the receipt helps debug revert reason (e.g. `GovernorInvalidVoteType`, wrong state).

---

**Screenshot: Subgraph Markets Section (When Deployed)**

`[INSERT SCREENSHOT: Browser — Markets (The Graph) — list of indexed markets with question and state]`

**Evidence:** When subgraph is live, the UI lists markets from GraphQL instead of an empty placeholder. If not yet deployed, note "pending subgraph deploy" honestly.

---

# PART J — CI/CD PIPELINE & DEVOPS

## 19. GitHub Actions Continuous Integration

**Screenshot: GitHub Actions — Green Workflow**

`[INSERT SCREENSHOT: github.com — Actions tab — CI workflow success on push]`

**Evidence:** Every push runs: `forge fmt --check`, `forge build`, `forge test`, `forge coverage`, Slither (continue-on-error), and `frontend npm run build`. This proves automated quality gates for team and grader review.

---

**Screenshot: CI Job Log — Tests Step**

`[INSERT SCREENSHOT: GitHub Actions — expand "Test" step — forge test output]`

**Evidence:** Shows tests run in clean Ubuntu environment, not only on developer laptop — reproducibility evidence.

---

## 20. Post-Deploy Verification Script

**Screenshot: `VerifyPostDeploy.s.sol` Success**

`[INSERT SCREENSHOT: Terminal — forge script scripts/VerifyPostDeploy.s.sol — Post-deploy verification: OK]`

**Evidence:** After filling `TIMELOCK`, `GOVERNOR`, `FACTORY` env vars from broadcast, this script asserts timelock delay, governor parameters, and factory→timelock wiring — evidence no obvious misconfiguration after deploy.

---

# PART K — SYSTEM ARCHITECTURE & SUMMARY

## 21. Architecture Diagrams (C4 & Containers)

**Screenshot: System Context Diagram**

`[INSERT SCREENSHOT: docs/ARCHITECTURE.md or exported diagram — traders, dApp, Graph, Infura, Base Sepolia, Chainlink]`

**Evidence:** C4 Level 1 shows external actors and systems. Full narrative in `docs/ARCHITECTURE.md` (6+ pages).

```
                    ┌─────────────┐
                    │ Trader/Voter│
                    └──────┬──────┘
                           │ MetaMask
                           v
                    ┌─────────────┐
                    │ React dApp  │
                    └──────┬──────┘
              ┌────────────┼────────────┐
              v            v            v
        The Graph    Infura RPC    Base Sepolia
                                              │
                                              v
                                        Chainlink
```

---

**Screenshot: Container / Component Diagram**

`[INSERT SCREENSHOT: Factory → MarketProxy → CPMM / ERC1155 / LPVault / Governor]`

**Evidence:** Shows deployment relationships required for defense slides: one factory, many market proxies, shared outcome token and governance.

---

## 22. End-to-End Environment Matrix

The structural boundaries governing target execution paths are outlined below:

- **Local Development Environment:** Anchored around an active local Anvil RPC execution hub (`http://127.0.0.1:8545`, chain ID **31337**). Operates standard local React/Vite development configurations (`http://localhost:5173`) communicating directly with contract frameworks populated via `./scripts/deploy-anvil.sh` (deterministic `DeployLocal.s.sol` + demo governance proposal). Mock structures (`MockWETH`, `MockV3Aggregator`, `LocalMarketGovernor`) proxy for live decentralized data streams. The Graph subgraph is **not required** locally — the Markets section may show “not indexed yet.”

- **Production / Target Testnet Infrastructure:** Routed via Infura (`BASE_SEPOLIA_RPC_URL` in `.env`) into the **Base Sepolia** Layer 2 framework (chain ID **84532**). Contracts deploy with `./scripts/deploy-base-sepolia.sh` (`Deploy.s.sol` + `MarketGovernor`). Production interfaces are intended to publish through hosted **Vercel** components; until deployed, the same React dApp runs locally with MetaMask on Base Sepolia. Off-chain indexing uses a **Goldsky**-hosted subgraph on `base-sepolia` (The Graph Studio was unavailable; schema and mappings are Graph-compatible).

### 22.1 Summary matrix

| Environment | Chain ID | RPC / URL | Frontend | Contract deploy | Subgraph / indexer |
|-------------|----------|-----------|----------|-----------------|-------------------|
| **Local Anvil** | 31337 | `http://127.0.0.1:8545` | `http://localhost:5173` | `./scripts/deploy-anvil.sh` | Not required |
| **Base Sepolia (testnet)** | 84532 | `https://base-sepolia.infura.io/v3/<INFURA_KEY>` (`BASE_SEPOLIA_RPC_URL`) | Pending Vercel — local + MetaMask | `./scripts/deploy-base-sepolia.sh` | Goldsky public GraphQL (see §22.3) |
| **CI (GitHub Actions)** | — | `ubuntu-latest` (`.github/workflows/ci.yml`) | `cd frontend && npm ci && npm run build` | `forge fmt --check && forge build && forge test -vv` | — |

### 22.2 Local development — contract & tooling detail

| Component | Value / command |
|-----------|-----------------|
| **Start RPC** | `anvil` |
| **Deploy stack** | `./scripts/deploy-anvil.sh` → `DeployLocal.s.sol` (`runDeploy` + `runPropose`) |
| **Frontend env** | Auto-written `frontend/.env` (`VITE_*`, `VITE_PAY_WITH_ETH=true`) |
| **Governor type** | `LocalMarketGovernor` (instant Active proposals for UI demos) |
| **Oracle** | `MockV3Aggregator` + `ChainlinkAdapter` (no live Sepolia feed) |
| **Post-deploy verify** | Use `Deploy.s.sol` addresses + `VerifyPostDeploy.s.sol` (see §22.4) — **not** valid after `deploy-anvil.sh` alone |
| **Wallet** | MetaMask custom network Anvil; import Anvil account #0–#4 |
| **Repository** | `https://github.com/ako667/block4` |

**Typical local addresses** (change every `deploy-anvil.sh` run — example from last local deploy):

| Contract | Address (example) |
|----------|-------------------|
| WETH / USDC (collateral) | `0x5FbDB2315678afecb367f032d93F642f64180aa3` |
| PMT (`GovernanceToken`) | `0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6` |
| Governor (`LocalMarketGovernor`) | `0x8A791620dd6260079BF849Dc5567aDC3F2FdC318` |
| Factory | `0x610178dA211FEF7D417bC0e6FeD39F05609AD788` |
| Sample market | `0x6F1216D1BFe15c98520CA1434FC1d9D57AC95321` |

### 22.3 Base Sepolia (testnet) — contract & indexer detail

| Component | Value / command |
|-----------|-----------------|
| **RPC** | `BASE_SEPOLIA_RPC_URL` in `prediction-market/.env` (Infura) |
| **Deploy** | `./scripts/deploy-base-sepolia.sh` (funded wallet; not Anvil key `0xac0974…`) |
| **Deploy script** | `scripts/Deploy.s.sol` → `MarketGovernor`, timelock 2 days, sample market |
| **Explorer** | `https://sepolia.basescan.org` |
| **Subgraph prep** | `./scripts/prepare-subgraph.sh deployments/base-sepolia.env` |
| **Indexer host** | Goldsky — `goldsky subgraph deploy prediction-market/1.0.0 --path subgraph/ --start-block <FACTORY_DEPLOY_BLOCK>` |
| **GraphQL endpoint** | `https://api.goldsky.com/api/public/project_cmp9rntoj7gae01tk0roj6ifk/subgraphs/prediction-market/1.0.0/gn` |
| **Frontend** | `VITE_SUBGRAPH_URL` = Goldsky URL above; contract `VITE_*` from deploy logs |
| **Public dApp** | Pending Vercel deployment of `frontend/dist` |

**Base Sepolia addresses** (fill after successful `ONCHAIN EXECUTION COMPLETE` — placeholders below are **not** valid until broadcast):

| Contract | Address / status |
|----------|------------------|
| Factory | *Pending funded deploy* — target file: `deployments/base-sepolia.env` |
| Sample market | *Pending funded deploy* |
| Mock USDC | *Pending funded deploy* |
| `START_BLOCK` (subgraph) | First Factory tx block on Basescan |

### 22.4 Production-style verification on Anvil (`Deploy.s.sol`)

Used for §19 post-deploy screenshot (`VerifyPostDeploy.s.sol`). Requires **`MarketGovernor`** (from `Deploy.s.sol`, not `deploy-anvil.sh`):

| Contract | Address (example — one Anvil `Deploy.s.sol` run) |
|----------|-----------------------------------------------------|
| Factory | `0xf5059a5D33d5853360D16C683c16e67980206f36` |
| Governor (`MarketGovernor`) | `0x851356ae760d987E095750cCeb3bC6014560891C` |
| Timelock | `0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9` |
| Sample market | `0x55652FF92Dc17a21AD6810Cce2F4703fa2339CAE` |

```bash
export TIMELOCK=0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9
export GOVERNOR=0x851356ae760d987E095750cCeb3bC6014560891C
export FACTORY=0xf5059a5D33d5853360D16C683c16e67980206f36
forge script scripts/VerifyPostDeploy.s.sol --rpc-url http://127.0.0.1:8545 -vv
# Expected log: Post-deploy verification: OK
```

### 22.5 CI / DevOps

| Step | Command / location |
|------|-------------------|
| Workflow | `.github/workflows/ci.yml` |
| Repository | `https://github.com/ako667/block4` |
| Local equivalent | `forge fmt --check && forge build && forge test -vv` (117 passed, 3 fork skipped) |
| Frontend gate | `cd frontend && npm ci && npm run build` |

---

## 23. Known Gaps Before Defense (Transparency)

| Item | Status | Action |
|------|--------|--------|
| Base Sepolia verified addresses | Pending | Fund wallet → `./scripts/deploy-base-sepolia.sh` → Basescan verify → §22.3 |
| Subgraph on `base-sepolia` | Deployed on Goldsky | Re-deploy with real `FACTORY` + `start-block` after testnet broadcast |
| Public Vercel URL | Pending | Deploy `frontend/dist`; until then use `http://localhost:5173` |
| Fork tests (3) | Skipped offline | Run with RPC in `.env` or document skip |
| README "in progress" text | Outdated | Use this report + `CHECKLIST.md` |

---

## CONCLUSION

This capstone delivers a **production-style on-chain prediction market** with custom CPMM economics, multi-standard token architecture (ERC-1155, ERC-4626, ERC-20Votes), Chainlink-aware resolution, timelocked DAO governance, UUPS upgrades, factory-based scaling, The Graph indexing scaffold, a Wagmi-powered frontend, and a rigorous Foundry test and CI pipeline.

Every section above includes a **screenshot placeholder** and an **Evidence** paragraph explaining what that image must prove to a grader. Replace each `[INSERT SCREENSHOT: ...]` with your actual capture from Cursor, terminal, MetaMask, Basescan, Infura, The Graph Studio, and GitHub Actions before PDF export.

---

## APPENDIX A — COMMANDS FOR REPRODUCING EVIDENCE

```bash
# Build
cd prediction-market && forge build

# All tests
forge test

# Coverage
forge coverage --report summary

# Local stack
anvil
./scripts/deploy-anvil.sh
cd frontend && npm run dev

# Base Sepolia RPC
cast chain-id --rpc-url base_sepolia

# Deploy testnet (when funded)
source .env
forge script scripts/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify
```

---

## APPENDIX B — DEPLOYED ADDRESSES (FILL AFTER TESTNET)

| Contract | Base Sepolia address |
|----------|----------------------|
| Factory | `[INSERT]` |
| GovernanceToken (PMT) | `[INSERT]` |
| Governor | `[INSERT]` |
| Timelock | `[INSERT]` |
| Sample market | `[INSERT]` |
| GlobalOutcomeShares | `[INSERT]` |
| LPVault | `[INSERT]` |

---

*End of report — Blockchain Technologies 2, Option D — Aktoty Omar, SE-2432*
