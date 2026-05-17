// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {IPredictionMarket} from "../../contracts/interfaces/IPredictionMarket.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";

contract PredictionMarketTest is BaseSetup {
    PredictionMarket market;
    uint256 marketId;

    function setUp() public {
        setUpBase();
        (marketId, market) = _createMarket(admin, 1000e6);
    }

    function test_InitialReserves() public view {
        assertGt(market.reserveYes(), 0);
        assertGt(market.reserveNo(), 0);
    }

    function test_Version() public view {
        assertEq(market.version(), "1.0.0");
    }

    function test_AddLiquidity() public {
        vm.startPrank(lp);
        collateral.approve(address(market), 500e6);
        market.addLiquidity(500e6);
        vm.stopPrank();
        assertGt(market.lpBalance(lp), 0);
    }

    function test_BuyYes_MintsShares() public {
        _buy(market, alice, true, 100e6, 1);
        assertGt(outcomeShares.balanceOf(alice, 1), 0);
    }

    function test_BuyNo_MintsShares() public {
        _buy(market, alice, false, 100e6, 1);
        assertGt(outcomeShares.balanceOf(alice, 2), 0);
    }

    function test_SellYes_ReturnsCollateral() public {
        _buy(market, alice, true, 200e6, 1);
        uint256 balBefore = collateral.balanceOf(alice);
        uint256 shares = outcomeShares.balanceOf(alice, 1);
        vm.startPrank(alice);
        market.sellOutcome(0, shares / 2, 1);
        vm.stopPrank();
        assertGt(collateral.balanceOf(alice), balBefore);
    }

    function test_Slippage_Reverts() public {
        vm.startPrank(alice);
        collateral.approve(address(market), 100e6);
        vm.expectRevert();
        market.swap(true, 100e6, type(uint256).max);
        vm.stopPrank();
    }

    function test_InvalidOutcome_Reverts() public {
        vm.startPrank(alice);
        collateral.approve(address(market), 10e6);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.buyOutcome(2, 10e6, 0);
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        uint256 lpBal = market.lpBalance(admin);
        assertGt(lpBal, 0);
        vm.prank(admin);
        market.removeLiquidity(lpBal / 4);
    }

    function test_CloseTrading_And_Resolve() public {
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.closeTrading();
        feed.setAnswer(5_000e8);
        vm.prank(admin);
        market.requestResolution();
        assertEq(uint8(market.marketState()), uint8(IPredictionMarket.MarketState.DisputeWindow));
    }

    function test_StaleOracle_Reverts() public {
        vm.warp(block.timestamp + STALENESS + 100);
        feed.setUpdatedAt(block.timestamp - STALENESS - 10);
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.closeTrading();
        vm.prank(admin);
        vm.expectRevert();
        market.requestResolution();
    }

    function test_FinalizeAndClaim() public {
        _buy(market, alice, true, 500e6, 1);
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(5_000e8);
        vm.startPrank(admin);
        market.closeTrading();
        market.requestResolution();
        vm.stopPrank();
        vm.warp(block.timestamp + 3 days);
        vm.prank(admin);
        market.finalizeResolution();
        uint256 before = collateral.balanceOf(alice);
        vm.prank(alice);
        market.claimWinnings();
        assertGt(collateral.balanceOf(alice), before);
    }

    function test_DisputeWindow() public {
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.closeTrading();
        feed.setAnswer(5_000e8);
        vm.prank(admin);
        market.requestResolution();
        vm.prank(bob);
        market.proposeDispute(1);
        assertTrue(true);
    }

    function test_EmergencyBrake() public {
        vm.prank(admin);
        market.activateEmergencyBrake("oracle anomaly");
        assertEq(uint8(market.marketState()), uint8(IPredictionMarket.MarketState.EmergencyPaused));
    }

    function test_KInvariant_OnBuy() public {
        uint256 kBefore = CPMMath.product(market.reserveYes(), market.reserveNo());
        _buy(market, bob, true, 50e6, 1);
        uint256 kAfter = CPMMath.product(market.reserveYes(), market.reserveNo());
        assertGe(kAfter, kBefore * 997 / 1000);
    }

    function test_MarketNotOpenAfterClose() public {
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.closeTrading();
        vm.startPrank(alice);
        collateral.approve(address(market), 10e6);
        vm.expectRevert(PredictionMarket.MarketNotOpen.selector);
        market.swap(true, 10e6, 0);
        vm.stopPrank();
    }

    function test_ClaimWithoutShares_Reverts() public {
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(5_000e8);
        vm.startPrank(admin);
        market.closeTrading();
        market.requestResolution();
        vm.stopPrank();
        vm.warp(block.timestamp + 3 days);
        vm.prank(admin);
        market.finalizeResolution();
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NothingToClaim.selector);
        market.claimWinnings();
    }

    function test_ZeroLiquidity_Reverts() public {
        vm.prank(lp);
        vm.expectRevert(PredictionMarket.ZeroLiquidity.selector);
        market.addLiquidity(0);
    }
}
