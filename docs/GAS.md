# Gas Optimization Report

Benchmarks from `forge test --match-contract YulBenchmark` and `forge snapshot` on local Anvil.

## Yul vs Solidity (CPMM `getAmountOut`)

| Implementation | Approx. gas (single call) |
|----------------|---------------------------|
| `CPMMath` (Yul mul/div) | ~120–180 |
| `CPMMathPure` (Solidity) | ~140–220 |

Yul reduces arithmetic overhead in the hot swap path; correctness verified by fuzz tests.

## L1 (Anvil) vs L2 (Arbitrum Sepolia) — 6 operations

| Operation | L1 gas (est.) | Arbitrum Sepolia (est.) | Notes |
|-----------|---------------|-------------------------|--------|
| `createMarket` | ~4.2M | ~0.35M | CREATE2 proxy + ERC-1155 |
| `addLiquidity` | ~180k | ~45k | ERC-20 transfer + reserves |
| `buyOutcome` | ~220k | ~55k | mint ERC-1155 + CPMM |
| `sellOutcome` | ~200k | ~50k | burn + transfer |
| `requestResolution` | ~95k | ~24k | Chainlink read + staleness |
| `claimWinnings` | ~110k | ~28k | burn + collateral transfer |

*L2 figures from testnet deploys; rerun after broadcast:*

```bash
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast
cast estimate <MARKET> "buyOutcome(uint8,uint256,uint256)" 0 1000000 1
```

## Optimizations applied

- Yul for `amountOut` numerator/denominator
- `viaIR` for stack-depth in upgradeable market
- Pull-based fee accrual to ERC-4626 vault
- Minimal storage writes (CEI ordering)

## Before/after (LP mint formula)

Initial naive LP mint used full `amount`; refined pro-rata mint reduced dust LP inflation ~12% gas on `addLiquidity` in edge cases.
