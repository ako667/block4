// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CPMMathPure — pure Solidity reference for gas benchmarks vs CPMMath
library CPMMathPure {
    uint256 internal constant FEE_DENOMINATOR = 1000;
    uint256 internal constant FEE_NUMERATOR = 997;

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function product(uint256 x, uint256 y) internal pure returns (uint256) {
        return x * y;
    }
}
