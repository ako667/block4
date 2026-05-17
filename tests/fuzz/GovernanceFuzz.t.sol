// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";

contract GovernanceFuzzTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function testFuzz_Delegate_IncreasesVotes(uint96 amount) public {
        amount = uint96(bound(amount, 1 ether, 100_000 ether));
        vm.prank(admin);
        govToken.transfer(alice, amount);
        vm.prank(alice);
        govToken.delegate(alice);
        assertEq(govToken.getVotes(alice), amount);
    }

    function testFuzz_Transfer_ReducesBalance(uint96 amount) public {
        amount = uint96(bound(amount, 1 ether, 10_000 ether));
        uint256 before = govToken.balanceOf(admin);
        vm.prank(admin);
        govToken.transfer(bob, amount);
        assertEq(govToken.balanceOf(admin), before - amount);
    }
}
