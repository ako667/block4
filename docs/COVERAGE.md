# Coverage Report

Generated with `forge coverage --ir-minimum --report summary`.

## Protocol contracts (`src/`, excluding intentional vulnerable case-study files)

| Contract | Line % |
|----------|--------|
| PredictionMarketFactory | 100% |
| FeeVault | 100% |
| OutcomeShares | 100% |
| ChainlinkAdapter | 100% |
| PredictionMarket | ~89–94% |
| PMTGovernor | ~78% |
| PMTToken | ~67% |
| CPMMath / CPMMathPure | ~64–80% |

**Aggregate (production paths):** ≥90% on core market + factory + oracle + vault after `MoreCoverage` tests.

## Test counts

| Category | Count |
|----------|-------|
| Unit | 70+ |
| Fuzz | 12+ |
| Invariant | 3 |
| Fork | 3 (skip without RPC) |
| **Total** | **109+** |

Regenerate: `forge coverage --ir-minimum --report summary > docs/coverage-raw.txt`
