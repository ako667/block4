# Security Audit Report (Internal)

**Protocol:** On-Chain Prediction Market  
**Date:** May 2026  
**Scope commit:** `HEAD` on `prediction-market/`  
**Auditors:** Team (course capstone)  

---

## Executive summary

The protocol implements binary prediction markets with a custom CPMM, Chainlink-based resolution, ERC-4626 fee vault, and OpenZeppelin Governor timelock. Core swap and claim paths use **Checks-Effects-Interactions** and **ReentrancyGuard**. **Slither** is run in CI with filters for `lib/` and test mocks.

No **Critical** or **High** issues remain in production `src/` at submission. Two **case studies** (reentrancy, access control) demonstrate fixed patterns with before/after tests.

---

## Scope

**In scope:**  
`src/core/*`, `src/oracle/*`, `src/vault/*`, `src/tokens/*`, `src/governance/*`, `src/libraries/*`

**Out of scope:**  
`src/security/Vulnerable*.sol` (intentional vulnerable teaching contracts), `src/mocks/*`, frontend, subgraph hosting.

---

## Methodology

- Static analysis: **Slither** (`slither.config.json`)
- Manual review: trust model, governance, oracle staleness, upgrade storage
- Dynamic: **Foundry** unit/fuzz/invariant/fork tests (109+ tests)
- Tools: forge coverage `--ir-minimum`, forge fmt

---

## Findings summary

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| S-01 | Medium | Reentrancy in withdraw (case study) | Fixed in `SecureVault` |
| S-02 | Medium | Unguarded `setFee` (case study) | Fixed in `SecureAdmin` |
| S-03 | Low | LP mint approximation dust | Acknowledged |
| S-04 | Informational | Centralized resolver role | Acknowledged |
| S-05 | Gas | Yul vs Solidity math | Optimized |

---

## Detailed findings

### S-01 — Reentrancy in vault withdraw (case study)

- **Severity:** Medium (demonstration)  
- **Location:** `src/security/VulnerableVault.sol:20-26`  
- **Description:** External call before balance update allows reentrant withdraw.  
- **Impact:** Double-spend of accounting balance.  
- **PoC:** `test_Reentrancy_Vulnerable_DoubleSpend` in `SecurityCaseStudies.t.sol`  
- **Recommendation:** CEI + `ReentrancyGuard`; use `SafeERC20`.  
- **Status:** Fixed in `SecureVault.sol` — `test_Reentrancy_Secure_NoDrain` passes.

### S-02 — Missing access control on admin setter (case study)

- **Severity:** Medium (demonstration)  
- **Location:** `src/security/VulnerableAdmin.sol:14-16`  
- **Description:** Any address may call `setFee`.  
- **Impact:** Parameter griefing / fee drain configuration.  
- **PoC:** `test_AccessControl_Vulnerable_AnyoneSetsFee`  
- **Recommendation:** `AccessControl` with `PARAM_ROLE`.  
- **Status:** Fixed in `SecureAdmin.sol`.

### S-03 — LP mint rounding

- **Severity:** Low  
- **Location:** `PredictionMarket._addLiquidityInternal`  
- **Description:** Simplified pro-rata LP mint may leave dust for tiny deposits.  
- **Impact:** Minor LP unfairness at edge sizes.  
- **Recommendation:** Use full Uniswap-v2 style `sqrt(k)` mint or minimum liquidity lock.  
- **Status:** Acknowledged for testnet scope.

### S-04 — Resolver centralization

- **Severity:** Informational  
- **Location:** `RESOLVER_ROLE`, `requestResolution`  
- **Description:** Trusted resolver triggers oracle read and dispute window start.  
- **Impact:** Malicious resolver could propose wrong outcome; mitigated by **2-day dispute window** and DAO governance over roles.  
- **Status:** Acknowledged — production would use Chainlink Automation + governance.

### S-05 — Gas: Yul CPMM math

- **Severity:** Gas  
- **Location:** `CPMMath.sol`  
- **Description:** Inline assembly for mul/div in swap hot path.  
- **Impact:** Lower gas vs `CPMMathPure`.  
- **Status:** Benchmarked in `YulBenchmarkTest`.

---

## Centralization analysis

| Actor | Powers | Compromise impact |
|-------|--------|-------------------|
| Timelock | Execute governance, own factory admin | Delayed malicious upgrade/create |
| Resolver | Close market, request/finalize resolution | Wrong outcome if dispute ignored |
| DEFAULT_ADMIN | Emergency pause | Trading halt |
| Oracle feed | Price data | Stale/wrong price — mitigated by `maxStaleness` revert |

Treasury (fee vault) owned by protocol; governor may propose fee parameter changes via timelock.

---

## Governance attack analysis

| Attack | Mitigation |
|--------|------------|
| Flash-loan vote | `ERC20Votes` uses past checkpoints; no flash mint in token |
| Whale vote | 4% quorum + 1 week voting period |
| Proposal spam | 1% threshold (10k PMT) |
| Timelock bypass | All privileged factory calls routed through governor executor |

---

## Oracle attack analysis

| Attack | Mitigation |
|--------|------------|
| Stale price | `ChainlinkAdapter.latestValidatedPrice` reverts `StalePrice` |
| Manipulated spot | Uses Chainlink aggregator, not spot DEX |
| Feed depeg | Governance can `setPaused` / update `maxStaleness` |

---

## Slither appendix

Run locally:

```bash
slither . --config-file slither.config.json --filter-paths "lib|test|mocks"
```

CI runs `crytic/slither-action` on `src/`. Production contracts target **0 Medium, 0 High** at submission. Vulnerable case-study contracts excluded via filter.

---

## Checklist (course requirements)

- [x] CEI / ReentrancyGuard on external calls  
- [x] AccessControl on privileged functions  
- [x] SafeERC20 for token transfers  
- [x] No `tx.origin` / unsafe ETH `transfer`  
- [x] Staleness check on oracle  
- [x] Two case studies with tests  

---

*End of report — ~8 pages when printed with Slither log appendix.*
