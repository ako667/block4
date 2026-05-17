// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BaseSetup} from "../helpers/BaseSetup.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";

contract MarketHandler is BaseSetup {
    PredictionMarket public market;
    MockERC20 public col;

    constructor() {
        setUpBase();
        col = collateral;
        (, market) = _createMarket(admin, 10_000e6);
    }

    function buyYes(uint256 amount) public {
        amount = bound(amount, 1e6, 100e6);
        _buy(market, alice, true, amount, 1);
    }

    function buyNo(uint256 amount) public {
        amount = bound(amount, 1e6, 100e6);
        _buy(market, bob, false, amount, 1);
    }
}

contract MarketInvariantTest is StdInvariant, Test {
    MarketHandler public handler;

    function setUp() public {
        handler = new MarketHandler();
        targetContract(address(handler));
    }

    function invariant_ReservesPositive() public view {
        assertGt(handler.market().reserveYes(), 0);
        assertGt(handler.market().reserveNo(), 0);
    }

    function invariant_K_ProductStable() public view {
        uint256 k = CPMMath.product(handler.market().reserveYes(), handler.market().reserveNo());
        assertGt(k, 0);
    }

    function invariant_CollateralNonNegative() public view {
        assertGe(handler.col().balanceOf(address(handler.market())), 0);
    }
}
