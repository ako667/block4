// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";

/// @dev Named tests matching project plan checklist
contract PlanChecklistTest is BaseSetup {
    PredictionMarket market;
    uint256 marketId;

    function setUp() public {
        setUpBase();
        (marketId, market) = _createMarket(admin, 2000e6);
    }

    function test_Swap_RevertIfSlippageTooHigh() public {
        vm.startPrank(alice);
        collateral.approve(address(market), 100e6);
        vm.expectRevert();
        market.swap(true, 100e6, type(uint256).max);
        vm.stopPrank();
    }

    function test_Oracle_RevertIfPriceStale() public {
        vm.warp(block.timestamp + STALENESS + 100);
        feed.setUpdatedAt(block.timestamp - STALENESS - 10);
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.closeTrading();
        vm.prank(admin);
        vm.expectRevert();
        market.requestResolution();
    }

    function testFuzz_AMM_K_Invariant(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 50e6));
        uint256 k0 = CPMMath.product(market.reserveYes(), market.reserveNo());
        _buy(market, bob, true, amount, 1);
        uint256 k1 = CPMMath.product(market.reserveYes(), market.reserveNo());
        assertGe(k1, k0 * 99 / 100);
    }

    function test_ResolveMarketViaOracle() public {
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(5_000e8);
        vm.prank(admin);
        market.grantRole(keccak256("RESOLVER_ROLE"), address(marketOracle));
        vm.prank(admin);
        marketOracle.resolveMarket(marketId);
        assertEq(uint8(market.marketState()), 3); // DisputeWindow
    }

    function test_GlobalOutcomeIds() public view {
        assertEq(outcomeShares.yesTokenId(marketId), 1);
        assertEq(outcomeShares.noTokenId(marketId), 2);
    }
}
