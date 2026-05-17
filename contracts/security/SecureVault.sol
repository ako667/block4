// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev Fixed vault — Checks-Effects-Interactions + ReentrancyGuard
contract SecureVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public balances;
    IERC20 public token;

    constructor(address token_) {
        token = IERC20(token_);
    }

    function deposit(uint256 amount) external nonReentrant {
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "insufficient");
        balances[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);
    }
}
