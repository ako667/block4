// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IChainlinkAdapter} from "../interfaces/IChainlinkAdapter.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/// @title ChainlinkAdapter — price feed with mandatory staleness check
contract ChainlinkAdapter is IChainlinkAdapter, AccessControl {
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    AggregatorV3Interface public immutable feed;
    uint256 public maxStaleness;
    bool public paused;

    error StalePrice(uint256 updatedAt, uint256 maxAllowed);
    error FeedPaused();
    error InvalidPrice();

    event StalenessUpdated(uint256 oldMax, uint256 newMax);
    event FeedPausedSet(bool paused);

    constructor(address feed_, uint256 maxStaleness_, address admin) {
        feed = AggregatorV3Interface(feed_);
        maxStaleness = maxStaleness_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
    }

    function setMaxStaleness(uint256 newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit StalenessUpdated(maxStaleness, newMax);
        maxStaleness = newMax;
    }

    function setPaused(bool p) external onlyRole(EMERGENCY_ROLE) {
        paused = p;
        emit FeedPausedSet(p);
    }

    function isStale() public view returns (bool) {
        (,,, uint256 updatedAt,) = feed.latestRoundData();
        return block.timestamp - updatedAt > maxStaleness;
    }

    function latestValidatedPrice() external view returns (int256 price, uint256 updatedAt) {
        if (paused) revert FeedPaused();
        (, int256 answer,, uint256 feedUpdatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (block.timestamp - feedUpdatedAt > maxStaleness) {
            revert StalePrice(feedUpdatedAt, maxStaleness);
        }
        return (answer, feedUpdatedAt);
    }
}
