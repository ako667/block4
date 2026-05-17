# Defense presentation script (with report screenshots)

**Source report:** `Blockchain Technologies 2 Implementation Report.pdf` (28 pages)  
**Repo:** https://github.com/ako667/block4  
**Format:** dense slides — **no IDE code screenshots**; only terminal, browser, MetaMask, dashboards, diagrams.  
**Speaker time:** ~12–15 minutes (≈1 min per slide)

**Layout tip:** each slide = **left column bullets** + **right column 2–4 small screenshots** from the report PDF.

---

## Slide 1 — Title & project identity

### On slide

**On-Chain Prediction Market**  
Blockchain Technologies 2 — Final Term  

**Team:** Aktoty Omar · Daniyal Sadykov · Akerke Kuan — **SE-2432**  
**Scenario:** Option D — Decentralized Binary Prediction Market  

**GitHub:** github.com/ako667/block4  

### Speaker says

Мы реализовали полноценный on-chain prediction market: торговля исходами YES/NO через CPMM, ликвидность в ERC-4626 vault, разрешение через Chainlink с dispute window, управление через OpenZeppelin Governor + Timelock. PMT — токен голосования, не валюта ставок.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Optional footer | Cover table (page 1) — repo, Base Sepolia, local demo URLs |

---

## Slide 2 — Technology stack (everything we used)

### On slide

| Layer | Technologies |
|-------|----------------|
| **Contracts** | Solidity **0.8.24**, **Foundry**, OpenZeppelin (UUPS, Governor, Timelock) |
| **L2 testnet** | **Base Sepolia** (chain **84532**) |
| **RPC** | **Infura** (`BASE_SEPOLIA_RPC_URL`) |
| **Local chain** | **Anvil** `127.0.0.1:8545` (chain **31337**) |
| **Wallet** | **MetaMask** |
| **Frontend** | **React 18**, **Vite**, **Wagmi**, **Viem** |
| **Indexing** | Subgraph schema + **Goldsky** on `base-sepolia` |
| **Oracle** | **Chainlink-style** feed + staleness guard (mock locally) |
| **QA** | **117** Foundry tests, fuzz, invariants, **Slither**, `audit/AUDIT.md` |
| **CI** | `.github/workflows/ci.yml` |

### Speaker says

Стек закрывает курс: L2 deploy, oracle, DAO, subgraph, dApp, тесты и audit. Локально — Anvil и один скрипт deploy; testnet — Infura и Base Sepolia.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Top-right | **foundry.toml** snippet *or* terminal **forge build** success (report p.3) |
| Bottom-right | **MetaMask Base Sepolia** network (report p.16) |

---

## Slide 3 — System architecture (how it fits together)

### On slide

**Flow:** User → **MetaMask** → **React dApp** → **Infura / Anvil RPC** → **Factory & Market proxies** → **ERC-1155 shares** + **LPVault**  

**Off-chain:** contract events → **subgraph (Goldsky)** → GraphQL → Markets list in UI  

**Governance:** **PMT** holders → **Governor** → **Timelock (2 days)** → parameter / factory actions  

**Resolution:** trading closes → **oracle** → **48h dispute** → winners **claim**  

### Speaker says

Один factory создаёт множество рынков. Все рынки делят global ERC-1155. Subgraph не заменяет блокчейн — ускоряет чтение истории рынков.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Main | **System context diagram** (report p.27 — ARCHITECTURE) |
| Small | **Container diagram** Factory → MarketProxy → CPMM / ERC1155 / LPVault / Governor (report p.27) |

---

## Slide 4 — Core protocol (what we built on-chain)

### On slide

