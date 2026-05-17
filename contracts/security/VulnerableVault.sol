// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Intentionally vulnerable — case study only (reentrancy). DO NOT DEPLOY.
contract VulnerableVault {
    mapping(address => uint256) public balances;
    IERC20 public token;

    constructor(address token_) {
        token = IERC20(token_);
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    // VULNERABLE: state update after external call
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        (bool ok,) = msg.sender.call(abi.encodeWithSignature("receive()"));
        ok;
        token.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
    }
}
