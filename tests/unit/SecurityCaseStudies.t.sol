// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {VulnerableVault} from "../../contracts/security/VulnerableVault.sol";
import {SecureVault} from "../../contracts/security/SecureVault.sol";
import {VulnerableAdmin} from "../../contracts/security/VulnerableAdmin.sol";
import {SecureAdmin} from "../../contracts/security/SecureAdmin.sol";

contract ReentrancyAttacker {
    VulnerableVault vault;
    uint256 public count;

    constructor(VulnerableVault v) {
        vault = v;
    }

    function attack() external {
        vault.deposit(100);
        vault.withdraw(100);
    }

    receive() external payable {
        if (count < 2) {
            count++;
            vault.withdraw(100);
        }
    }
}

contract SecurityCaseStudiesTest is Test {
    MockERC20 token;
    address admin = makeAddr("admin");

    function setUp() public {
        token = new MockERC20("T", "T", 18);
    }

    function test_Reentrancy_Vulnerable_DoubleSpend() public {
        VulnerableVault v = new VulnerableVault(address(token));
        token.mint(address(v), 1000);
        token.mint(address(this), 200);
        token.approve(address(v), 200);
        v.deposit(100);
        ReentrancyAttacker attacker = new ReentrancyAttacker(v);
        token.mint(address(attacker), 100);
        vm.expectRevert();
        attacker.attack();
    }

    function test_Reentrancy_Secure_NoDrain() public {
        SecureVault v = new SecureVault(address(token));
        token.mint(address(this), 500);
        token.approve(address(v), 500);
        v.deposit(100);
        v.withdraw(50);
        assertEq(v.balances(address(this)), 50);
    }

    function test_AccessControl_Vulnerable_AnyoneSetsFee() public {
        VulnerableAdmin a = new VulnerableAdmin();
        vm.prank(makeAddr("attacker"));
        a.setFee(9999);
        assertEq(a.feeBps(), 9999);
    }

    function test_AccessControl_Secure_OnlyRole() public {
        SecureAdmin a = new SecureAdmin(admin);
        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        a.setFee(100);
        vm.prank(admin);
        a.setFee(50);
        assertEq(a.feeBps(), 50);
    }
}