- **CPMM** — constant product `x·y = k`, swap fee **0.3%** (`swapFeeBps = 30`)  
- **PredictionMarketFactory** — `createMarket` + **CREATE2** deterministic addresses  
- **Global ERC-1155** — YES/NO token IDs per market (`2n−1`, `2n`)  
- **LPVault (ERC-4626)** — **pmLP** shares, protocol fees via `depositFees`  
- **UUPS upgrades** — `MarketProxy` + guarded implementation  
- **PMT** — `ERC20Votes` + **Permit** (1M supply) — **governance only**  
- Trading collateral: **USDC / WETH** — **not PMT**

### Speaker says

Это ответ на Option D: AMM, multi-token standards, factory, upgrades. Ставки идут коллатералом; PMT — для голосования.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Left stack | Terminal **Yul vs Pure gas benchmark** (report p.10) |
| Right | Terminal **PlanChecklistTest** passing (report p.15) |

*Do not use IDE code pages 7–12 on this slide.*

---

## Slide 5 — Oracle, lifecycle & security of settlement

### On slide

- **ChainlinkAdapter** — rejects stale prices (`maxStaleness`, e.g. **3600s**)  
- **MarketOracle** — `resolveMarket(marketId)` per registered market  
- **Lifecycle:** Open → TradingClosed → **DisputeWindow (48h)** → Resolved  
- **Emergency pause** on market  
- **Tests prove** stale feed → revert on resolution  

### Speaker says

Без свежего oracle цена не принимается. Dispute window защищает от мгновенного финала спорного исхода.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Main | Terminal **test_Oracle_RevertIfPriceStale** / stale oracle test (report p.14) |
| Optional | **PlanChecklist** — resolve via oracle (report p.15) |

---

## Slide 6 — Local development (Anvil end-to-end)

### On slide

1. `anvil` — local RPC **8545**, chain **31337**  
2. `./scripts/deploy-anvil.sh` — full stack + demo **governance proposal**  
3. Auto **`frontend/.env`** — `VITE_*` addresses, `VITE_PAY_WITH_ETH=true`  
4. `npm run dev` → **http://localhost:5173**  
5. **LocalMarketGovernor** — instant **Active** proposals for UI demo  

### Speaker says

Один скрипт поднимает всё для защиты без testnet ETH: trade, delegate, vote.

### Screenshots (grid 2×2)

| # | From report PDF |
|---|-----------------|
| 1 | **Anvil running** (report p.4) |
| 2 | **deploy-anvil.sh** success + proposal id (report p.5) |
| 3 | **frontend/.env** with VITE_* (report p.6) |
| 4 | Optional: **forge build** OK (report p.3) |

---

## Slide 7 — Frontend dApp & MetaMask (trading path)

### On slide

- **Connect / Disconnect** wallet  
- **Wrong network** banner → switch **Anvil**  
- **Wallet & governance** — ETH balance, PMT, voting power, proposal state  
- **Trade** — `0.01 ETH` → **Buy YES shares (pay ETH)** → `buyOutcomeWithEth`  
- Stack: **Wagmi + Viem** (not Ethers.js)  

### Speaker says

Показываем, что UI реально вызывает контракты, а не mock API.

### Screenshots (grid 2×2)

| # | From report PDF |
|---|-----------------|
| 1 | **dApp home — wallet connected** (report PART I — §17) |
| 2 | **Wrong network banner** |
| 3 | **ETH amount + Buy YES** |
| 4 | **MetaMask — 0.01 ETH confirmed** |

*Add 5th small: balance after tx — if space on next line.*

---

## Slide 8 — Governance in the UI + tests

### On slide

- **Delegate PMT** → voting power &gt; 0  
- **Proposal #id — Active**  
- **Vote FOR** — `castVote` (0 ETH, only gas)  
- On-chain params (**MarketGovernor**): delay **7200**, period **50400**, quorum **4%**, threshold **10 000 PMT**, timelock **2 days**  
- E2E test: **propose → vote → queue → execute**  

### Speaker says

