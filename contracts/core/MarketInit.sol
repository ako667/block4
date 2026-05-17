// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct MarketInitParams {
    uint256 marketId;
    address collateral;
    address outcomes;
    address oracle;
    address feeVault;
    address factory;
    address admin;
    string question;
    int256 strikePrice;
    uint8 yesWinsIfAbove;
    uint256 endTime;
}
