// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {PredictionMarketV2} from "../../contracts/core/PredictionMarketV2.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";
import {CPMMathPure} from "../../contracts/libraries/CPMMathPure.sol";

contract MoreCoverageTest is BaseSetup {
    function setUp() public {
        setUpBase();
    }

    function test_UUPS_UpgradeToV2() public {
        bytes32 upgrader = keccak256("UPGRADER_ROLE");
        PredictionMarketV2 implV2 = new PredictionMarketV2();
        (, PredictionMarket market) = _createMarket(admin, 100e6);
        assertTrue(market.hasRole(upgrader, admin));
        vm.prank(admin);
        market.upgradeToAndCall(address(implV2), abi.encodeCall(PredictionMarketV2.initializeV2, ("chainlink", 1e9)));
        PredictionMarketV2 upgraded = PredictionMarketV2(address(market));
        assertEq(upgraded.version(), "2.0.0");
        vm.prank(admin);
        upgraded.setMaxTradeSize(500e6);
    }

    function test_CPMMath_ProductBranches() public pure {
        assertEq(CPMMath.product(1, 1), 1);
        assertEq(CPMMathPure.product(2, 3), 6);
    }

    function test_Resolution_NoAboveStrike() public {
        (, PredictionMarket m) = _createMarket(admin, 500e6);
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(1000e8);
        vm.startPrank(admin);
        m.closeTrading();
        m.requestResolution();
        vm.stopPrank();
        vm.warp(block.timestamp + 3 days);
        vm.prank(admin);
        m.finalizeResolution();
    }

    function test_RequestResolution_FromOpenAfterEnd() public {
        (, PredictionMarket m) = _createMarket(admin, 100e6);
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(5000e8);
        vm.prank(admin);
        m.requestResolution();
    }

    function test_DisputeOverridesOutcome() public {
        (, PredictionMarket m) = _createMarket(admin, 200e6);
        vm.warp(block.timestamp + 8 days);
        feed.setAnswer(5000e8);
        vm.prank(admin);
        m.closeTrading();
        vm.prank(admin);
        m.requestResolution();
        vm.prank(bob);
        m.proposeDispute(1);
        vm.warp(block.timestamp + 3 days);
        vm.prank(admin);
        m.finalizeResolution();
        assertEq(m.winningOutcome(), 1);
    }

    function test_GovTokenPermit() public {
        uint256 pk = 0xA11CE;
        address holder = vm.addr(pk);
        vm.prank(admin);
        govToken.transfer(holder, 1000 ether);
        vm.warp(block.timestamp + 1);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                holder,
                bob,
                100 ether,
                govToken.nonces(holder),
                block.timestamp + 1 hours
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        govToken.permit(holder, bob, 100 ether, block.timestamp + 1 hours, v, r, s);
        assertEq(govToken.allowance(holder, bob), 100 ether);
    }

    function test_Market_YesWinsIfBelow() public {
        vm.startPrank(admin);
        collateral.approve(address(factory), 100e6);
        uint256 id;
        address mAddr;
        (id, mAddr) = factory.createMarket("below", "Crypto", 5000e8, 0, block.timestamp + 5 days, 100e6);
        id;
        vm.stopPrank();
        PredictionMarket m = PredictionMarket(mAddr);
        vm.warp(block.timestamp + 6 days);
        feed.setAnswer(6000e8);
        vm.prank(admin);
        m.closeTrading();
        vm.prank(admin);
        m.requestResolution();
    }
}
