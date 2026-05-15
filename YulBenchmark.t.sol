// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CPMMath} from "../../contracts/libraries/CPMMath.sol";
import {CPMMathPure} from "../../contracts/libraries/CPMMathPure.sol";

contract YulBenchmarkTest is Test {
    function test_Gas_YulVsPure() public {
        uint256 gasYul;
        uint256 gasPure;
        uint256 amountIn = 100e6;
        uint256 rIn = 1000e6;
        uint256 rOut = 1000e6;

        uint256 g0 = gasleft();
        CPMMath.getAmountOut(amountIn, rIn, rOut);
        gasYul = g0 - gasleft();

        g0 = gasleft();
        CPMMathPure.getAmountOut(amountIn, rIn, rOut);
        gasPure = g0 - gasleft();

        emit log_named_uint("gas_yul", gasYul);
        emit log_named_uint("gas_pure", gasPure);
        assertEq(CPMMath.getAmountOut(amountIn, rIn, rOut), CPMMathPure.getAmountOut(amountIn, rIn, rOut));
    }
}
