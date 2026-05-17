// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPredictionMarket {
    enum MarketState {
        Open,
        TradingClosed,
        ResolutionRequested,
        DisputeWindow,
        Resolved,
        EmergencyPaused
    }

    event LiquidityAdded(address indexed provider, uint256 collateral, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 collateral, uint256 lpBurned);
    event OutcomeBought(address indexed trader, uint8 outcomeId, uint256 amountIn, uint256 amountOut);
    event OutcomeSold(address indexed trader, uint8 outcomeId, uint256 amountIn, uint256 amountOut);
    event ResolutionProposed(uint8 winningOutcome, int256 oraclePrice);
    event DisputeProposed(address indexed disputer, uint8 proposedOutcome);
    event MarketResolved(uint8 winningOutcome);
    event WinningsClaimed(address indexed account, uint256 amount);
    event EmergencyBrakeActivated(address indexed activator, string reason);

    function marketState() external view returns (MarketState);
    function reserveYes() external view returns (uint256);
    function reserveNo() external view returns (uint256);
    function winningOutcome() external view returns (uint8);
}
