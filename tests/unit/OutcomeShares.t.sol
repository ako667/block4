// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GlobalOutcomeShares} from "../../contracts/tokens/GlobalOutcomeShares.sol";

contract OutcomeSharesTest is Test {
    GlobalOutcomeShares shares;
    address admin = makeAddr("admin");
    address engine = makeAddr("engine");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.startPrank(admin);
        shares = new GlobalOutcomeShares(admin);
        shares.grantMarketEngine(engine);
        vm.stopPrank();
    }

    function test_TokenIds_Market1() public view {
        assertEq(shares.yesTokenId(1), 1);
        assertEq(shares.noTokenId(1), 2);
    }

    function test_TokenIds_Market2() public view {
        assertEq(shares.yesTokenId(2), 3);
        assertEq(shares.noTokenId(2), 4);
    }

    function test_MintBurn() public {
        vm.prank(engine);
        shares.mint(alice, 1, 100);
        assertEq(shares.balanceOf(alice, 1), 100);
        vm.prank(engine);
        shares.burn(alice, 1, 40);
        assertEq(shares.balanceOf(alice, 1), 60);
    }

    function test_OnlyMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        shares.mint(alice, 1, 1);
    }
}
