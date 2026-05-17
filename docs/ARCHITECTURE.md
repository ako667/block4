# Architecture & Design Document

**Project:** On-Chain Prediction Market (Option D)  
**Stack:** Foundry, OpenZeppelin 5, The Graph, React/Wagmi, Arbitrum Sepolia  

---

## 1. System context (C4 Level 1)

```
                    ┌─────────────┐
                    │   Traders   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   ┌──────────┐    ┌────────────┐    ┌──────────────┐
   │  dApp    │    │  Wallets   │    │  DAO voters  │
   └────┬─────┘    └─────┬──────┘    └──────┬───────┘
        │                │                   │
        └────────────────┼───────────────────┘
                         ▼
              ┌──────────────────────┐
              │ Prediction Market    │
              │ Protocol (L2)        │
              └──────────┬───────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
 ┌────────────┐   ┌─────────────┐  ┌────────────┐
 │ Chainlink  │   │ The Graph   │  │ Collateral │
 │ Price Feed │   │ Subgraph    │  │ (USDC)     │
 └────────────┘   └─────────────┘  └────────────┘
```

Users interact via the dApp or directly with contracts. Governance controls factory permissions and protocol parameters through a timelocked governor.

---

## 2. Container diagram

| Container | Responsibility |
|-----------|----------------|
| `PredictionMarketFactory` | CREATE / CREATE2 deployment of market proxies |
| `PredictionMarket` (UUPS) | CPMM trading, liquidity, lifecycle state machine |
| `OutcomeShares` (ERC-1155) | YES=0 / NO=1 shares per market |
| `FeeVault` (ERC-4626) | LP fee aggregation |
| `ChainlinkAdapter` | Staleness-checked oracle reads |
| `PMTToken` | ERC20Votes + Permit governance token |
| `PMTGovernor` + `TimelockController` | Propose → vote → queue → execute |
| Subgraph | Index `MarketCreated`, trades, resolution |
| Frontend | Wagmi wallet, on-chain writes, GraphQL reads |

**Proxy layout:** Each market is `ERC1967Proxy` → `PredictionMarket` implementation. Upgrades authorized by `UPGRADER_ROLE` (intended: Timelock).

**Access control roles:**

| Role | Holder | Capability |
|------|--------|------------|
| `MARKET_CREATOR_ROLE` | Timelock / admin | Create markets |
| `RESOLVER_ROLE` | Admin / oracle bot | Close trading, resolve |
| `UPGRADER_ROLE` | Timelock | UUPS upgrade |
| `DEFAULT_ADMIN_ROLE` | Timelock | Grant/revoke roles, emergency brake |

---

## 3. Sequence diagrams

### 3.1 Buy YES (CPMM swap)

```
Trader -> USDC.approve(market)
Trader -> market.buyOutcome(0, amountIn, minOut)
  market: transfer USDC, CPMMath.getAmountOut, update reserves
  market -> OutcomeShares.mint(trader, YES, amountOut)
  market -> FeeVault.depositFees (optional)
```

### 3.2 Governance: propose → execute

```
Proposer -> Governor.propose(...)
Voters -> Governor.castVote (after votingDelay blocks)
Anyone -> Governor.queue (if Succeeded)
Wait Timelock delay (2 days)
Executor -> Governor.execute -> Timelock.executeBatch -> Factory.createMarket
```

### 3.3 Resolution & claim

```
Resolver -> market.closeTrading (after endTime)
Resolver -> market.requestResolution()
  -> ChainlinkAdapter.latestValidatedPrice() [reverts if stale]
  -> state = DisputeWindow (2 days)
Optional: user.proposeDispute
Resolver -> finalizeResolution()
Winner -> claimWinnings() [CEI: burn shares, transfer collateral]
```

---

## 4. State machine (market lifecycle)

```
Open → TradingClosed → DisputeWindow → Resolved
  ↘ EmergencyPaused (circuit breaker)
```

---

## 5. Storage layout (upgradeable market)

| Slot | Variable | Notes |
|------|----------|-------|
| OZ init | AccessControl, ReentrancyGuard, Pausable, ERC1967 | OZ gap reserved |
| app | `collateral`, `outcomes`, `oracle`, `feeVault` | immutable refs set once |
| AMM | `reserveYes`, `reserveNo`, `totalLPSupply` | CPMM reserves |
| lifecycle | `marketState`, `winningOutcome`, `resolutionProposedAt` | resolution |
| V2 (new) | `resolutionSource`, `maxTradeSize` | append-only in V2 |

**V1 → V2:** No reordering of V1 slots; V2 adds fields at end. `PredictionMarketV2` uses `reinitializer(2)`.

---

## 6. Trust assumptions

- **Timelock** controls factory creation and upgrades; 2-day delay limits instant malicious upgrades.
- **Oracle:** Chainlink feed assumed honest; staleness bound limits expired prices.
- **Admin / resolver:** Can pause and propose resolution; dispute window allows social challenge before finalize.
- **No `tx.origin` auth;** no block.timestamp randomness.

---

## 7. Design patterns (documented)

1. **Factory** — CREATE + CREATE2 markets  
2. **UUPS proxy** — upgradeable market logic  
3. **Checks-Effects-Interactions** — swaps, claims, vault  
4. **Pull payments** — `claimWinnings`, fee vault deposits  
5. **AccessControl** — all privileged functions  
6. **Pausable / circuit breaker** — `activateEmergencyBrake`  
7. **State machine** — `MarketState` enum  
8. **Oracle adapter** — `ChainlinkAdapter` interface  
9. **Timelock** — governance execution delay  
10. **ReentrancyGuard** — external entrypoints  

---

## 8. ADRs

**ADR-001: CPMM vs LMSR**  
*Context:* Need on-chain pricing. *Decision:* CPMM `x·y=k` with 0.3% fee (course spec). *Consequence:* simpler liquidity, known DeFi UX.

**ADR-002: ERC-1155 outcomes**  
*Context:* Binary shares. *Decision:* tokenId 0/1 per market contract. *Consequence:* efficient batch transfers.

**ADR-003: Block-based governor clock**  
*Context:* ERC20Votes uses block numbers. *Decision:* 7200 / 50400 blocks ≈ 1 day / 1 week. *Consequence:* aligns OpenZeppelin examples.

---

## 9. Team ownership

See root `README.md` table.
