// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Mock Chainlink-style aggregator for tests
contract MockV3Aggregator {
    int256 public answer;
    uint8 public decimals;
    uint256 public updatedAt;
    uint80 public roundId;

    constructor(int256 initialAnswer, uint8 aggDecimals) {
        answer = initialAnswer;
        decimals = aggDecimals;
        updatedAt = block.timestamp;
        roundId = 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }

    function setAnswer(int256 newAnswer) external {
        answer = newAnswer;
        updatedAt = block.timestamp;
        roundId += 1;
    }

    function setUpdatedAt(uint256 ts) external {
        updatedAt = ts;
    }
}
