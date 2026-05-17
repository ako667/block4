// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PredictionMarket} from "./PredictionMarket.sol";

/// @title PredictionMarketV2 — documented V1 → V2 upgrade (extended metadata)
contract PredictionMarketV2 is PredictionMarket {
    string public resolutionSource;
    uint256 public maxTradeSize;

    function initializeV2(string calldata source, uint256 maxTrade) external reinitializer(2) {
        resolutionSource = source;
        maxTradeSize = maxTrade;
    }

    function version() external pure override returns (string memory) {
        return "2.0.0";
    }

    function setMaxTradeSize(uint256 maxTrade) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTradeSize = maxTrade;
    }
}
