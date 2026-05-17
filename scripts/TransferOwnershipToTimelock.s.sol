// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PredictionMarketFactory} from "../contracts/core/PredictionMarketFactory.sol";

/// @notice Transfers factory admin roles to timelock (post-deploy step)
contract TransferOwnershipToTimelockScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address factoryAddr = vm.envAddress("FACTORY");
        address timelock = vm.envAddress("TIMELOCK");

        PredictionMarketFactory factory = PredictionMarketFactory(factoryAddr);
        bytes32 admin = factory.DEFAULT_ADMIN_ROLE();
        bytes32 creator = factory.MARKET_CREATOR_ROLE();

        vm.startBroadcast(pk);
        factory.grantRole(creator, timelock);
        factory.grantRole(admin, timelock);
        factory.revokeRole(creator, vm.addr(pk));
        factory.revokeRole(admin, vm.addr(pk));
        vm.stopBroadcast();

        console2.log("Factory ownership transferred to timelock", timelock);
    }
}
