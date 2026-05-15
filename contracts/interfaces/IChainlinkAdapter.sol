// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChainlinkAdapter {
    function latestValidatedPrice() external view returns (int256 price, uint256 updatedAt);
    function isStale() external view returns (bool);
    function maxStaleness() external view returns (uint256);
}
