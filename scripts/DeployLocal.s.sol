// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {MockWETH} from "../contracts/mocks/MockWETH.sol";
import {MockV3Aggregator} from "../contracts/mocks/MockV3Aggregator.sol";
import {ChainlinkAdapter} from "../contracts/oracle/ChainlinkAdapter.sol";
import {MarketOracle} from "../contracts/oracle/MarketOracle.sol";
import {LPVault} from "../contracts/vault/LPVault.sol";
import {GlobalOutcomeShares} from "../contracts/tokens/GlobalOutcomeShares.sol";
import {PredictionMarket} from "../contracts/core/PredictionMarket.sol";
import {PredictionMarketFactory} from "../contracts/core/PredictionMarketFactory.sol";
import {GovernanceToken} from "../contracts/governance/GovernanceToken.sol";
import {LocalMarketGovernor} from "../contracts/governance/LocalMarketGovernor.sol";

/// @notice Deploy full stack to local Anvil + write frontend/.env
/// forge script scripts/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract DeployLocalScript is Script {
    function run() external {
            uint256 deployerKey = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        MockWETH weth = new MockWETH();
        MockV3Aggregator feed = new MockV3Aggregator(3_500e8, 8);
        ChainlinkAdapter adapter = new ChainlinkAdapter(address(feed), 3600, deployer);
        MarketOracle marketOracle = new MarketOracle(address(adapter), deployer);
        LPVault lpVault = new LPVault(weth, deployer);
        GlobalOutcomeShares shares = new GlobalOutcomeShares(deployer);
        PredictionMarket impl = new PredictionMarket();

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(2 days, proposers, executors, deployer);

        GovernanceToken token = new GovernanceToken(deployer);
        LocalMarketGovernor governor = new LocalMarketGovernor(token, timelock);
        PredictionMarketFactory factory = new PredictionMarketFactory(
            address(impl),
            address(shares),
            address(weth),
            address(adapter),
            address(lpVault),
            deployer,
            address(timelock),
            address(marketOracle)
        );

        shares.grantRole(shares.DEFAULT_ADMIN_ROLE(), address(factory));
        marketOracle.grantRole(marketOracle.DEFAULT_ADMIN_ROLE(), address(factory));
        lpVault.grantCollector(address(factory));

        uint256 liq = 10 ether;
        weth.deposit{value: liq}();
        weth.approve(address(factory), liq);
        (, address marketAddr) = factory.createMarket(
            "ETH above 4000 by Friday?",
            "Crypto",
            4_000e8,
            1,
            block.timestamp + 7 days,
            liq
        );

        // Demo proposal (LocalMarketGovernor: votingDelay = 0 → Active immediately)
        address[] memory targets = new address[](1);
        targets[0] = marketAddr;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setSwapFeeBps(uint256)", uint256(25));

        // PMT for demo voters (Anvil accounts 0–4)
        address[5] memory voters = [
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3c44CDDd6b9349c716DF4239024A1b9d47DC6b88,
            0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
        ];
        for (uint256 i = 0; i < voters.length; i++) {
            token.transfer(voters[i], 50_000 ether);
        }
        token.delegate(deployer);
        vm.roll(block.number + 2);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Demo: set swap fee to 0.25%");
        vm.stopBroadcast();

        string memory env = string(
            abi.encodePacked(
                "VITE_USDC=",
                vm.toString(address(weth)),
                "\nVITE_PAY_WITH_ETH=true",
                "\nVITE_PMT=",
                vm.toString(address(token)),
                "\nVITE_GOVERNOR=",
                vm.toString(address(governor)),
                "\nVITE_FACTORY=",
                vm.toString(address(factory)),
                "\nVITE_SAMPLE_MARKET=",
                vm.toString(marketAddr),
                "\nVITE_GOVERNOR_PROPOSAL_ID=",
                vm.toString(proposalId),
                "\nVITE_SUBGRAPH_URL=https://api.studio.thegraph.com/query/placeholder/pmt/version/latest\n"
            )
        );
        string memory infuraKey = vm.envOr("INFURA_API_KEY", string(""));
        if (bytes(infuraKey).length > 0) {
            env = string(abi.encodePacked(env, "VITE_INFURA_API_KEY=", infuraKey, "\n"));
        }
        vm.writeFile("frontend/.env", env);

        console2.log("=== Local deploy OK ===");
        console2.log("WETH (collateral)", address(weth));
        console2.log("Market", marketAddr);
        console2.log("Factory", address(factory));
        console2.log("Demo proposal id", proposalId, "(state should be Active)");
        console2.log("Wrote frontend/.env - trades use native ETH (buyOutcomeWithEth)");
    }
}
