// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ChainlinkAdapter} from "./ChainlinkAdapter.sol";

interface IPredictionMarketEngine {
    function closeTrading() external;
    function requestResolution() external;
    function marketState() external view returns (uint8);
}

/// @title MarketOracle — Chainlink resolution entrypoint per marketId
contract MarketOracle is AccessControl {
    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");

    ChainlinkAdapter public immutable adapter;
    mapping(uint256 marketId => address) public marketById;

    event MarketRegistered(uint256 indexed marketId, address indexed market);
    event MarketResolved(uint256 indexed marketId, int256 price);

    constructor(address adapter_, address admin) {
        adapter = ChainlinkAdapter(adapter_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RESOLVER_ROLE, admin);
    }

    function registerMarket(uint256 marketId, address market) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marketById[marketId] = market;
        emit MarketRegistered(marketId, market);
    }

    /// @notice Resolve market via Chainlink with staleness check (3600s default on adapter)
    function resolveMarket(uint256 marketId) external onlyRole(RESOLVER_ROLE) {
        address market = marketById[marketId];
        require(market != address(0), "unknown market");
        (int256 price,) = adapter.latestValidatedPrice();
        IPredictionMarketEngine(market).closeTrading();
        IPredictionMarketEngine(market).requestResolution();
        emit MarketResolved(marketId, price);
    }
}
