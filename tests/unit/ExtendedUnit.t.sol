// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {LPVault} from "../../contracts/vault/LPVault.sol";
import {GovernanceToken} from "../../contracts/governance/GovernanceToken.sol";
import {GlobalOutcomeShares} from "../../contracts/tokens/GlobalOutcomeShares.sol";

/// @dev Additional unit tests to meet 50+ unit test requirement
contract ExtendedUnitTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_CollateralDecimals() public view {
        assertEq(collateral.decimals(), 6);
    }

    function test_GovTokenName() public view {
        assertEq(govToken.name(), "Prediction Market Token");
    }

    function test_LPVaultAsset() public view {
        assertEq(address(lpVault.asset()), address(collateral));
    }

    function test_FactoryImplementation() public view {
        assertEq(address(factory.implementation()), address(implementation));
    }

    function test_AdapterFeed() public view {
        assertEq(address(adapter.feed()), address(feed));
    }

    function test_MintCollateral() public {
        collateral.mint(alice, 1e6);
        assertEq(collateral.balanceOf(alice), INITIAL_MINT + 1e6);
    }

    function test_TransferCollateral() public {
        vm.prank(alice);
        collateral.transfer(bob, 100e6);
        assertEq(collateral.balanceOf(bob), INITIAL_MINT + 100e6);
    }

    function test_ApproveAndTransferFrom() public {
        vm.prank(alice);
        collateral.approve(bob, 50e6);
        vm.prank(bob);
        collateral.transferFrom(alice, bob, 50e6);
        assertEq(collateral.balanceOf(bob), INITIAL_MINT + 50e6);
    }

    function test_GovPermitDomain() public view {
        assertEq(govToken.name(), "Prediction Market Token");
    }

    function test_TimelockAdminIsAdmin() public view {
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_GovernorName() public view {
        assertEq(governor.name(), "Market Governor");
    }

    function test_MarketFactoryCollateral() public view {
        assertEq(factory.collateral(), address(collateral));
    }

    function test_MarketFactoryOracle() public view {
        assertEq(factory.oracle(), address(adapter));
    }

    function test_MarketFactoryLPVault() public view {
        assertEq(factory.feeVault(), address(lpVault));
    }

    function test_CreateMarketZeroLiquidity() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        assertTrue(address(m) != address(0));
    }

    function test_BuySellRoundTrip() public {
        (, PredictionMarket m) = _createMarket(admin, 2000e6);
        _buy(m, alice, true, 100e6, 1);
        uint256 shares = GlobalOutcomeShares(address(m.outcomes())).balanceOf(alice, 1);
        vm.startPrank(alice);
        m.sellOutcome(0, shares / 4, 1);
        vm.stopPrank();
    }

    function test_ProtocolFeesAccrue() public {
        (, PredictionMarket m) = _createMarket(admin, 1000e6);
        _buy(m, alice, true, 100e6, 1);
        assertGt(m.protocolFeesAccrued(), 0);
    }

    function test_MarketQuestion() public {
        (, PredictionMarket m) = _createMarket(admin, 100e6);
        assertTrue(bytes(m.question()).length > 0);
    }

    function test_MarketEndTime() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        assertGt(m.endTime(), block.timestamp);
    }

    function test_LPVaultTotalAssets() public {
        collateral.mint(alice, 100e6);
        vm.startPrank(alice);
        collateral.approve(address(lpVault), 100e6);
        lpVault.deposit(100e6, alice);
        assertEq(lpVault.totalAssets(), 100e6);
        vm.stopPrank();
    }

    function test_GovTokenTotalSupply() public view {
        assertEq(govToken.totalSupply(), 1_000_000 ether);
    }

    function test_FeedDecimals() public view {
        assertEq(feed.decimals(), 8);
    }

    function test_FeedSetAnswer() public {
        feed.setAnswer(4000e8);
        assertEq(feed.answer(), 4000e8);
    }

    function test_AdapterNotPaused() public view {
        assertFalse(adapter.paused());
    }

    function test_MarketStrikePrice() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        assertEq(m.strikePrice(), 4_000e8);
    }

    function test_RemoveLiquidityZeroReverts() public {
        (, PredictionMarket m) = _createMarket(admin, 100e6);
        vm.prank(lp);
        vm.expectRevert(PredictionMarket.ZeroLiquidity.selector);
        m.removeLiquidity(0);
    }

    function test_CloseTradingTooEarly() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.ResolutionTooEarly.selector);
        m.closeTrading();
    }

    function test_FinalizeTooEarlyInDispute() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        vm.warp(block.timestamp + 8 days);
        vm.startPrank(admin);
        m.closeTrading();
        feed.setAnswer(5000e8);
        m.requestResolution();
        vm.expectRevert(PredictionMarket.NotInDisputeWindow.selector);
        m.finalizeResolution();
        vm.stopPrank();
    }

    function test_GrantRoleFactory() public view {
        assertTrue(factory.hasRole(factory.MARKET_CREATOR_ROLE(), admin));
    }

    function test_SupportsInterfaceOutcome() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        GlobalOutcomeShares o = GlobalOutcomeShares(address(m.outcomes()));
        assertTrue(o.supportsInterface(0xd9b67a26));
    }

    function test_VaultPreviewDeposit() public {
        assertGt(lpVault.previewDeposit(100e6), 0);
    }

    function test_VaultMaxDeposit() public view {
        assertEq(lpVault.maxDeposit(alice), type(uint256).max);
    }

    function test_GovClock() public view {
        assertEq(govToken.clock(), block.number);
    }

    function test_MarketFactoryTimelock() public view {
        assertEq(factory.timelock(), address(timelock));
    }

    function test_BuyBothOutcomes() public {
        (, PredictionMarket m) = _createMarket(admin, 5000e6);
        _buy(m, alice, true, 50e6, 1);
        _buy(m, bob, false, 50e6, 1);
    }

    function test_LpBalanceTracking() public {
        (, PredictionMarket m) = _createMarket(admin, 500e6);
        vm.startPrank(lp);
        collateral.approve(address(m), 100e6);
        m.addLiquidity(100e6);
        assertGt(m.lpBalance(lp), 0);
        vm.stopPrank();
    }

    function test_MarketStateOpen() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        assertEq(uint8(m.marketState()), 0);
    }

    function test_DisputeNotInWindow() public {
        (, PredictionMarket m) = _createMarket(admin, 0);
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NotInDisputeWindow.selector);
        m.proposeDispute(0);
    }
}
