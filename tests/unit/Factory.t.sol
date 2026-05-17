// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";

contract FactoryTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_CreateMarket_IncrementsCount() public {
        _createMarket(admin, 100e6);
        assertEq(factory.marketCount(), 1);
    }

    function test_CreateMarketDeterministic_SameSaltSameAddress() public {
        bytes32 salt = keccak256(abi.encodePacked("eth-4000", block.timestamp));
        vm.startPrank(admin);
        collateral.approve(address(factory), 200e6);
        uint256 id;
        address m1;
        (id, m1) = factory.createMarketDeterministic(
            "Q1", "Crypto", 4000e8, 1, block.timestamp + 1 days, 100e6, salt
        );
        vm.stopPrank();
        assertTrue(m1 != address(0));
        assertEq(id, 1);
        assertEq(factory.marketBySalt(salt), m1);
    }

    function test_PredictMarketAddress() public view {
        bytes memory initData = hex"00";
        bytes32 salt = bytes32(uint256(1));
        address predicted = factory.predictMarketAddress(salt, initData);
        assertTrue(predicted != address(0));
    }

    function test_OnlyCreatorCanCreate() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.createMarket("x", "Crypto", 1, 1, block.timestamp + 1, 0);
    }

    function test_MultipleMarkets() public {
        _createMarket(admin, 50e6);
        _createMarket(admin, 50e6);
        assertEq(factory.marketCount(), 2);
        assertEq(outcomeShares.yesTokenId(2), 3);
    }
}
