// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketGovernor} from "./MarketGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @notice Anvil-only governor: instant proposals for frontend demos
contract LocalMarketGovernor is MarketGovernor {
    constructor(IVotes token_, TimelockController timelock_) MarketGovernor(token_, timelock_) {}

    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 45_000;
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
    }
}
