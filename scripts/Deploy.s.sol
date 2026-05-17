// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {MockV3Aggregator} from "../contracts/mocks/MockV3Aggregator.sol";
import {ChainlinkAdapter} from "../contracts/oracle/ChainlinkAdapter.sol";
import {MarketOracle} from "../contracts/oracle/MarketOracle.sol";
import {LPVault} from "../contracts/vault/LPVault.sol";
import {GlobalOutcomeShares} from "../contracts/tokens/GlobalOutcomeShares.sol";
import {PredictionMarket} from "../contracts/core/PredictionMarket.sol";
import {PredictionMarketFactory} from "../contracts/core/PredictionMarketFactory.sol";
import {GovernanceToken} from "../contracts/governance/GovernanceToken.sol";
import {MarketGovernor} from "../contracts/governance/MarketGovernor.sol";

contract DeployScript is Script {
    function run() external {
        // Pass key via: forge script ... --private-key 0x...  (no PRIVATE_KEY in .env required)
        vm.startBroadcast();
        address deployer = msg.sender;

        MockERC20 usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        usdc.mint(deployer, 10_000_000e6);
        MockV3Aggregator feed = new MockV3Aggregator(3_500e8, 8);
        ChainlinkAdapter adapter = new ChainlinkAdapter(address(feed), 3600, deployer);
        MarketOracle marketOracle = new MarketOracle(address(adapter), deployer);
        LPVault lpVault = new LPVault(usdc, deployer);
        GlobalOutcomeShares shares = new GlobalOutcomeShares(deployer);
        PredictionMarket impl = new PredictionMarket();

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(2 days, proposers, executors, deployer);

        GovernanceToken token = new GovernanceToken(deployer);
        MarketGovernor governor = new MarketGovernor(token, timelock);
        PredictionMarketFactory factory = new PredictionMarketFactory(
            address(impl),
            address(shares),
            address(usdc),
            address(adapter),
            address(lpVault),
            deployer,
            address(timelock),
            address(marketOracle)
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        lpVault.grantCollector(address(factory));
        token.delegate(deployer);

        usdc.approve(address(factory), 2_000e6);
        (uint256 sampleMarketId, address sampleMarket) = factory.createMarket(
            "Will ETH exceed $5000 on testnet?",
            "crypto",
            5_000e8,
            1,
            block.timestamp + 30 days,
            1_000e6
        );

        vm.stopBroadcast();

        console2.log("USDC", address(usdc));
        console2.log("OutcomeShares", address(shares));
        console2.log("Factory", address(factory));
        console2.log("Governor", address(governor));
        console2.log("Timelock", address(timelock));
        console2.log("PMT", address(token));
        console2.log("MarketOracle", address(marketOracle));
        console2.log("SampleMarketId", sampleMarketId);
        console2.log("SampleMarket", sampleMarket);
    }
}