ERC20Votes требует delegate — UI это проводит. Timelock задерживает исполнение после голосования.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Top | **Delegate + Proposal Active + Vote FOR** (report §18) |
| Bottom left | **MetaMask castVote confirmed** |
| Bottom right | **GovernanceTest — test_ProposeVoteQueueExecute** (report p.19) |

*Optional: Governor parameters slide (report p.17) — text only, no code IDE.*

---

## Slide 9 — Base Sepolia & Infura (L2 deployment path)

### On slide

- **Primary L2:** Base Sepolia via **Infura**  
- `cast chain-id` → **84532**  
- Deploy script: `./scripts/deploy-base-sepolia.sh` → `Deploy.s.sol`  
- **MarketGovernor** (production params, not Local)  
- **Post-deploy:** `VerifyPostDeploy.s.sol` → `Post-deploy verification: OK`  
- **Explorer:** sepolia.basescan.org  

*Status line (choose one):*  
- ✅ *If deployed:* Factory verified on Basescan  
- ⏳ *If pending:* Infrastructure ready; live addresses after funded broadcast  

### Speaker says

Infura — production-grade RPC. Verification script проверяет timelock, governor constants и factory→timelock wiring.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| 1 | **MetaMask Base Sepolia** (p.16) |
| 2 | **cast chain-id 84532** |
| 3 | **Infura dashboard** requests (p.16) |
| 4 | **VerifyPostDeploy OK** (report PART J §20) *or* deploy broadcast success when available |

---

## Slide 10 — Gas & L1 vs L2 economics

### On slide

- Gas measured with **`cast estimate`** / deploy logs  
- **L2 (Base Sepolia)** — lower cost per `buyOutcome` vs L1 narrative  
- Optimizer + **Yul CPMM** reduce hot-path gas  
- *Table: L1 vs L2 gas matrix from Part D §10*

### Speaker says

Метрики подтверждают, зачем L2 для prediction market с частыми сделками.

### Screenshots — **you will add**

| Place | From report PDF |
|-------|-----------------|
| Main | **Part D §10 — gas optimization matrix** (report p.16–17 area) — *insert when ready* |
| Side | **Yul benchmark terminal** (p.10) as supporting evidence |

---

## Slide 11 — Subgraph & indexed markets (Goldsky)

### On slide

- **Schema:** Market, Trade, LiquidityPosition, Resolution, ProtocolStats  
- **Events:** `MarketCreated`, `OutcomeBought`, `LiquidityAdded`, `MarketResolved`  
- **Network:** `base-sepolia`  
- **Host:** **Goldsky** public GraphQL (Graph-compatible; Studio unavailable)  
- Frontend: **Markets (The Graph)** section  

### Speaker says

Subgraph читает события Factory/Markets; UI не сканирует весь chain через RPC.

### Screenshots — **part 14 metrics when ready**

| Place | From report PDF |
|-------|-----------------|
| 1 | **Goldsky / Studio — Synced, entity count** (report p.21) — *add graph when ready* |
| 2 | **Playground query** `markets { question state volume }` (report p.22) |
| 3 | **dApp Markets list populated** (PART I §18 subgraph section) |

*Skip schema.graphql / subgraph.yaml IDE pages.*

---

## Slide 12 — Testing, coverage & quality gates

### On slide

| Suite | Result |
|-------|--------|
| **Full** `forge test` | **117 passed**, 0 failed, **3 fork skipped** (offline RPC) |
| **Fuzz** | AMM *k*, governance |
| **Invariant** | reserves, collateral, *k* stable |
| **Coverage** | core contracts high line coverage (`forge coverage`) |
| **Governance E2E** | propose → vote → queue → execute |

### Speaker says

120 тестов в проекте; fork-тесты Sepolia пропускаются без live RPC — это ожидаемо.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| Large | **forge test — 117 passed** (report p.23) |
| Small top | **AMMFuzz** output (p.24–25) |
| Small bottom | **MarketInvariant** handler table (p.25) |
| Optional | **forge coverage summary** (p.25) |

---

