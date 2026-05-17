// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureAdmin is AccessControl {
    bytes32 public constant PARAM_ROLE = keccak256("PARAM_ROLE");
    uint256 public feeBps;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PARAM_ROLE, admin);
    }

    function setFee(uint256 bps) external onlyRole(PARAM_ROLE) {
        require(bps <= 1000, "max 10%");
        feeBps = bps;
    }
}
