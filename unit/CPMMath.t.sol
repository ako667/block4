// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";
import {CPMMathPure} from "../../contracts/libraries/CPMMathPure.sol";

contract CPMMathWrapper {
    function amountOut(uint256 a, uint256 rIn, uint256 rOut) external pure returns (uint256) {
        return CPMMath.getAmountOut(a, rIn, rOut);
    }

    function quote(uint256 out, uint256 min) external pure {
        CPMMath.quoteMinOut(out, min);
    }
}

contract CPMMathTest is Test {
    CPMMathWrapper wrapper = new CPMMathWrapper();

    function test_GetAmountOut_MatchesPure() public pure {
        uint256 outYul = CPMMath.getAmountOut(100e6, 1000e6, 1000e6);
        uint256 outPure = CPMMathPure.getAmountOut(100e6, 1000e6, 1000e6);
        assertEq(outYul, outPure);
    }

    function test_GetAmountOut_ZeroReverts() public {
        vm.expectRevert(CPMMath.ZeroAmount.selector);
        wrapper.amountOut(0, 100, 100);
    }

    function test_GetAmountOut_NoLiquidityReverts() public {
        vm.expectRevert(CPMMath.InsufficientLiquidity.selector);
        wrapper.amountOut(1, 0, 100);
    }

    function test_Product() public pure {
        assertEq(CPMMath.product(100, 200), 20000);
    }

    function test_QuoteMinOut_Reverts() public {
        vm.expectRevert(CPMMath.InsufficientOutput.selector);
        wrapper.quote(5, 10);
    }

    function testFuzz_AmountOut_Positive(uint256 amountIn, uint256 rIn, uint256 rOut) public {
        vm.assume(amountIn > 0 && rIn > 0 && rOut > 0);
        amountIn = bound(amountIn, 1, type(uint64).max);
        rIn = bound(rIn, 1, type(uint64).max);
        rOut = bound(rOut, 1, type(uint64).max);
        uint256 out = CPMMath.getAmountOut(amountIn, rIn, rOut);
        vm.assume(out > 0);
        assertLt(out, rOut);
    }
}