## Slide 13 — Security audit & CI/CD

### On slide

**Security**  
- Internal **audit/AUDIT.md** — findings S-01–S-05  
- **Case studies:** vulnerable vs secure reentrancy & access control  
- **Slither** in CI pipeline  

**CI/CD**  
- `forge fmt --check` → `build` → `test` → `coverage` → Slither → **frontend build**  
- Repo: **github.com/ako667/block4**  

### Speaker says

Уязвимые контракты — учебные; production path с ReentrancyGuard и SafeERC20.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| 1 | **audit/AUDIT.md findings table** (p.20) |
| 2 | **SecurityCaseStudiesTest passed** (p.20) |
| 3 | **Slither** output or **terminal forge test** if no Actions (p.20 / p.26) |
| 4 | **GitHub Actions green** OR local CI terminal (p.26) |

---

## Slide 14 — Environments, results & next steps

### On slide

| Environment | RPC | Frontend | Deploy |
|-------------|-----|----------|--------|
| **Local** | Anvil `:8545` | `localhost:5173` | `deploy-anvil.sh` |
| **Testnet** | Infura Base Sepolia | Vercel *pending* | `deploy-base-sepolia.sh` |
| **CI** | GitHub Ubuntu | `npm run build` | `forge test` |

**Delivered:** CPMM market · ERC-1155/4626 · DAO · oracle · subgraph · dApp · 117 tests · audit  

**Next:** live Base Sepolia verify · Goldsky sync at factory block · Vercel public URL  

### Speaker says

Матрица окружений показывает, что demo локально и production path на L2 согласованы.

### Screenshots

| Place | From report PDF |
|-------|-----------------|
| 1 | **Environment matrix** text/table (report p.28) |
| 2 | Cover page **compliance summary** or checklist (report p.1–2) |

---

## Slide 15 — Thank you / Q&A

### On slide

**Questions?**

**Live demo backup:** Anvil + localhost:5173 — Buy YES · Delegate · Vote  

**Repository:** https://github.com/ako667/block4  

### Screenshots

Optional: team photo or single **dApp connected** screenshot.

---

## Quick map: report PDF page → slide

| Report section | PDF ~page | Use on slide |
|----------------|-----------|--------------|
| Cover / executive summary | 1 | 1, 14 |
| forge build | 3 | 2 |
| Anvil + deploy-anvil + .env | 4–6 | 6 |
| Yul benchmark | 10 | 4, 10 |
| PlanChecklist / oracle tests | 14–15 | 4, 5 |
| MetaMask + Infura + cast | 16 | 2, 9 |
| Gas matrix | 16–17 | **10** *(add graphs)* |
| Governor params (text) | 17 | 8 |
| Frontend + governance tests | 18–19 | 7, 8 |
| Audit + Slither | 20 | 13 |
| Goldsky / query | 21–22 | **11** *(add metrics)* |
| forge test 117 | 23 | 12 |
| Fuzz / invariant / coverage | 24–25 | 12 |
| CI + VerifyPostDeploy | 26 | 9, 13 |
| Architecture + matrix | 27–28 | 3, 14 |

---

## Slides to **exclude** (code-only — not for presentation)

- IDE: `PredictionMarket.sol`, `Factory.sol`, `CPMMath.sol` source (report p.7–12)  
- IDE: `schema.graphql`, `subgraph.yaml` (use Studio/Goldsky + UI instead)  
- IDE: `MarketGovernor.sol` source (use parameter **text** on slide 8)  

---

## Checklist before presenting

- [ ] Slide 10: gas table / graphs inserted (Part D §10)  
- [ ] Slide 11: Goldsky sync % + entity graph (Part G §14)  
- [ ] Slide 9: honest Base Sepolia status (deployed vs pending)  
- [ ] Cover URLs updated if Vercel / Factory live  
- [ ] Rehearse 3 min live demo on Anvil (slides 6–8)  
