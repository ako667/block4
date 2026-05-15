// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title MarketProxy — UUPS proxy wrapper for PredictionMarket engine
/// @dev Factory deploys `new MarketProxy(implementation, initData)` or CREATE2 equivalent bytecode
contract MarketProxy is ERC1967Proxy {
    constructor(address implementation, bytes memory initData) ERC1967Proxy(implementation, initData) {}
}
