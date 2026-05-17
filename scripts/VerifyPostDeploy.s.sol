// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {MarketGovernor} from "../contracts/governance/MarketGovernor.sol";
import {PredictionMarketFactory} from "../contracts/core/PredictionMarketFactory.sol";

contract VerifyPostDeployScript is Script {
    function run() external view {
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");
        address factoryAddr = vm.envAddress("FACTORY");

        TimelockController timelock = TimelockController(payable(timelockAddr));
        MarketGovernor governor = MarketGovernor(payable(governorAddr));
        PredictionMarketFactory factory = PredictionMarketFactory(factoryAddr);

        require(timelock.getMinDelay() == 2 days, "timelock delay");
        require(governor.votingDelay() == 7200, "voting delay");
        require(governor.votingPeriod() == 50400, "voting period");
        require(governor.proposalThreshold() == 10_000 ether, "threshold");
        require(factory.timelock() == timelockAddr, "factory timelock");

        console2.log("Post-deploy verification: OK");
    }
}
