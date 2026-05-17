// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PredictionMarket} from "../../contracts/core/PredictionMarket.sol";
import {PredictionMarketV2} from "../../contracts/core/PredictionMarketV2.sol";

contract UpgradeTest is Test {
    function test_V2_VersionString() public {
        PredictionMarketV2 v2 = new PredictionMarketV2();
        assertEq(v2.version(), "2.0.0");
    }
}
