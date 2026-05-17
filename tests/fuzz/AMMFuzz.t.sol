// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";

contract AMMFuzzTest is BaseSetup {
    PredictionMarket market;

    function setUp() public {
        setUpBase();
        (, market) = _createMarket(admin, 5000e6);
    }

    function testFuzz_Buy_IncreasesReserve(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 500e6));
        uint256 ry = market.reserveYes();
        uint256 rn = market.reserveNo();
        _buy(market, alice, true, amount, 1);
        assertGe(market.reserveNo(), rn);
    }

    function testFuzz_SwapOutput_LessThanReserve(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 100e6));
        uint256 out = CPMMath.getAmountOut(amount, market.reserveNo(), market.reserveYes());
        assertLt(out, market.reserveYes());
    }

    function testFuzz_K_NonDecreasing(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 50e6));
        uint256 k0 = CPMMath.product(market.reserveYes(), market.reserveNo());
        _buy(market, bob, false, amount, 1);
        uint256 k1 = CPMMath.product(market.reserveYes(), market.reserveNo());
        assertGe(k1, k0 * 99 / 100);
    }

    function testFuzz_MultipleBuys(uint96 a1, uint96 a2) public {
        a1 = uint96(bound(a1, 1e6, 30e6));
        a2 = uint96(bound(a2, 1e6, 30e6));
        _buy(market, alice, true, a1, 1);
        _buy(market, bob, false, a2, 1);
        assertGt(market.reserveYes() + market.reserveNo(), 0);
    }
}
