// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FeeVault — ERC-4626 vault for protocol LP fee accrual
contract FeeVault is ERC4626, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant FEE_COLLECTOR_ROLE = keccak256("FEE_COLLECTOR_ROLE");

    uint256 public totalFeesCollected;

    event FeesDeposited(address indexed from, uint256 amount);

    constructor(IERC20 asset_, address admin)
        ERC4626(asset_)
        ERC20("Prediction Market Fee Vault", "pmFEE")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEE_COLLECTOR_ROLE, admin);
    }

    /// @notice Collect swap fees from markets (pull pattern)
    function depositFees(uint256 amount) external onlyRole(FEE_COLLECTOR_ROLE) nonReentrant {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        totalFeesCollected += amount;
        emit FeesDeposited(msg.sender, amount);
    }

    function grantCollector(address collector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(FEE_COLLECTOR_ROLE, collector);
    }
}
