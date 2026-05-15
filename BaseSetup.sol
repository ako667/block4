// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockV3Aggregator} from "../../contracts/mocks/MockV3Aggregator.sol";
import {ChainlinkAdapter} from "../../contracts/oracle/ChainlinkAdapter.sol";
import {MarketOracle} from "../../contracts/oracle/MarketOracle.sol";
import {LPVault} from "../../contracts/vault/LPVault.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {PredictionMarketFactory} from "../../contracts/core/PredictionMarketFactory.sol";
import {GlobalOutcomeShares} from "../../contracts/tokens/GlobalOutcomeShares.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {MarketGovernor} from "../../contracts/governance/MarketGovernor.sol";

abstract contract BaseSetup is Test {
    MockERC20 internal collateral;
    MockV3Aggregator internal feed;
    ChainlinkAdapter internal adapter;
    MarketOracle internal marketOracle;
    LPVault internal lpVault;
    GlobalOutcomeShares internal outcomeShares;
    PredictionMarket internal implementation;
    PredictionMarketFactory internal factory;
    GovernanceToken internal govToken;
    TimelockController internal timelock;
    MarketGovernor internal governor;

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal lp = makeAddr("lp");

    uint256 internal constant INITIAL_MINT = 10_000_000e6;
    uint256 internal constant STALENESS = 3600;

    function setUpBase() internal {
        vm.startPrank(admin);
        collateral = new MockERC20("Mock USDC", "USDC", 6);
        feed = new MockV3Aggregator(3_500e8, 8);
        adapter = new ChainlinkAdapter(address(feed), STALENESS, admin);
        marketOracle = new MarketOracle(address(adapter), admin);
        lpVault = new LPVault(collateral, admin);
        outcomeShares = new GlobalOutcomeShares(admin);
        implementation = new PredictionMarket();
        timelock = new TimelockController(2 days, _singleton(admin), _singleton(admin), admin);
        govToken = new GovernanceToken(admin);
        governor = new MarketGovernor(govToken, timelock);
        factory = new PredictionMarketFactory(
            address(implementation),
            address(outcomeShares),
            address(collateral),
            address(adapter),
            address(lpVault),
            admin,
            address(timelock),
            address(marketOracle)
        );
        outcomeShares.grantRole(outcomeShares.DEFAULT_ADMIN_ROLE(), address(factory));
        marketOracle.grantRole(marketOracle.DEFAULT_ADMIN_ROLE(), address(factory));
        lpVault.grantCollector(address(factory));
        govToken.delegate(admin);
        vm.roll(block.number + 1);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), admin);
        vm.stopPrank();

        collateral.mint(alice, INITIAL_MINT);
        collateral.mint(bob, INITIAL_MINT);
        collateral.mint(lp, INITIAL_MINT);
        collateral.mint(admin, INITIAL_MINT);
    }

    function _singleton(address a) private pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    function _createMarket(address creator, uint256 liquidity)
        internal
        returns (uint256 marketId, PredictionMarket market)
    {
        vm.startPrank(creator);
        if (liquidity > 0) collateral.approve(address(factory), liquidity);
        address mAddr;
        (marketId, mAddr) = factory.createMarket(
            "ETH above 4000 by Friday?", "Crypto", 4_000e8, 1, block.timestamp + 7 days, liquidity
        );
        vm.stopPrank();
        market = PredictionMarket(mAddr);
    }

    function _buy(PredictionMarket market, address user, bool isYes, uint256 amountIn, uint256 minOut) internal {
        vm.startPrank(user);
        collateral.approve(address(market), amountIn);
        market.swap(isYes, amountIn, minOut);
        vm.stopPrank();
    }
}
