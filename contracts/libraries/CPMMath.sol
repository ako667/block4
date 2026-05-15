// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CPMMath — CPMM math with Yul-optimized mulDiv (Uniswap-style)
library CPMMath {
    uint256 internal constant FEE_DENOMINATOR = 1000;
    uint256 internal constant FEE_NUMERATOR = 997; // 0.3% fee

    error ZeroAmount();
    error InsufficientOutput();
    error InsufficientLiquidity();

    /// @notice floor(x * y / d)
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        if (d == 0) revert InsufficientLiquidity();
        assembly ("memory-safe") {
            result := div(mul(x, y), d)
        }
    }

    /// @notice amountOut for constant-product swap with 0.3% fee
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = mulDiv(amountIn, FEE_NUMERATOR, 1);
        uint256 numerator = mulDiv(amountInWithFee, reserveOut, 1);
        uint256 denominator = mulDiv(reserveIn, FEE_DENOMINATOR, 1) + amountInWithFee;
        amountOut = mulDiv(numerator, 1, denominator);
    }

    function product(uint256 x, uint256 y) internal pure returns (uint256 k) {
        assembly ("memory-safe") {
            k := mul(x, y)
        }
    }

    function quoteMinOut(uint256 amountOut, uint256 minOut) internal pure {
        if (amountOut < minOut) revert InsufficientOutput();
    }
}
