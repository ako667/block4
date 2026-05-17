// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";

contract LPVaultTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_DepositWithdraw_ERC4626() public {
        vm.startPrank(alice);
        collateral.approve(address(lpVault), 1000e6);
        uint256 shares = lpVault.deposit(500e6, alice);
        assertGt(shares, 0);
        lpVault.withdraw(100e6, alice, alice);
        vm.stopPrank();
    }

    function test_DepositFees() public {
        vm.prank(admin);
        lpVault.grantCollector(bob);
        collateral.mint(bob, 100e6);
        vm.startPrank(bob);
        collateral.approve(address(lpVault), 50e6);
        lpVault.depositFees(50e6);
        vm.stopPrank();
        assertEq(lpVault.totalFeesCollected(), 50e6);
    }

    function test_OnlyCollectorDepositsFees() public {
        collateral.mint(alice, 10e6);
        vm.startPrank(alice);
        collateral.approve(address(lpVault), 10e6);
        vm.expectRevert();
        lpVault.depositFees(10e6);
        vm.stopPrank();
    }

    function testFuzz_DepositRoundTrip(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 1_000_000e6));
        collateral.mint(alice, amount);
        vm.startPrank(alice);
        collateral.approve(address(lpVault), amount);
        uint256 shares = lpVault.deposit(amount, alice);
        uint256 assets = lpVault.redeem(shares, alice, alice);
        assertApproxEqAbs(assets, amount, 2);
        vm.stopPrank();
    }
}
