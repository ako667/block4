
On-Chain Prediction Market
Course: Blockchain Technologies 2 — Final Project
Students: Daniyal Sadykov, Aktoty Omar, Akerke Kuan
Scenario: Option D — On-Chain Prediction Market
Status: Day 1 complete (foundation & core primitives)

Binary prediction market protocol with a custom CPMM (x·y=k), ERC-1155 outcome shares, ERC-4626 LP vault, Chainlink resolution, DAO governance, UUPS upgrades, The Graph subgraph, and a React + Wagmi dApp.

Days 2–3 (market engine, oracle, governance, frontend) will be added in follow-up commits.

Team
Member	Area	Day 1 focus
Member 1	Core & AMM	Foundry setup, CPMM math (Yul), project config
Member 2	Tokens & interfaces	ERC-1155, interfaces, mocks, proxy scaffold, CPMM tests
Member 3	Vault & CI	ERC-4626 vaults, test harness, CI, checklist
Day 1 — Git submissions
Commits are pushed in order: Member 1 → Member 2 → Member 3.

Member 1
chore: init foundry project with CPMM math libraries

- Add foundry.toml, remappings, slither config, and gitignore
- Add CPMMath and CPMMathPure libraries (Yul mulDiv)
- Add initial README for prediction market protocol
Files (9):

Path
foundry.toml
foundry.lock
remappings.txt
slither.config.json
.gitignore
.gitmodules
contracts/libraries/CPMMath.sol
contracts/libraries/CPMMathPure.sol
README.md
Member 2
feat: add outcome tokens, interfaces, mocks, and proxy scaffold

- Add IChainlinkAdapter and IPredictionMarket interfaces
- Add MockERC20, MockV3Aggregator, and MockOracleAdapter
- Add GlobalOutcomeShares and OutcomeShares ERC-1155
- Add MarketProxy and CPMMath unit tests
Files (9):

Path
contracts/interfaces/IChainlinkAdapter.sol
contracts/interfaces/IPredictionMarket.sol
contracts/mocks/MockERC20.sol
contracts/mocks/MockV3Aggregator.sol
contracts/mocks/MockOracleAdapter.sol
contracts/tokens/GlobalOutcomeShares.sol
contracts/tokens/OutcomeShares.sol
contracts/proxy/MarketProxy.sol
tests/unit/CPMMath.t.sol
Member 3
feat: add LP vault, test harness, and CI workflow

- Add LPVault and FeeVault (ERC-4626 pmLP)
- Add BaseSetup test helper and OutcomeShares tests
- Add Yul benchmark test and project CHECKLIST
- Add frontend env example and GitHub Actions CI
Files (8):

Path
contracts/vault/LPVault.sol
contracts/vault/FeeVault.sol
tests/helpers/BaseSetup.sol
tests/unit/OutcomeShares.t.sol
tests/benchmark/YulBenchmark.t.sol
CHECKLIST.md
frontend/.env.example
.github/workflows/ci.yml
Repository layout (after Day 1)
prediction-market/
├── contracts/
│   ├── interfaces/       # IChainlinkAdapter, IPredictionMarket
│   ├── libraries/        # CPMMath (Yul), CPMMathPure
│   ├── mocks/            # MockERC20, MockV3Aggregator, MockOracleAdapter
│   ├── tokens/           # GlobalOutcomeShares, OutcomeShares (ERC-1155)
│   ├── vault/            # LPVault, FeeVault (ERC-4626 pmLP)
│   └── proxy/            # MarketProxy (UUPS wrapper)
├── tests/
│   ├── helpers/          # BaseSetup.sol
│   ├── unit/             # CPMMath.t.sol, OutcomeShares.t.sol
│   └── benchmark/        # YulBenchmark.t.sol
├── frontend/
│   └── .env.example
├── .github/workflows/    # CI (forge build + tests)
├── foundry.toml
├── remappings.txt
├── slither.config.json
└── CHECKLIST.md
Outcome token IDs (global ERC-1155):

Market	YES	NO
1	1	2
2	3	4
Quick start (Day 1)
Prerequisites
Foundry
Git
Install & build
git clone <your-repo-url>
cd prediction-market
forge install
forge build
Run Day 1 tests
forge test --match-path tests/unit/CPMMath.t.sol
forge test --match-path tests/unit/OutcomeShares.t.sol
forge test --match-path tests/benchmark/YulBenchmark.t.sol
Format check (CI)
forge fmt --check

