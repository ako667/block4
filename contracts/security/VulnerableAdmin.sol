// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Intentionally vulnerable — unguarded admin (case study). DO NOT DEPLOY.
contract VulnerableAdmin {
    address public owner;
    uint256 public feeBps;

    constructor() {
        owner = msg.sender;
    }

    function setFee(uint256 bps) external {
        feeBps = bps;
    }
}
