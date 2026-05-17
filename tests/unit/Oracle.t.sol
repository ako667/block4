// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {ChainlinkAdapter} from "../../contracts/oracle/ChainlinkAdapter.sol";

contract OracleTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_LatestPrice() public view {
        (int256 p, uint256 ts) = adapter.latestValidatedPrice();
        assertGt(p, 0);
        assertGt(ts, 0);
    }

    function test_IsStale_False() public view {
        assertFalse(adapter.isStale());
    }

    function test_IsStale_True() public {
        vm.warp(block.timestamp + STALENESS + 100);
        feed.setUpdatedAt(block.timestamp - STALENESS - 10);
        assertTrue(adapter.isStale());
    }

    function test_Stale_Reverts() public {
        vm.warp(block.timestamp + STALENESS + 100);
        feed.setUpdatedAt(block.timestamp - STALENESS - 10);
        vm.expectRevert();
        adapter.latestValidatedPrice();
    }

    function test_Paused_Reverts() public {
        vm.prank(admin);
        adapter.setPaused(true);
        vm.expectRevert(ChainlinkAdapter.FeedPaused.selector);
        adapter.latestValidatedPrice();
    }

    function test_SetMaxStaleness() public {
        vm.prank(admin);
        adapter.setMaxStaleness(7200);
        assertEq(adapter.maxStaleness(), 7200);
    }

    function test_InvalidPrice() public {
        feed.setAnswer(0);
        vm.expectRevert(ChainlinkAdapter.InvalidPrice.selector);
        adapter.latestValidatedPrice();
    }
}
