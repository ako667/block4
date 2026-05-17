// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IChainlinkAdapter} from "../interfaces/IChainlinkAdapter.sol";

/// @dev Day-1 stub oracle for Member 1 push (replaced by ChainlinkAdapter on Day 2)
contract MockOracleAdapter is IChainlinkAdapter {
    int256 public price;
    uint256 public maxStaleness = 3600;

    constructor(int256 initialPrice) {
        price = initialPrice;
    }

    function setPrice(int256 p) external {
        price = p;
    }

    function latestValidatedPrice() external view returns (int256, uint256) {
        return (price, block.timestamp);
    }

    function isStale() external pure returns (bool) {
        return false;
    }
}
